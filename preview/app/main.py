"""calcofi-preview: a private view of a dataset before its provider confirms it.

Two access modes (PREVIEW_ACCESS), each with its own URLs; the other mode's answer 404.
`iap`, at /d/{key}/: IAP decides who may sign in at all and access.csv (in the bucket,
versioned; not in git, which is public) which dataset each address sees. `link`, at
/{key}/{token}/ (preview.calcofi.io/{key}/{token}/ through the server's Caddy): no sign-in;
the token is 8 characters nobody guesses, the build (datasets/{key}-{token}/) opted in
("access": "link" in build.json), the provider gets the link by email and may pass it on,
and the decision form asks for a name and address.
Either way a decision is written once to consent/{key}/ and folded into the dataset's
consent question by scripts/pull_preview_consent.R.

  datasets/{slug}/current.txt         the build on show (slug = the key in iap mode, key-token in link mode)
  datasets/{slug}/{build}/build.json  what the build is: dataset_key, name, pages, consent
                                      question, access (iap | link)
  datasets/{slug}/{build}/...         its pages and files: a summary, and static builds of
                                      calcofi.io (site/) and the Explorer (explore/)
  {data_roots}/...                    the candidate release those builds read through
                                      /d/{slug}/data/, e.g. ducklake-preview/ (build.json data_roots)
  access.csv                          dataset_key,email,status,...   (iap mode)
  consent/{key}/{utc}_{email}.json    one object per decision, never overwritten
"""
import base64
import binascii
import html
import json
import re
import secrets
from datetime import datetime, timezone

from fastapi import Depends, FastAPI, Form, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse, Response, StreamingResponse

from . import __version__
from .access import link_slug, may_view, may_view_link, parse_access, slug_key, visible_keys
from .config import Settings
from .consent import ATTRIBUTION_FIELDS, DECISIONS, EMAIL_RE, consent_object_name, consent_record
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


def who(request: Request) -> str | None:
    return current_email(request, SETTINGS)


def link_mode() -> bool:
    return SETTINGS.access == "link"


def grants(store) -> dict:
    return parse_access((store.read("access.csv") or b"").decode())


def current_build(store, slug: str) -> dict:
    bid = (store.read(f"datasets/{slug}/current.txt") or b"").decode().strip()
    raw = store.read(f"datasets/{slug}/{bid}/build.json") if bid else None
    if not raw:
        raise HTTPException(404, f"no preview of {slug}")
    return json.loads(raw)


def allowed_build(email: str | None, slug: str, store, via: str) -> dict:
    """The build on show for this request, or the one 404 that says nothing. Each mode answers
    only its own URLs (`via`): iap at /d/{key}/, where the address must be granted the key (or be
    the team); link at /{key}/{token}/, where the slug must carry its token and the build must
    have opted in, so a build published under its plain key is unreachable."""
    if via != SETTINGS.access:
        raise HTTPException(404, f"no preview of {slug}")
    if link_mode():
        try:
            b = current_build(store, slug)
        except HTTPException:
            b = {}
        if not may_view_link(slug, b):
            raise HTTPException(404, f"no preview of {slug}")
        return b
    # the same 404 for "not granted" and "no such dataset": a reviewer learns nothing of the others
    if not may_view(email, slug, grants(store), SETTINGS.team):
        raise HTTPException(404, f"no preview of {slug}")
    return current_build(store, slug)


def url_base(slug: str) -> str:
    """Where this build's pages live: /d/{key} (iap) or /{key}/{token} (link)."""
    if link_mode():
        return f"/{slug_key(slug)}/{slug[len(slug_key(slug)) + 1:]}"
    return f"/d/{slug}"


