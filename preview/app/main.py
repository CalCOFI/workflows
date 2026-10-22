"""calcofi-preview: a sign-in-only view of a dataset before its provider confirms it.

IAP decides who may sign in at all; access.csv (in the bucket, versioned; not in git,
which is public) decides which dataset each person sees; a decision is written once to
consent/{key}/ and folded into the dataset's consent question by
scripts/pull_preview_consent.R.

  datasets/{key}/current.txt          the build on show
  datasets/{key}/{build}/build.json   what the build is: name, pages, consent question
  datasets/{key}/{build}/...          its pages and files
  access.csv                          dataset_key,email,status,...
  consent/{key}/{utc}_{email}.json    one object per decision, never overwritten
"""
import html
import json

from fastapi import Depends, FastAPI, Form, HTTPException, Request
from fastapi.responses import HTMLResponse, RedirectResponse, Response

from . import __version__
from .access import KEY_RE, may_view, parse_access, visible_keys
from .config import Settings
from .consent import DECISIONS, consent_object_name, consent_record
from .identity import current_email
from .store import Exists, GcsStore, content_type, safe_path

app = FastAPI(title="calcofi-preview", version=__version__, docs_url=None, redoc_url=None)
SETTINGS = Settings()
STORE = None  # set by the tests, or a GcsStore on first use


def get_store():
    global STORE
    if STORE is None:
        STORE = GcsStore(SETTINGS.bucket)
    return STORE


def who(request: Request) -> str:
    return current_email(request, SETTINGS)


def grants(store) -> dict:
    return parse_access((store.read("access.csv") or b"").decode())


def current_build(store, key: str) -> dict:
    bid = (store.read(f"datasets/{key}/current.txt") or b"").decode().strip()
    raw = store.read(f"datasets/{key}/{bid}/build.json") if bid else None
    if not raw:
        raise HTTPException(404, f"no preview of {key}")
    return json.loads(raw)


def require(email: str, key: str, store) -> None:
    # the same 404 for "not granted" and "no such dataset": a reviewer learns nothing of the others
    if not may_view(email, key, grants(store), SETTINGS.team):
        raise HTTPException(404, f"no preview of {key}")


HEAD = """<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>{title}</title>
<link rel="icon" type="image/png" sizes="32x32" href="https://calcofi.io/brand/v2/favicon-32x32.png">
<script>(function(){{var d=document.documentElement,m=/[?&]theme=(dark|light)\\b/.exec(location.search);var t=(m&&m[1])||"light";d.dataset.theme=t;d.style.colorScheme=t}})();</script>
<link rel="stylesheet" href="https://calcofi.io/brand/v2/fonts.css">
<link rel="stylesheet" href="https://calcofi.io/brand/v2/theme.css">
<style>
  body {{ max-width: 52rem; margin: 0 auto; padding: 1rem; font-family: var(--font-body, system-ui); }}
  .note {{ border-left: 4px solid var(--accent, #c69214); padding: .5rem 1rem; }}
  textarea {{ width: 100%; min-height: 5rem; }}
  table {{ border-collapse: collapse; }} td, th {{ padding: .25rem .5rem; text-align: left; }}
</style></head><body>
<p><a href="/">CalCOFI.io preview</a> · signed in as {email}</p>
"""


def page(title: str, email: str, body: str) -> HTMLResponse:
    e = html.escape
    return HTMLResponse(HEAD.format(title=e(title), email=e(email)) + body + "</body></html>",
                        headers={"Cache-Control": "private, no-store"})


@app.get("/healthz")
def healthz():
    return {"ok": True, "version": __version__}


