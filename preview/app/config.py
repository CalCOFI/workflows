"""Settings from the environment (Cloud Run service env vars)."""
import os
from dataclasses import dataclass, field


def _csv(v: str) -> frozenset[str]:
    return frozenset(e.strip().lower() for e in v.split(",") if e.strip())


@dataclass(frozen=True)
class Settings:
    # the private bucket holding datasets/{key}/{build}/, access.csv and consent/
    bucket: str = field(default_factory=lambda: os.environ.get("PREVIEW_BUCKET", "calcofi-preview"))
    # IAP's signed-header audience: /projects/{number}/locations/{region}/services/{service}
    iap_audience: str = field(default_factory=lambda: os.environ.get("PREVIEW_IAP_AUDIENCE", ""))
    # the data team sees every dataset; reviewers only the ones access.csv grants them
    team: frozenset[str] = field(default_factory=lambda: _csv(os.environ.get("PREVIEW_TEAM", "")))
    # local development only: a fixed identity in place of IAP's signed header.
    # refused on Cloud Run (K_SERVICE is set there), so it can never ship
    dev_email: str = field(default_factory=lambda: os.environ.get("PREVIEW_DEV_EMAIL", ""))
    on_cloud_run: bool = field(default_factory=lambda: bool(os.environ.get("K_SERVICE")))