HEAD = """<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>{title}</title>
<link rel="icon" type="image/png" sizes="32x32" href="https://calcofi.io/brand/v2/favicon-32x32.png">
<script>(function(){{var d=document.documentElement,m=/[?&]theme=(dark|light)\\b/.exec(location.search);var t=(m&&m[1])||"light";d.dataset.theme=t;d.style.colorScheme=t}})();</script>
<link rel="stylesheet" href="https://calcofi.io/brand/v2/fonts.css">
<link rel="stylesheet" href="https://calcofi.io/brand/v2/theme.css">
<link rel="stylesheet" href="https://calcofi.io/brand/v2/icons.css">
<style>
  body {{ margin: 0; font-family: var(--font-body, system-ui); color: var(--cc-fg, #1b2733); background: var(--cc-bg, #fff); }}
  .pv-wrap {{ max-width: 64rem; margin: 0 auto; padding: 0 1rem 3rem; }}
  .pv-top {{ display: flex; justify-content: space-between; align-items: center; gap: 1rem; padding: .6rem 0; font-size: .9rem; opacity: .85; }}
  .pv-top a {{ color: inherit; text-decoration: none; font-weight: 600; }}
  .pv-hero {{ padding: 2rem 0 1rem; }}
  .pv-eyebrow {{ font-family: var(--font-display, "Teko", var(--font-body, system-ui)); letter-spacing: .08em; text-transform: uppercase; font-size: 1.05rem; color: var(--cc-accent, #c69214); }}
  .pv-hero h1 {{ font-family: var(--font-display, "Teko", var(--font-body, system-ui)); font-size: clamp(2.4rem, 6vw, 4.4rem); line-height: .95; margin: .2rem 0 .6rem; letter-spacing: .01em; }}
  .pv-hero h1 .pv-ds {{ color: var(--cc-accent-2, #0b6e99); }}
  .pv-lede {{ font-size: 1.2rem; max-width: 44rem; margin: 0 0 1rem; }}
  .pv-nums {{ display: flex; flex-wrap: wrap; gap: 1.5rem 2.5rem; margin: 1rem 0 0; }}
  .pv-nums div {{ display: flex; flex-direction: column; }}
  .pv-nums dd {{ margin: 0; font-family: var(--font-display, "Teko", var(--font-body, system-ui)); font-size: 2.6rem; line-height: 1; color: var(--cc-accent-2, #0b6e99); }}
  .pv-nums dt {{ font-size: .85rem; text-transform: uppercase; letter-spacing: .06em; opacity: .75; }}
  .pv-note {{ border-left: 4px solid var(--cc-accent, #c69214); padding: .6rem 1rem; background: color-mix(in srgb, var(--cc-accent, #c69214) 8%, transparent); border-radius: 0 .5rem .5rem 0; margin: 1.2rem 0; }}
  h2 {{ font-family: var(--font-display, "Teko", var(--font-body, system-ui)); font-size: 2rem; letter-spacing: .02em; margin: 2rem 0 .6rem; }}
  .pv-doors {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(15rem, 1fr)); gap: 1rem; }}
  .pv-door {{ display: block; color: inherit; text-decoration: none; border: 1px solid color-mix(in srgb, currentColor 18%, transparent); border-radius: .75rem; overflow: hidden; background: var(--cc-surface, color-mix(in srgb, currentColor 4%, transparent)); transition: transform .12s, box-shadow .12s; }}
  .pv-door:hover {{ transform: translateY(-2px); box-shadow: 0 8px 24px rgba(0,0,0,.12); }}
  .pv-door img {{ display: block; width: 100%; aspect-ratio: 16/10; object-fit: cover; object-position: top; border-bottom: 1px solid color-mix(in srgb, currentColor 12%, transparent); }}
  .pv-door .pv-ph {{ aspect-ratio: 16/10; display: grid; place-items: center; font-family: var(--font-display, "Teko", var(--font-body, system-ui)); font-size: 2.2rem; color: #fff; background: linear-gradient(135deg, var(--cc-accent-2, #0b6e99), var(--cc-accent, #c69214)); }}
  .pv-door .pv-body {{ padding: .8rem 1rem 1rem; }}
  .pv-door h3 {{ margin: 0 0 .25rem; font-size: 1.15rem; }}
  .pv-door p {{ margin: 0; font-size: .95rem; opacity: .85; }}
  .pv-door .pv-go {{ display: inline-block; margin-top: .5rem; font-weight: 600; color: var(--cc-accent-2, #0b6e99); }}
  form.pv-form {{ display: grid; gap: 1rem; max-width: 46rem; }}
  .pv-form label {{ display: block; font-weight: 600; }}
  .pv-form input[type=text], .pv-form input[type=email], .pv-form input[type=url], .pv-form textarea {{ width: 100%; box-sizing: border-box; font: inherit; padding: .5rem .6rem; border: 1px solid color-mix(in srgb, currentColor 30%, transparent); border-radius: .4rem; background: var(--cc-bg, #fff); color: inherit; }}
  .pv-form textarea {{ min-height: 4.5rem; }}
  .pv-form .pv-hint {{ font-weight: 400; font-size: .85rem; opacity: .75; }}
  .pv-form .pv-two {{ display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }}
  .pv-form .pv-choice label {{ font-weight: 500; display: flex; gap: .5rem; align-items: baseline; margin: .3rem 0; }}
  .pv-form fieldset {{ border: 1px solid color-mix(in srgb, currentColor 18%, transparent); border-radius: .6rem; padding: .8rem 1rem; }}
  .pv-form legend {{ font-weight: 700; padding: 0 .4rem; }}
  .pv-btn {{ font: inherit; font-weight: 700; padding: .7rem 1.4rem; border: 0; border-radius: .5rem; background: var(--cc-accent, #c69214); color: #1b2733; cursor: pointer; }}
  table.pv-tbl {{ border-collapse: collapse; width: 100%; font-size: .95rem; }} .pv-tbl td, .pv-tbl th {{ padding: .35rem .5rem; text-align: left; vertical-align: top; border-top: 1px solid color-mix(in srgb, currentColor 12%, transparent); }}
  .pv-fb img {{ max-width: 14rem; border-radius: .3rem; border: 1px solid color-mix(in srgb, currentColor 18%, transparent); }}
  @media (max-width: 600px) {{ .pv-form .pv-two {{ grid-template-columns: 1fr; }} }}
</style></head><body><div class="pv-wrap">
<p class="pv-top"><a href="/">CalCOFI.io preview</a><span>{viewer}</span></p>
"""


