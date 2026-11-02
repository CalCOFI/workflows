"""Objects in the private bucket (GCS), or a local directory for tests and development."""
import mimetypes
from pathlib import Path, PurePosixPath


class Exists(Exception):
    """write_new() found the object already there."""


def safe_path(*parts: str) -> str:
    """Join object-path parts, refusing anything that climbs out (.., absolute, empty)."""
    segs = [s for part in parts for s in part.split("/")]
    if not segs or any(s in ("", ".", "..") or "\\" in s for s in segs):
        raise ValueError(f"unsafe path: {'/'.join(parts)}")
    return str(PurePosixPath(*segs))


# types a static site and the Explorer need that mimetypes may not know on every platform
TYPES = {".wasm": "application/wasm", ".mjs": "text/javascript", ".js": "text/javascript",
         ".json": "application/json", ".geojson": "application/geo+json",
         ".parquet": "application/vnd.apache.parquet", ".txt": "text/plain; charset=utf-8",
         ".md": "text/markdown; charset=utf-8", ".svg": "image/svg+xml", ".woff2": "font/woff2"}
CHUNK = 1 << 20


def content_type(name: str) -> str:
    return TYPES.get(PurePosixPath(name).suffix.lower()) or mimetypes.guess_type(name)[0] or "application/octet-stream"


class LocalStore:
    def __init__(self, root: str | Path):
        self.root = Path(root)

    def read(self, name: str) -> bytes | None:
        f = self.root / safe_path(name)
        return f.read_bytes() if f.is_file() else None

    def stream(self, name: str):
        """Chunks of the object, or None when it is absent."""
        f = self.root / safe_path(name)
        if not f.is_file():
            return None

        def chunks():
            with f.open("rb") as fh:
                while b := fh.read(CHUNK):
                    yield b
        return chunks()

    def list_prefixes(self, prefix: str) -> list[str]:
        d = self.root / safe_path(prefix)
        return sorted(p.name for p in d.iterdir() if p.is_dir()) if d.is_dir() else []

    def list_names(self, prefix: str) -> list[str]:
        d = self.root / safe_path(prefix)
        return sorted(str(p.relative_to(self.root)) for p in d.rglob("*") if p.is_file()) if d.is_dir() else []

    def write_new(self, name: str, data: bytes, ctype: str) -> None:
        f = self.root / safe_path(name)
        if f.exists():
            raise Exists(name)
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_bytes(data)


class GcsStore:
    def __init__(self, bucket: str):
        from google.cloud import storage
        self.bucket = storage.Client().bucket(bucket)

    def read(self, name: str) -> bytes | None:
        from google.api_core.exceptions import NotFound
        try:
            return self.bucket.blob(safe_path(name)).download_as_bytes()
        except NotFound:
            return None

    def stream(self, name: str):
        """Chunks of the object, or None when it is absent. Streamed, never buffered: a buffered
        Cloud Run response stops at 32 MiB, and a release table (obs_bio) is about that size."""
        from google.api_core.exceptions import NotFound
        blob = self.bucket.blob(safe_path(name))
        try:
            blob.reload()
        except NotFound:
            return None

        def chunks():
            with blob.open("rb", chunk_size=CHUNK) as fh:
                while b := fh.read(CHUNK):
                    yield b
        return chunks()

    def list_prefixes(self, prefix: str) -> list[str]:
        it = self.bucket.client.list_blobs(self.bucket, prefix=safe_path(prefix) + "/", delimiter="/")
        list(it)  # prefixes fill in as the pages are read
        return sorted(p.rstrip("/").rsplit("/", 1)[-1] for p in it.prefixes)

    def list_names(self, prefix: str) -> list[str]:
        return sorted(b.name for b in self.bucket.client.list_blobs(self.bucket, prefix=safe_path(prefix) + "/"))

    def write_new(self, name: str, data: bytes, ctype: str) -> None:
        from google.api_core.exceptions import PreconditionFailed
        try:  # if_generation_match=0: create only, never overwrite a recorded decision
            self.bucket.blob(safe_path(name)).upload_from_string(data, content_type=ctype, if_generation_match=0)
        except PreconditionFailed:
            raise Exists(name) from None