@app.get("/", response_class=HTMLResponse)
def home(email: str = Depends(who), store=Depends(get_store)):
    keys = visible_keys(email, grants(store), SETTINGS.team, store.list_prefixes("datasets"))
    items = "".join(f'<li><a href="/d/{k}/">{html.escape(k)}</a></li>' for k in keys)
    body = ("<h1>Datasets to review</h1>"
            + (f"<ul>{items}</ul>" if items else
               "<p>Nothing is shared with this account yet. If you expected a dataset here, "
               "reply to the email that sent you this link, saying which address you signed in with.</p>"))
    return page("CalCOFI.io preview", email, body)


@app.get("/d/{key}/", response_class=HTMLResponse)
def dataset(key: str, email: str = Depends(who), store=Depends(get_store)):
    require(email, key, store)
    b = current_build(store, key)
    e = html.escape
    pages = "".join(
        f'<li><a href="/d/{key}/f/{e(p["path"])}">{e(p.get("title", p["path"]))}</a>'
        f'{" — " + e(p["description"]) if p.get("description") else ""}</li>'
        for p in b.get("pages", []))
    mine = [json.loads(store.read(n) or b"{}") for n in store.list_names(f"consent/{key}")]
    if email not in SETTINGS.team:
        mine = [r for r in mine if r.get("email") == email]
    rows = "".join(f"<tr><td>{e(r.get('recorded_utc', ''))}</td><td>{e(r.get('email', ''))}</td>"
                   f"<td>{e(r.get('decision', ''))}</td><td>{e(r.get('comment', ''))}</td></tr>" for r in mine)
    body = f"""
<h1>{e(b.get("dataset_name", key))}</h1>
<p class="note">This is a private preview of <code>{e(key)}</code> as CalCOFI.io would publish it
(build <code>{e(str(b.get("build_id")))}</code>, {e(str(b.get("created_utc", "")))}). Nothing here is public.</p>
<h2>What to review</h2><ul>{pages}</ul>
<h2>Your decision</h2>
<p>{e(b.get("consent_question", ""))}</p>
<form method="post" action="/d/{key}/consent">
  <input type="hidden" name="build_id" value="{e(str(b.get("build_id")))}">
  <p><label><input type="radio" name="decision" value="yes" required> Yes, publish it as shown</label><br>
     <label><input type="radio" name="decision" value="not_yet"> Not yet (say what should change below)</label></p>
  <p><label>Comments<br><textarea name="comment"></textarea></label></p>
  <p><button type="submit">Record my decision</button></p>
</form>
{f"<h2>Recorded</h2><table><tr><th>when (UTC)</th><th>who</th><th>decision</th><th>comment</th></tr>{rows}</table>" if rows else ""}
"""
    return page(b.get("dataset_name", key), email, body)


@app.get("/d/{key}/f/{path:path}")
def dataset_file(key: str, path: str, email: str = Depends(who), store=Depends(get_store)):
    require(email, key, store)
    b = current_build(store, key)
    try:
        name = safe_path("datasets", key, str(b["build_id"]), path)
    except ValueError:
        raise HTTPException(400, "bad path") from None
    data = store.read(name)
    if data is None:
        raise HTTPException(404, "not in this build")
    return Response(data, media_type=content_type(path), headers={"Cache-Control": "private, no-store"})


@app.post("/d/{key}/consent")
def consent(key: str, decision: str = Form(...), comment: str = Form(""), build_id: str = Form(...),
            email: str = Depends(who), store=Depends(get_store)):
    require(email, key, store)
    if decision not in DECISIONS:
        raise HTTPException(400, f"decision must be one of {DECISIONS}")
    b = current_build(store, key)
    if str(b.get("build_id")) != build_id:
        # the page was older than the build now on show: they decided on something else
        raise HTTPException(409, "this preview was updated while you had it open; reload and review it again")
    rec = consent_record(key, email, decision, comment, b)
    try:
        store.write_new(consent_object_name(rec), json.dumps(rec, indent=2).encode(), "application/json")
    except Exists:
        raise HTTPException(409, "a decision was already recorded this second; reload") from None
    return RedirectResponse(f"/d/{key}/", status_code=303)