def page(title: str, email: str | None, body: str) -> HTMLResponse:
    e = html.escape
    viewer = "opened from a private link" if email is None else f"signed in as {e(email)}"
    return HTMLResponse(HEAD.format(title=e(title), viewer=viewer) + body + "</div></body></html>",
                        headers={"Cache-Control": "private, no-store"})


# not /healthz: Cloud Run reserves paths ending in "z" and answers them 404 itself
@app.get("/health")
def health():
    return {"ok": True, "version": __version__}


@app.get("/", response_class=HTMLResponse)
def home(email: str | None = Depends(who), store=Depends(get_store)):
    if link_mode():
        # nothing to list: each dataset opens only from the link its provider received
        return page("CalCOFI.io preview", None,
                    "<h1>CalCOFI.io preview</h1><p>A dataset preview opens from the private link "
                    "sent to its data provider. If you were sent one, use that link.</p>")
    keys = visible_keys(email, grants(store), SETTINGS.team, store.list_prefixes("datasets"))
    items = "".join(f'<li><a href="/d/{k}/">{html.escape(k)}</a></li>' for k in keys)
    body = ("<h1>Datasets to review</h1>"
            + (f"<ul>{items}</ul>" if items else
               "<p>Nothing is shared with this account yet. If you expected a dataset here, "
               "reply to the email that sent you this link, saying which address you signed in with.</p>"))
    return page("CalCOFI.io preview", email, body)


def fmt_n(n) -> str:
    try:
        return f"{int(n):,}"
    except (TypeError, ValueError):
        return ""


def dataset_numbers(rec: dict) -> list[tuple[str, str]]:
    """The hero's numbers from the release record: nothing typed, nothing shown that is not there."""
    cov = rec.get("coverage") or {}
    years = cov.get("years") or []
    out = []
    if cov.get("year_min") and cov.get("year_max"):
        out.append((f"{cov['year_min']}–{cov['year_max']}", "years"))
    n_obs = sum(int(y.get("n_obs") or 0) for y in years) if years else cov.get("n_obs")
    n_roots = sum(int(y.get("n_roots") or 0) for y in years) if years else cov.get("n_roots")
    if n_obs:
        out.append((fmt_n(n_obs), "observations"))
    if n_roots:
        out.append((fmt_n(n_roots), "sampling events"))
    if rec.get("n_taxa"):
        out.append((fmt_n(rec["n_taxa"]), "taxa"))
    return out


def first_sentence(md: str) -> str:
    md = (md or "").strip().split("\n")[0]
    m = md.split(". ")
    return (m[0] + ".") if len(m) > 1 else md


