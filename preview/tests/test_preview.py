import json
from dataclasses import replace
from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient

from app import main
from app.access import link_slug, may_view, may_view_link, mint_slug, mint_token, parse_access, slug_key
from app.config import Settings
from app.consent import consent_object_name, consent_record
from app.store import Exists, LocalStore, safe_path

KEY = "sio_held-zoo"
OTHER = "cce-lter_other"
BUILD = {"build_id": "b1", "dataset_key": KEY, "dataset_name": "Held zooplankton",
         "created_utc": "2026-10-22T00:00:00Z", "consent_question_id": "sio_held-zoo_09",
         "consent_question": "May CalCOFI.io publish it as shown?",
         "pages": [{"path": "summary.html", "title": "Summary"}],
         "data_roots": ["ducklake-preview"]}


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
    (tmp_path / "datasets" / KEY / "b1" / "site" / "datasets").mkdir(parents=True)
    (tmp_path / "datasets" / KEY / "b1" / "site" / "index.html").write_text("<p>site home</p>")
    (tmp_path / "datasets" / KEY / "b1" / "site" / "datasets" / "index.html").write_text("<p>catalog</p>")
    rel = tmp_path / "ducklake-preview" / "releases"
    rel.mkdir(parents=True)
    (rel / "latest.txt").write_text("v2026.11.02\n")
    (rel / "big.parquet").write_bytes(b"P" * (3 * (1 << 20) + 5))
    (tmp_path / "access.csv").write_text(
        "dataset_key,email,status,granted,granted_by\n"
        f"{KEY},PI@ucsd.edu,active,2026-10-22,ben\n"
        f"{OTHER},pi@ucsd.edu,revoked,2026-10-22,ben\n")
    return s


def client(store, monkeypatch, email="pi@ucsd.edu", team=frozenset({"bebest@ucsd.edu"}), on_cloud_run=False,
           access="iap"):
    monkeypatch.setattr(main, "STORE", store)
    monkeypatch.setattr(main, "SETTINGS", replace(Settings(), team=team, dev_email=email, on_cloud_run=on_cloud_run,
                                                  access=access))
    return TestClient(main.app)


TOKEN = "k7m2x9q4"
SLUG = f"{KEY}-{TOKEN}"
LINK = f"/{KEY}/{TOKEN}"


@pytest.fixture
def link_store(store, tmp_path):
    """The same store with KEY also published under a link-mode slug, and OTHER under a slug
    whose build never opted in."""
    for slug, key, access in [(SLUG, KEY, "link"), (f"{OTHER}-aaaaaaaa", OTHER, None)]:
        d = tmp_path / "datasets" / slug / "b2"
        d.mkdir(parents=True)
        build = {**BUILD, "build_id": "b2", "dataset_key": key, **({"access": access} if access else {})}
        (d / "build.json").write_text(json.dumps(build))
        (d / "summary.html").write_text(f"<p>{slug} rows</p>")
        (tmp_path / "datasets" / slug / "current.txt").write_text("b2\n")
    return store


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


# static builds and the candidate release ---------------------------------------------

def test_a_folder_serves_its_index_html(store, monkeypatch):
    c = client(store, monkeypatch)
    assert "site home" in c.get(f"/d/{KEY}/f/site/").text
    assert "catalog" in c.get(f"/d/{KEY}/f/site/datasets/").text


def test_data_is_streamed_whole_from_the_build_data_roots(store, monkeypatch):
    c = client(store, monkeypatch)
    r = c.get(f"/d/{KEY}/data/ducklake-preview/releases/latest.txt")
    assert r.status_code == 200 and r.text.strip() == "v2026.11.02"
    assert r.headers["cache-control"] == "private, no-store"
    r = c.get(f"/d/{KEY}/data/ducklake-preview/releases/big.parquet")
    assert len(r.content) == 3 * (1 << 20) + 5    # several chunks, nothing lost
    assert r.headers["content-type"] == "application/vnd.apache.parquet"


def test_data_never_reaches_outside_the_data_roots(store, monkeypatch):
    c = client(store, monkeypatch)
    for path in ["access.csv", "secret.txt", f"consent/{KEY}/x.json", f"datasets/{OTHER}/b1/build.json",
                 "ducklake-preview-other/x", "ducklake-preview/../access.csv", "ducklake-preview/%2e%2e/access.csv"]:
        assert c.get(f"/d/{KEY}/data/{path}").status_code in (400, 404), path


def test_data_needs_access_to_the_dataset(store, monkeypatch):
    c = client(store, monkeypatch)
    assert c.get(f"/d/{OTHER}/data/ducklake-preview/releases/latest.txt").status_code == 404
    assert client(store, monkeypatch, email="").get(
        f"/d/{KEY}/data/ducklake-preview/releases/latest.txt").status_code == 401


def test_explorer_and_site_assets_get_their_types():
    from app.store import content_type
    assert content_type("duckdb-eh.wasm") == "application/wasm"
    assert content_type("worker.mjs") == "text/javascript"
    assert content_type("grid.geojson") == "application/geo+json"


# link mode -------------------------------------------------------------------------

