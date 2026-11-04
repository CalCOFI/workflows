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

    def size(self, name: str) -> int | None:
        f = self.root / safe_path(name)
        return f.stat().st_size if f.is_file() else None

    def stream(self, name: str, start: int = 0, end: int | None = None):
        """Chunks of the object (bytes start..end inclusive, or to the end), or None when absent."""
        f = self.root / safe_path(name)
        if not f.is_file():
            return None

        def chunks():
            left = None if end is None else end - start + 1
            with f.open("rb") as fh:
                fh.seek(start)
                while left is None or left > 0:
                    b = fh.read(CHUNK if left is None else min(CHUNK, left))
                    if not b:
                        break
                    if left is not None:
                        left -= len(b)
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

    def size(self, name: str) -> int | None:
        blob = self.bucket.get_blob(safe_path(name))
        return None if blob is None else blob.size

    def stream(self, name: str, start: int = 0, end: int | None = None):
        """Chunks of the object (bytes start..end inclusive, or to the end), or None when absent."""
        blob = self.bucket.get_blob(safe_path(name))
        if blob is None:
            return None
        last = (blob.size or 0) - 1 if end is None else min(end, (blob.size or 0) - 1)

        def chunks():
            pos = start
            while pos <= last:
                stop = min(pos + CHUNK - 1, last)
                yield blob.download_as_bytes(start=pos, end=stop, checksum=None)
                pos = stop + 1
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