def dataset(slug: str, email: str | None, store, via: str) -> HTMLResponse:
    b = allowed_build(email, slug, store, via)
    key = b.get("dataset_key", slug)
    base = url_base(slug)
    rec = b.get("dataset") or {}
    att = rec.get("attribution") or {}
    prov = rec.get("provider") or {}
    e = html.escape
    name = b.get("dataset_name") or rec.get("dataset_name") or key
    short = rec.get("dataset_name_short") or name
    thanks_to = ", ".join(att.get("pi_names") or []) or prov.get("name") or prov.get("short") or "the data provider"
    doors = ""
    for p in b.get("pages", []):
        shot = p.get("shot")
        pic = (f'<img src="{base}/f/{e(shot)}" alt="" loading="lazy">' if shot
               else f'<div class="pv-ph">{e(p.get("short") or p.get("title", ""))}</div>')
        doors += (f'<a class="pv-door" href="{base}/f/{e(p["path"])}">{pic}<div class="pv-body">'
                  f'<h3>{e(p.get("title", p["path"]))}</h3><p>{e(p.get("description", ""))}</p>'
                  f'<span class="pv-go">open ↗</span></div></a>')
    nums = "".join(f"<div><dd>{e(v)}</dd><dt>{e(l)}</dt></div>" for v, l in dataset_numbers(rec))
    # what was already said about it: decisions, then feedback
    mine = [json.loads(store.read(n) or b"{}") for n in store.list_names(f"consent/{key}")]
    if not link_mode() and email not in SETTINGS.team:
        mine = [r for r in mine if r.get("email") == email]
    rows = "".join(f"<tr><td>{e(r.get('recorded_utc', ''))}</td>"
                   f"<td>{e(r.get('name') or r.get('email', ''))}</td>"
                   f"<td>{e(r.get('decision', ''))}</td><td>{e(r.get('comment', ''))}</td></tr>" for r in mine)
    fbs = [json.loads(store.read(n) or b"{}") for n in store.list_names(f"feedback/{key}") if n.endswith(".json")]
    fb_rows = ""
    for r in sorted(fbs, key=lambda r: r.get("recorded_utc", ""), reverse=True):
        img = (f'<a href="{base}/fb/{e(r["image"])}" target="_blank"><img src="{base}/fb/{e(r["image"])}" alt="the view"></a>'
               if r.get("image") else "")
        fb_rows += (f"<tr><td>{e(r.get('recorded_utc', ''))}</td><td>{e(r.get('app', ''))}</td>"
                    f"<td>{e(r.get('text', ''))}<br><a href=\"{e(r.get('url', ''))}\">{e((r.get('url') or '')[:80])}</a></td>"
                    f"<td class=\"pv-fb\">{img}</td></tr>")
    whoami = ("""  <div class="pv-two">
    <label>Your name<input type="text" name="name" required maxlength="200"></label>
    <label>Your email<input type="email" name="email" required maxlength="200"></label>
  </div>
""" if link_mode() else "")
    lic = att.get("license_name") or att.get("license") or ""
    body = f"""
<section class="pv-hero">
  <div class="pv-eyebrow">A private preview · nothing here is public</div>
  <h1>Thank you for<br><span class="pv-ds">{e(short)}</span></h1>
  <p class="pv-lede">{e(first_sentence(rec.get("description_md") or ""))} This is your data as CalCOFI.io would publish it: its catalog page, the species and measurement pages it joins, the Explorer and the Finder. We are grateful for the contribution, {e(thanks_to)}, and nothing goes public until you say so below.</p>
  {f'<dl class="pv-nums">{nums}</dl>' if nums else ''}
</section>

<h2>Click through it</h2>
<div class="pv-doors">{doors}</div>

<div class="pv-note"><b>Spot something off?</b> Every CalCOFI.io page and the Explorer have a <i class="cc-i cc-i-ui-feedback" aria-hidden="true"></i> <b>Feedback</b> button in the header: it takes a screenshot you can mark up and sends it with your note straight to the CalCOFI data team, privately. (The ingest notebook has no button; say it in the comments below.)</div>

<h2>Your decision</h2>
<p>{e(b.get("consent_question", ""))}</p>
<form method="post" action="{base}/consent" class="pv-form">
  <input type="hidden" name="build_id" value="{e(str(b.get("build_id")))}">
{whoami}  <fieldset>
    <legend>How CalCOFI.io will credit it</legend>
    <p class="pv-hint">Pre-filled with what we hold. Edit anything that should read differently; it is recorded with your decision.</p>
    <label>Citation <span class="pv-hint">(how users are asked to cite the dataset)</span><textarea name="citation_main">{e(att.get("citation_main") or "")}</textarea></label>
    <div class="pv-two">
      <label>Licence <span class="pv-hint">(e.g. CC BY 4.0, CC0)</span><input type="text" name="license_name" value="{e(lic)}" maxlength="200"></label>
      <label>Licence or terms URL<input type="url" name="license_url" value="{e(att.get("license_url") or "")}" maxlength="500"></label>
    </div>
    <label>Acknowledgement <span class="pv-hint">(funders, crew, programmes; optional)</span><textarea name="acknowledgement">{e(att.get("acknowledgement") or "")}</textarea></label>
  </fieldset>
  <div class="pv-choice">
    <label><input type="radio" name="decision" value="yes" required> <span><b>Yes, publish it as shown</b> — it joins the next public release of the integrated database and CalCOFI.io.</span></label>
    <label><input type="radio" name="decision" value="not_yet"> <span><b>Not yet</b> — say what should change below; we fix it and send a new preview.</span></label>
  </div>
  <label>Comments<textarea name="comment"></textarea></label>
  <p><button type="submit" class="pv-btn">Record my decision</button></p>
</form>
{f'<h2>Recorded</h2><table class="pv-tbl"><tr><th>when (UTC)</th><th>who</th><th>decision</th><th>comment</th></tr>{rows}</table>' if rows else ''}
{f'<h2>Feedback received</h2><table class="pv-tbl"><tr><th>when (UTC)</th><th>from</th><th>note</th><th>view</th></tr>{fb_rows}</table>' if fb_rows else ''}
"""
    return page(name, email, body)


