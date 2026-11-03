#!/usr/bin/env bash
# build_preview.sh — one dataset's private preview for the calcofi-preview service (preview/,
# plan 2026-11-02): calcofi.io and the Explorer, each built against the candidate release in the
# private bucket that includes the held dataset, plus the ingest notebook's render, then shown.
#
#   scripts/build_preview.sh <provider> <dataset> [notebook_html]
#
# Run from a workflows checkout holding metadata/<provider>/<dataset>/questions.csv (the consent
# row, related_field = consent). The candidate release comes first: release_database.qmd with
#   CALCOFI_RELEASE_BUCKET=calcofi-preview CALCOFI_RELEASE_PREFIX=ducklake-preview/releases
#   CALCOFI_TABLES_PREFIX=ducklake-preview/tables CALCOFI_RELEASE_INCLUDE=<provider>_<dataset>
# and gs://calcofi-preview/ducklake-preview/releases/latest.txt naming it.
#
# Env: SITE_DIR (a CalCOFI.github.io checkout with scripts/build_preview.sh, default
# ../CalCOFI.github.io), EXPLORE_DIR (a CalCOFI/explore checkout with VITE_PREVIEW, default
# ../explore), CALCOFI_PREVIEW_BUCKET (default calcofi-preview), PREVIEW_RELEASE_ROOT (default
# ducklake-preview). PREVIEW_ACCESS must match the service's: `iap` (default) shows the build at
# /d/<key>/ to the addresses access.csv grants; `link` shows it at /<key>/<token>/, token = 8 of
# [a-z0-9] minted here (or PREVIEW_TOKEN to reuse one), stored as datasets/<key>-<token>/, to
# anyone holding the link, as https://preview.calcofi.io/<key>/<token>/ (PREVIEW_HOST). Uploads as
# the active gcloud account; the build shows once current.txt names it.
set -euo pipefail

PROVIDER="${1:?provider, e.g. sio}"
DATASET="${2:?dataset, e.g. cetacean-sightings}"
NOTEBOOK="${3:-}"
KEY="${PROVIDER}_${DATASET}"
ACCESS="${PREVIEW_ACCESS:-iap}"
case "$ACCESS" in
  iap)  TOKEN=""; SLUG="$KEY"; URLBASE="/d/$KEY";;
  # minted without a pipeline: under pipefail, `tr … | head -c 8` ends the script silently
  link) TOKEN="${PREVIEW_TOKEN:-$(python3 -c 'import secrets, string; print("".join(secrets.choice(string.ascii_lowercase + string.digits) for _ in range(8)))')}"
        SLUG="$KEY-$TOKEN"; URLBASE="/$KEY/$TOKEN";;
  *)    echo "PREVIEW_ACCESS must be iap or link, not $ACCESS" >&2; exit 1;;
esac
HOST="${PREVIEW_HOST:-preview.calcofi.io}"
WF="$(pwd)"
SITE_DIR="$(cd "${SITE_DIR:-$WF/../CalCOFI.github.io}" && pwd)"
EXPLORE_DIR="$(cd "${EXPLORE_DIR:-$WF/../explore}" && pwd)"
FINDER_DIR="${FINDER_DIR:-$WF/../db-viz-station}"      # the Dataset Finder; skipped when absent
BUCKET="${CALCOFI_PREVIEW_BUCKET:-calcofi-preview}"
ROOT="${PREVIEW_RELEASE_ROOT:-ducklake-preview}"
REL="$ROOT/releases"
QUESTIONS="$WF/metadata/$PROVIDER/$DATASET/questions.csv"

case "$BUCKET" in calcofi-db|calcofi-files-public) echo "refusing the public bucket $BUCKET" >&2; exit 1;; esac
[ -f "$QUESTIONS" ] || { echo "no $QUESTIONS" >&2; exit 1; }
VERSION="$(gcloud storage cat "gs://$BUCKET/$REL/latest.txt" | tr -d '[:space:]')"
BUILD="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$(mktemp -d)/$BUILD"
mkdir -p "$OUT"
echo "preview $KEY ($ACCESS, $URLBASE/): candidate release $VERSION, build $BUILD"

# 1. calcofi.io ----
(cd "$SITE_DIR" && PREVIEW_URLBASE="$URLBASE" scripts/build_preview.sh "$KEY" "https://storage.googleapis.com/$BUCKET/$REL" "$OUT/site")

# 2. the Explorer: data through the service's /d/{key}/data/ (same origin, behind the same sign-in) ----
(cd "$EXPLORE_DIR" &&
  VITE_BASE="$URLBASE/f/explore/" VITE_DATA_URL="$URLBASE/data/" VITE_RELEASE_PREFIX="$REL" \
  VITE_PREVIEW=1 VITE_PREVIEW_HOME="$URLBASE/" VITE_SITE_URL="$URLBASE/f/site/" VITE_FEEDBACK_URL="$URLBASE/feedback" \
  npx vite build --outDir "$OUT/explore" --emptyOutDir --logLevel warn)

# 2b. the Dataset Finder (db-viz-station), its data built from the candidate, reading it through the link ----
if [ -d "$FINDER_DIR" ]; then
  scripts/build_preview_finder.sh "$(cd "$FINDER_DIR" && pwd)" "$BUCKET" "$REL" "$VERSION" "https://$HOST$URLBASE/data" "$OUT/finder"
else
  echo "no Finder checkout at $FINDER_DIR: the preview has no Finder page"
fi