def test_tokens_are_8_of_a_z_0_9_and_slugs_carry_the_key():
    tok = mint_token()
    assert len(tok) == 8 and tok.isalnum() and tok.islower() or tok.isdigit()
    s = mint_slug(KEY)
    assert slug_key(s) == KEY and len(s) == len(KEY) + 9
    assert slug_key(KEY) is None and slug_key(f"{KEY}-abc") is None and slug_key(f"{KEY}-ABCDEFGH") is None
    assert link_slug(KEY, TOKEN) == SLUG
    assert link_slug("d", TOKEN) is None and link_slug(KEY, "f") is None and link_slug(KEY, "data") is None
    with pytest.raises(ValueError):
        mint_slug("not a key")
    assert may_view_link(SLUG, {"access": "link", "dataset_key": KEY})
    assert not may_view_link(SLUG, {"dataset_key": KEY})                       # never opted in
    assert not may_view_link(SLUG, {"access": "link", "dataset_key": OTHER})   # someone else's build
    assert not may_view_link(KEY, {"access": "link", "dataset_key": KEY})      # no token


def test_link_mode_needs_no_identity_but_only_the_link_opens(link_store, monkeypatch):
    c = client(link_store, monkeypatch, email="", access="link")
    assert c.get("/health").status_code == 200
    home = c.get("/")
    assert home.status_code == 200 and KEY not in home.text and TOKEN not in home.text
    r = c.get(f"{LINK}/")
    assert r.status_code == 200 and "opened from a private link" in r.text and 'name="email"' in r.text
    assert f'href="{LINK}/f/summary.html"' in r.text and f'action="{LINK}/consent"' in r.text
    assert c.get(f"{LINK}/f/summary.html").status_code == 200
    assert c.get(f"{LINK}/data/ducklake-preview/releases/latest.txt").text.strip() == "v2026.11.02"
    # the iap URLs, the wrong token, a build that never opted in, malformed parts: all absent
    for path in [f"/d/{KEY}/", f"/d/{SLUG}/", f"/{KEY}/00000000/", f"/{OTHER}/aaaaaaaa/",
                 f"/d/{KEY}/f/summary.html", f"/d/{KEY}/data/ducklake-preview/releases/latest.txt",
                 f"/{KEY}/", f"/{KEY}/{TOKEN.upper()}/"]:
        assert c.get(path).status_code == 404, path
    # a link pasted without its trailing slash still arrives
    r = c.get(f"{LINK}", follow_redirects=False)
    assert r.status_code == 307 and r.headers["location"].endswith(f"{LINK}/")


def test_iap_mode_never_answers_the_link_urls(link_store, monkeypatch):
    c = client(link_store, monkeypatch, email="bebest@ucsd.edu")       # the team, who sees everything
    assert c.get(f"/d/{SLUG}/").status_code == 200                     # …through the iap family
    assert c.get(f"{LINK}/").status_code == 404
    assert c.get(f"{LINK}/f/summary.html").status_code == 404
    assert c.get(f"{LINK}/data/ducklake-preview/releases/latest.txt").status_code == 404


def test_link_mode_ignores_a_stray_iap_header(link_store, monkeypatch):
    c = client(link_store, monkeypatch, email="", access="link")
    monkeypatch.setattr(main, "SETTINGS", replace(main.SETTINGS, iap_audience="/projects/1/locations/r/services/s"))
    assert c.get(f"{LINK}/", headers={"x-goog-iap-jwt-assertion": "not.a.jwt"}).status_code == 200


def test_link_mode_decision_names_the_reviewer(link_store, monkeypatch):
    c = client(link_store, monkeypatch, email="", access="link")
    r = c.post(f"{LINK}/consent", data={"decision": "yes", "comment": "fine", "build_id": "b2"})
    assert r.status_code == 400                                   # no name or address
    r = c.post(f"{LINK}/consent", data={"decision": "yes", "comment": "fine", "build_id": "b2",
                                        "name": "A PI", "email": "not an address"})
    assert r.status_code == 400
    r = c.post(f"{LINK}/consent", data={"decision": "yes", "comment": "fine", "build_id": "b2",
                                        "name": "A PI", "email": "PI@lab.org"}, follow_redirects=False)
    assert r.status_code == 303 and r.headers["location"] == f"{LINK}/"
    names = link_store.list_names(f"consent/{KEY}")               # filed under the key, not the slug
    assert len(names) == 1 and names[0].endswith("_pi@lab.org.json")
    rec = json.loads(link_store.read(names[0]))
    assert rec["via"] == "link" and rec["name"] == "A PI" and rec["email"] == "pi@lab.org" and rec["dataset_key"] == KEY
    assert "A PI" in c.get(f"{LINK}/").text                       # shown to the next holder of the link


def test_iap_mode_still_serves_the_key_and_records_via_iap(link_store, monkeypatch):
    c = client(link_store, monkeypatch)
    r = c.get(f"/d/{KEY}/")
    assert r.status_code == 200 and f'action="/d/{KEY}/consent"' in r.text
    r = c.post(f"/d/{KEY}/consent", data={"decision": "not_yet", "comment": "x", "build_id": "b1"}, follow_redirects=False)
    assert r.status_code == 303 and r.headers["location"] == f"/d/{KEY}/"
    rec = json.loads(link_store.read(link_store.list_names(f"consent/{KEY}")[0]))
    assert rec["via"] == "iap" and rec["email"] == "pi@ucsd.edu"


def test_settings_refuse_an_unknown_access_mode(monkeypatch):
    monkeypatch.setenv("PREVIEW_ACCESS", "open")
    with pytest.raises(ValueError):
        Settings()