def dataset_file(slug: str, path: str, email: str | None, store, via: str, request: Request | None = None):
    b = allowed_build(email, slug, store, via)
    if path == "" or path.endswith("/"):
        path += "index.html"
    try:
        name = safe_path("datasets", slug, str(b["build_id"]), path)
    except ValueError:
        raise HTTPException(400, "bad path") from None
    return stream(store, name, "not in this build", request)


def dataset_data(slug: str, path: str, email: str | None, store, via: str, request: Request | None = None):
    """The candidate release the build's site and Explorer read: only under the build's data_roots,
    so neither access.csv nor consent/ nor another dataset's build can be reached this way."""
    b = allowed_build(email, slug, store, via)
    try:
        name = safe_path(path)
    except ValueError:
        raise HTTPException(400, "bad path") from None
    roots = [safe_path(r) for r in b.get("data_roots", [])]
    if not any(name.startswith(r + "/") for r in roots):
        raise HTTPException(404, "not in this preview")
    return stream(store, name, "not in this preview", request)


RANGE_RE = re.compile(r"^bytes=(\d*)-(\d*)$")


def stream(store, name: str, missing: str, request: Request | None = None):
    """The object, whole or by byte range (206), with HEAD answered from its size: DuckDB-WASM in the
    Explorer and the Finder reads parquet by ranges and asks HEAD first; without this it downloads
    whole objects (and the wasm bundle's HEAD was a 405)."""
    size = store.size(name)
    if size is None:
        raise HTTPException(404, missing)
    headers = {"Cache-Control": "private, no-store", "Accept-Ranges": "bytes"}
    ctype = content_type(name)
    if request is not None and request.method == "HEAD":
        return Response(status_code=200, media_type=ctype, headers={**headers, "Content-Length": str(size)})
    rng = request.headers.get("range") if request is not None else None
    m = RANGE_RE.match(rng) if rng else None
    if m and size > 0:
        a, b = m.group(1), m.group(2)
        if a == "" and b == "":
            raise HTTPException(416, "bad range")
        if a == "":                       # the last N bytes
            start, end = max(size - int(b), 0), size - 1
        else:
            start = int(a)
            end = size - 1 if b == "" else min(int(b), size - 1)
        if start > end or start >= size:
            return Response(status_code=416, headers={**headers, "Content-Range": f"bytes */{size}"})
        chunks = store.stream(name, start, end)
        return StreamingResponse(chunks, status_code=206, media_type=ctype,
                                 headers={**headers, "Content-Range": f"bytes {start}-{end}/{size}",
                                          "Content-Length": str(end - start + 1)})
    chunks = store.stream(name)
    if chunks is None:
        raise HTTPException(404, missing)
    return StreamingResponse(chunks, media_type=ctype, headers={**headers, "Content-Length": str(size)})