# 3. the ingest notebook's render, which never goes into the public repo for a held dataset ----
# Quarto puts the page's stylesheets, scripts and widgets in a sibling <name>_files/ directory and
# references it by relative path; the page is unstyled without it (seen 2026-11-03), so it comes
# along as ingest_files/ and the references are rewritten to match.
if [ -n "$NOTEBOOK" ]; then
  NB_FILES="${NOTEBOOK%.html}_files"
  NB_NAME="$(basename "${NOTEBOOK%.html}")_files"
  if [ -d "$NB_FILES" ]; then
    cp -R "$NB_FILES" "$OUT/ingest_files"
    perl -pe "s{(?<![\\w/])\\Q$NB_NAME\\E/}{ingest_files/}g" "$NOTEBOOK" > "$OUT/ingest.html"
  else
    cp "$NOTEBOOK" "$OUT/ingest.html"
  fi
fi

# 4. build.json: what is on show and the consent question it answers ----
gcloud storage cat "gs://$BUCKET/$REL/$VERSION/datasets.json" > "$OUT/.datasets.json"
python3 - "$KEY" "$BUILD" "$VERSION" "$ROOT" "$QUESTIONS" "$OUT" "${NOTEBOOK:+1}" "$ACCESS" "$SLUG" "$TOKEN" "$URLBASE" <<'PY'
import csv, json, sys
from datetime import datetime, timezone
key, build, version, root, questions, out, notebook, access, slug, token, urlbase = sys.argv[1:12]
ds = json.load(open(f"{out}/.datasets.json"))
rec = next((d for d in ds.get("datasets", []) if d.get("dataset_key") == key), None)
if rec is None:
    sys.exit(f"{key} is not in the candidate release {version}: was it built with CALCOFI_RELEASE_INCLUDE={key}?")
consent = [r for r in csv.DictReader(open(questions)) if r.get("related_field") == "consent"]
if len(consent) != 1:
    sys.exit(f"{questions} needs exactly one consent row (related_field = consent), has {len(consent)}")
q = consent[0]
pages = [
    {"path": f"site/datasets/{key}/", "title": "Its page on CalCOFI.io", "short": "Dataset page",
     "description": "the dataset as the catalog would list it: coverage, map, variables, species, citation"},
    {"path": f"explore/?datasets={key}", "title": "In the CalCOFI Explorer", "short": "Explorer",
     "description": "map, time series and downloads, with this dataset selected"}]
import os
if os.path.isdir(f"{out}/finder"):
    pages.append({"path": f"finder/?dataset={key}&tour=off", "title": "In the Dataset Finder", "short": "Finder",
                  "description": "station by station: which variables this dataset adds, where and when"})
pages.append({"path": "site/", "title": "CalCOFI.io with it included", "short": "CalCOFI.io",
              "description": "the front page and the species and measurement pages it adds to"})
if notebook:
    pages.append({"path": "ingest.html", "title": "How it was ingested", "short": "Notebook",
                  "description": "the notebook that turns the source files into the database tables"})
# the record the landing page reads: name, provider, attribution (the citation and licence boxes
# are pre-filled from it), coverage (the numbers), description
cov = rec.get("coverage") or {}
dataset = {k: rec.get(k) for k in ("dataset_key", "dataset_name", "dataset_name_short", "description_md",
                                   "category", "provider", "attribution", "since_version", "links")}
dataset["coverage"] = {k: cov.get(k) for k in ("realm", "temporal", "year_min", "year_max", "years")}
build_json = {
    "build_id": build, "dataset_key": key,
    "dataset_name": rec.get("dataset_name") or key,
    "created_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "release_version": version, "data_roots": [root],
    # the service serves a build at /d/<slug>/ only in the mode it was built for
    "access": access, "slug": slug, "token": token, "url_path": urlbase + "/",
    "consent_question_id": q["id"], "consent_question": q["question"],
    "pages": pages, "dataset": dataset}
json.dump(build_json, open(f"{out}/build.json", "w"), indent=2)
print(json.dumps({k: build_json[k] for k in ("build_id", "dataset_name", "release_version", "consent_question_id")}))
PY
rm "$OUT/.datasets.json"

# 5. upload, then show it ----
gcloud storage cp -r "$OUT" "gs://$BUCKET/datasets/$SLUG/" --quiet
echo "$BUILD" | gcloud storage cp - "gs://$BUCKET/datasets/$SLUG/current.txt" --quiet

# 6. screenshots of the pages now on show, for the landing page's doors (link mode only: the
# pages are reachable; in iap mode nothing here can sign in) ----
if [ "$ACCESS" = link ] && [ -d "$EXPLORE_DIR/node_modules/puppeteer-core" ]; then
  urls=()
  for p in $(python3 -c "import json; print(' '.join(p['path'] for p in json.load(open('$OUT/build.json'))['pages']))"); do urls+=("https://$HOST$URLBASE/f/$p"); done
  if NODE_PATH="$EXPLORE_DIR/node_modules" node scripts/preview_shots.cjs "$OUT/shots" "${urls[@]}"; then
    python3 - "$OUT/build.json" "$OUT/shots" <<'PY2'
import json, os, sys
bj, shots = sys.argv[1:3]
b = json.load(open(bj))
for i, p in enumerate(b["pages"], 1):
    if os.path.exists(f"{shots}/{i}.png"): p["shot"] = f"shots/{i}.png"
json.dump(b, open(bj, "w"), indent=2)
PY2
    gcloud storage cp -r "$OUT/shots" "gs://$BUCKET/datasets/$SLUG/$BUILD/" --quiet
    gcloud storage cp "$OUT/build.json" "gs://$BUCKET/datasets/$SLUG/$BUILD/build.json" --quiet
  else
    echo "screenshots skipped (no page captured)"
  fi
fi
if [ "$ACCESS" = link ]; then echo "shown: https://$HOST$URLBASE/  (build $BUILD, link)"
else echo "shown: https://calcofi-preview-199066946721.us-west1.run.app$URLBASE/  (build $BUILD, iap)"; fi
