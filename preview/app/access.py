"""Which datasets a person may see: access.csv in the private bucket (not in git: the repo is public)."""
import csv
import io
import re
import secrets

KEY_RE = re.compile(r"^[a-z0-9][a-z0-9-]*_[a-z0-9][a-z0-9-]*$")
# link mode: the dataset key and a short token nobody guesses, shown as /<key>/<token>/ and
# stored as datasets/<key>-<token>/ (8 of [a-z0-9]: 41 bits; the key is public already)
TOKEN_RE = re.compile(r"^[a-z0-9]{8}$")
SLUG_RE = re.compile(r"^([a-z0-9][a-z0-9-]*_[a-z0-9][a-z0-9-]*)-([a-z0-9]{8})$")
ALPHABET = "abcdefghijklmnopqrstuvwxyz0123456789"


def mint_token() -> str:
    return "".join(secrets.choice(ALPHABET) for _ in range(8))


def mint_slug(key: str) -> str:
    if not KEY_RE.match(key):
        raise ValueError(f"not a dataset key: {key}")
    return f"{key}-{mint_token()}"


def slug_key(slug: str) -> str | None:
    """The dataset key a link-mode slug names, or None when it is not one."""
    m = SLUG_RE.match(slug)
    return m.group(1) if m else None


def link_slug(key: str, token: str) -> str | None:
    """The storage slug behind /<key>/<token>/, or None when either part is malformed."""
    return f"{key}-{token}" if KEY_RE.match(key) and TOKEN_RE.match(token) else None


def may_view_link(slug: str, build: dict) -> bool:
    """Link mode: the slug carries the secret and the build on show opted in to it."""
    key = slug_key(slug)
    return key is not None and build.get("access") == "link" and build.get("dataset_key") == key


def parse_access(text: str) -> dict[str, frozenset[str]]:
    """email -> dataset keys, from rows `dataset_key,email,...`; a revoked row is ignored."""
    grants: dict[str, set[str]] = {}
    for row in csv.DictReader(io.StringIO(text)):
        key, email = (row.get("dataset_key") or "").strip(), (row.get("email") or "").strip().lower()
        if not KEY_RE.match(key) or "@" not in email:
            continue
        if (row.get("status") or "active").strip() != "active":
            continue
        grants.setdefault(email, set()).add(key)
    return {e: frozenset(k) for e, k in grants.items()}


def may_view(email: str, key: str, grants: dict[str, frozenset[str]], team: frozenset[str]) -> bool:
    return bool(KEY_RE.match(key)) and (email in team or key in grants.get(email, frozenset()))


def visible_keys(email: str, grants: dict[str, frozenset[str]], team: frozenset[str],
                 all_keys: list[str]) -> list[str]:
    return sorted(k for k in all_keys if may_view(email, k, grants, team))