def consent(slug: str, decision: str, comment: str, build_id: str, name: str, email_typed: str,
            email: str | None, store, via: str, attribution: dict | None = None) -> RedirectResponse:
    b = allowed_build(email, slug, store, via)
    key = b.get("dataset_key", slug)
    if decision not in DECISIONS:
        raise HTTPException(400, f"decision must be one of {DECISIONS}")
    if str(b.get("build_id")) != build_id:
        # the page was older than the build now on show: they decided on something else
        raise HTTPException(409, "this preview was updated while you had it open; reload and review it again")
    if link_mode():
        # nobody signed in: the reviewer says who they are, and the record says it was typed
        if not name.strip() or not EMAIL_RE.match(email_typed.strip()):
            raise HTTPException(400, "a name and an email address are needed with the decision")
        rec = consent_record(key, email_typed.strip().lower(), decision, comment, b, name=name, via="link",
                             attribution=attribution)
    else:
        rec = consent_record(key, email, decision, comment, b, via="iap", attribution=attribution)
    try:
        store.write_new(consent_object_name(rec), json.dumps(rec, indent=2).encode(), "application/json")
    except Exists:
        raise HTTPException(409, "a decision was already recorded this second; reload") from None
    return RedirectResponse(f"{url_base(slug)}/", status_code=303)


FEEDBACK_FIELDS = ("app", "kind", "label", "title", "link", "datasets", "url", "release", "viewport", "theme",
                   "text", "email", "user_agent")
FEEDBACK_MAX_IMAGE = 8 * (1 << 20)


async def feedback(request: Request, slug: str, email: str | None, store, via: str) -> JSONResponse:
    """What the site's and the Explorer's Feedback dialogs POST (text/plain JSON, the Apps Script's
    shape): kept in the private bucket as feedback/{key}/{utc}_{id}.json (+ .png), never a public
    issue, and listed on the dataset's page for the team and the provider."""
    b = allowed_build(email, slug, store, via)
    key = b.get("dataset_key", slug)
    try:
        payload = json.loads((await request.body()).decode("utf-8"))
        assert isinstance(payload, dict)
    except (ValueError, AssertionError, UnicodeDecodeError):
        return JSONResponse({"ok": False, "error": "not a JSON object"}, status_code=400)
    text = str(payload.get("text") or "").strip()
    if not text and not payload.get("title"):
        return JSONResponse({"ok": False, "error": "nothing to send"}, status_code=400)
    now = datetime.now(timezone.utc)
    fid = secrets.token_hex(4)
    stamp = now.strftime("%Y%m%dT%H%M%SZ")
    rec = {k: (",".join(payload[k]) if isinstance(payload.get(k), list) else str(payload.get(k) or ""))[:4000]
           for k in FEEDBACK_FIELDS if payload.get(k) not in (None, "")}
    rec.update({"dataset_key": key, "build_id": b.get("build_id"), "recorded_utc": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "id": fid, "via": via, "signed_in": email or ""})
    img = str(payload.get("image") or "")
    if img.startswith("data:image/png;base64,"):
        try:
            png = base64.b64decode(img.split(",", 1)[1], validate=True)
        except (binascii.Error, ValueError):
            return JSONResponse({"ok": False, "error": "the image is not base64 PNG"}, status_code=400)
        if len(png) > FEEDBACK_MAX_IMAGE:
            return JSONResponse({"ok": False, "error": "the image is too large"}, status_code=413)
        rec["image"] = f"{stamp}_{fid}.png"
        store.write_new(f"feedback/{key}/{rec['image']}", png, "image/png")
    store.write_new(f"feedback/{key}/{stamp}_{fid}.json", json.dumps(rec, indent=2).encode(), "application/json")
    return JSONResponse({"ok": True, "id": fid, "private": True})


def feedback_image(slug: str, name: str, email: str | None, store, via: str) -> StreamingResponse:
    b = allowed_build(email, slug, store, via)
    key = b.get("dataset_key", slug)
    try:
        obj = safe_path("feedback", key, name)
    except ValueError:
        raise HTTPException(400, "bad path") from None
    if not name.endswith(".png"):
        raise HTTPException(404, "not found")
    return stream(store, obj, "not found")


