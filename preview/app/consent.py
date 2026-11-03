"""A reviewer's decision, recorded once and never overwritten."""
import hashlib
import json
import re
from datetime import datetime, timezone

DECISIONS = ("yes", "not_yet")
# one address, no whitespace and nothing that could be a path segment (it names the object)
EMAIL_RE = re.compile(r"^[^\s/@]+@[^\s/@]+\.[^\s/@]+$")


def consent_record(key: str, email: str, decision: str, comment: str, build: dict,
                   now: datetime | None = None, name: str = "", via: str = "iap") -> dict:
    if decision not in DECISIONS:
        raise ValueError(f"decision must be one of {DECISIONS}")
    if not EMAIL_RE.match(email):
        raise ValueError("not an email address")
    now = now or datetime.now(timezone.utc)
    return {
        "dataset_key": key,
        "decision": decision,
        "comment": comment.strip()[:4000],
        # iap: the address IAP verified; link: the address the reviewer typed beside their name
        "email": email.strip().lower(),
        "name": name.strip()[:200],
        "via": via,
        "recorded_utc": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        # exactly what was shown: the build and its manifest's hash
        "build_id": build.get("build_id"),
        "build_sha256": hashlib.sha256(json.dumps(build, sort_keys=True).encode()).hexdigest(),
        "question_id": build.get("consent_question_id"),
        "question": build.get("consent_question"),
        "release_candidate": build.get("release_candidate"),
    }


def consent_object_name(rec: dict) -> str:
    """consent/{key}/{utc}_{email}.json: one object per decision, sorted by time."""
    stamp = rec["recorded_utc"].replace(":", "").replace("-", "")
    return f"consent/{rec['dataset_key']}/{stamp}_{rec['email']}.json"
