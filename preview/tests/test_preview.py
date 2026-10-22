import json
from dataclasses import replace
from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient

from app import main
from app.access import may_view, parse_access
from app.config import Settings
from app.consent import consent_object_name, consent_record
from app.store import Exists, LocalStore, safe_path

KEY = "sio_held-zoo"
OTHER = "cce-lter_other"
BUILD = {"build_id": "b1", "dataset_key": KEY, "dataset_name": "Held zooplankton",
         "created_utc": "2026-10-22T00:00:00Z", "consent_question_id": "sio_held-zoo_09",
         "consent_question": "May CalCOFI.io publish it as shown?",
         "pages": [{"path": "summary.html", "title": "Summary"}]}


@pytest.fixture
def store(tmp_path):
    s = LocalStore(tmp_path)
    for key, build in [(KEY, BUILD), (OTHER, {**BUILD, "dataset_key": OTHER, "dataset_name": "Other"})]:
        d = tmp_path / "datasets" / key / "b1"
        d.mkdir(parents=True)
        (d / "build.json").write_text(json.dumps(build))
        (d / "summary.html").write_text(f"<p>{key} rows</p>")
        (tmp_path / "datasets" / key / "current.txt").write_text("b1\n")
    (tmp_path / "secret.txt").write_text("outside the build")
    (tmp_path / "access.csv").write_text(
        "dataset_key,email,status,granted,granted_by\n"
        f"{KEY},PI@ucsd.edu,active,2026-10-22,ben\n"
        f"{OTHER},pi@ucsd.edu,revoked,2026-10-22,ben\n")
    return s


def client(store, monkeypatch, email="pi@ucsd.edu", team=frozenset({"bebest@ucsd.edu"}), on_cloud_run=False):
    monkeypatch.setattr(main, "STORE", store)
    monkeypatch.setattr(main, "SETTINGS", replace(Settings(), team=team, dev_email=email, on_cloud_run=on_cloud_run))
    return TestClient(main.app)


# access -------------------------------------------------------------------------

def test_parse_access_lowercases_and_drops_revoked_and_malformed():
    g = parse_access("dataset_key,email,status\nsio_a,X@Y.org,active\nsio_b,x@y.org,revoked\nbad key,x@y.org,\n")
    assert g == {"x@y.org": frozenset({"sio_a"})}


def test_team_sees_all_reviewer_only_granted():
    g = {"pi@x.org": frozenset({"sio_a"})}
    assert may_view("pi@x.org", "sio_a", g, frozenset())
    assert not may_view("pi@x.org", "sio_b", g, frozenset())
    assert may_view("ben@x.org", "sio_b", g, frozenset({"ben@x.org"}))
    assert not may_view("ben@x.org", "../etc", g, frozenset({"ben@x.org"}))


# identity -----------------------------------------------------------------------

def test_no_identity_is_refused(store, monkeypatch):
    c = client(store, monkeypatch, email="")
    assert c.get("/").status_code == 401


def test_dev_identity_is_refused_on_cloud_run(store, monkeypatch):
    c = client(store, monkeypatch, on_cloud_run=True)
    assert c.get(f"/d/{KEY}/").status_code == 401


def test_a_forged_iap_header_is_refused(store, monkeypatch):
    c = client(store, monkeypatch, email="")
    monkeypatch.setattr(main, "SETTINGS", replace(main.SETTINGS, iap_audience="/projects/1/locations/r/services/s"))
    r = c.get("/", headers={"x-goog-iap-jwt-assertion": "not.a.jwt"})
    assert r.status_code == 401


# pages --------------------------------------------------------------------------

def test_reviewer_sees_only_their_dataset(store, monkeypatch):
    c = client(store, monkeypatch)
    home = c.get("/").text
    assert KEY in home and OTHER not in home
    assert c.get(f"/d/{KEY}/").status_code == 200
    assert c.get(f"/d/{OTHER}/").status_code == 404           # revoked: same 404 as absent
    assert c.get(f"/d/{OTHER}/f/summary.html").status_code == 404


def test_team_sees_every_dataset(store, monkeypatch):
    c = client(store, monkeypatch, email="bebest@ucsd.edu")
    home = c.get("/").text
    assert KEY in home and OTHER in home


def test_file_is_served_from_the_current_build_only(store, monkeypatch):
    c = client(store, monkeypatch)
    r = c.get(f"/d/{KEY}/f/summary.html")
    assert r.status_code == 200 and "rows" in r.text
    assert r.headers["cache-control"] == "private, no-store"
    assert c.get(f"/d/{KEY}/f/../../../secret.txt").status_code in (400, 404)
    assert c.get(f"/d/{KEY}/f/%2e%2e/%2e%2e/%2e%2e/secret.txt").status_code in (400, 404)


def test_safe_path_refuses_climbing():
    for bad in [("a", ".."), ("/etc",), ("a", "", "b")]:
        with pytest.raises(ValueError):
            safe_path(*bad)


# consent ------------------------------------------------------------------------

def test_consent_is_recorded_with_who_and_what_was_shown(store, monkeypatch, tmp_path):
    c = client(store, monkeypatch)
    r = c.post(f"/d/{KEY}/consent", data={"decision": "yes", "comment": "fine", "build_id": "b1"},
               follow_redirects=False)
    assert r.status_code == 303
    names = store.list_names(f"consent/{KEY}")
    assert len(names) == 1
    rec = json.loads(store.read(names[0]))
    assert rec["email"] == "pi@ucsd.edu" and rec["decision"] == "yes"
    assert rec["build_id"] == "b1" and rec["question_id"] == "sio_held-zoo_09" and len(rec["build_sha256"]) == 64
    assert "fine" in c.get(f"/d/{KEY}/").text


def test_consent_on_a_stale_page_is_refused(store, monkeypatch):
    c = client(store, monkeypatch)
    r = c.post(f"/d/{KEY}/consent", data={"decision": "yes", "build_id": "b0"})
    assert r.status_code == 409
    assert store.list_names(f"consent/{KEY}") == []


def test_consent_needs_access_and_a_known_decision(store, monkeypatch):
    c = client(store, monkeypatch)
    assert c.post(f"/d/{OTHER}/consent", data={"decision": "yes", "build_id": "b1"}).status_code == 404
    assert c.post(f"/d/{KEY}/consent", data={"decision": "maybe", "build_id": "b1"}).status_code == 400


def test_a_recorded_decision_is_never_overwritten(store):
    rec = consent_record(KEY, "pi@ucsd.edu", "yes", "", BUILD, now=datetime(2026, 10, 22, tzinfo=timezone.utc))
    name = consent_object_name(rec)
    assert name == f"consent/{KEY}/20261022T000000Z_pi@ucsd.edu.json"
    store.write_new(name, b"{}", "application/json")
    with pytest.raises(Exists):
        store.write_new(name, b"{}", "application/json")


def test_reviewer_does_not_see_other_reviewers_decisions(store, monkeypatch):
    store.write_new(f"consent/{KEY}/20261021T000000Z_other@noaa.gov.json",
                    json.dumps({"email": "other@noaa.gov", "decision": "not_yet", "comment": "theirs"}).encode(),
                    "application/json")
    assert "theirs" not in client(store, monkeypatch).get(f"/d/{KEY}/").text
    assert "theirs" in client(store, monkeypatch, email="bebest@ucsd.edu").get(f"/d/{KEY}/").text