def attribution_form(citation_main: str, license_name: str, license_url: str, acknowledgement: str) -> dict:
    return {"citation_main": citation_main, "license_name": license_name, "license_url": license_url,
            "acknowledgement": acknowledgement}


# the routes: /d/{key}/… answers in iap mode, /{key}/{token}/… in link mode. The /d/ family is
# declared first so /d/<x>/ never parses as key "d" + token "<x>".

@app.get("/d/{slug}/", response_class=HTMLResponse)
def dataset_iap(slug: str, email: str | None = Depends(who), store=Depends(get_store)):
    return dataset(slug, email, store, "iap")


@app.api_route("/d/{slug}/f/{path:path}", methods=["GET", "HEAD"])
def dataset_file_iap(request: Request, slug: str, path: str, email: str | None = Depends(who), store=Depends(get_store)):
    return dataset_file(slug, path, email, store, "iap", request)


@app.api_route("/d/{slug}/data/{path:path}", methods=["GET", "HEAD"])
def dataset_data_iap(request: Request, slug: str, path: str, email: str | None = Depends(who), store=Depends(get_store)):
    return dataset_data(slug, path, email, store, "iap", request)


@app.post("/d/{slug}/consent")
def consent_iap(slug: str, decision: str = Form(...), comment: str = Form(""), build_id: str = Form(...),
                name: str = Form(""), email_typed: str = Form("", alias="email"),
                citation_main: str = Form(""), license_name: str = Form(""), license_url: str = Form(""),
                acknowledgement: str = Form(""),
                email: str | None = Depends(who), store=Depends(get_store)):
    return consent(slug, decision, comment, build_id, name, email_typed, email, store, "iap",
                   attribution_form(citation_main, license_name, license_url, acknowledgement))


@app.post("/d/{slug}/feedback")
async def feedback_iap(request: Request, slug: str, email: str | None = Depends(who), store=Depends(get_store)):
    return await feedback(request, slug, email, store, "iap")


@app.get("/d/{slug}/fb/{name}")
def feedback_image_iap(slug: str, name: str, email: str | None = Depends(who), store=Depends(get_store)):
    return feedback_image(slug, name, email, store, "iap")


def _slug(key: str, token: str) -> str:
    slug = link_slug(key, token)
    if slug is None:
        raise HTTPException(404, f"no preview of {key}")
    return slug


@app.get("/{key}/{token}/", response_class=HTMLResponse)
def dataset_link(key: str, token: str, email: str | None = Depends(who), store=Depends(get_store)):
    return dataset(_slug(key, token), email, store, "link")


@app.api_route("/{key}/{token}/f/{path:path}", methods=["GET", "HEAD"])
def dataset_file_link(request: Request, key: str, token: str, path: str, email: str | None = Depends(who), store=Depends(get_store)):
    return dataset_file(_slug(key, token), path, email, store, "link", request)


@app.api_route("/{key}/{token}/data/{path:path}", methods=["GET", "HEAD"])
def dataset_data_link(request: Request, key: str, token: str, path: str, email: str | None = Depends(who), store=Depends(get_store)):
    return dataset_data(_slug(key, token), path, email, store, "link", request)


@app.post("/{key}/{token}/consent")
def consent_link(key: str, token: str, decision: str = Form(...), comment: str = Form(""),
                 build_id: str = Form(...), name: str = Form(""), email_typed: str = Form("", alias="email"),
                 citation_main: str = Form(""), license_name: str = Form(""), license_url: str = Form(""),
                 acknowledgement: str = Form(""),
                 email: str | None = Depends(who), store=Depends(get_store)):
    return consent(_slug(key, token), decision, comment, build_id, name, email_typed, email, store, "link",
                   attribution_form(citation_main, license_name, license_url, acknowledgement))


@app.post("/{key}/{token}/feedback")
async def feedback_link(request: Request, key: str, token: str, email: str | None = Depends(who), store=Depends(get_store)):
    return await feedback(request, _slug(key, token), email, store, "link")


@app.get("/{key}/{token}/fb/{name}")
def feedback_image_link(key: str, token: str, name: str, email: str | None = Depends(who), store=Depends(get_store)):
    return feedback_image(_slug(key, token), name, email, store, "link")
