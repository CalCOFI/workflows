#!/usr/bin/env python3
"""preview_feedback_issues.py — one private GitHub issue per feedback report sent from a dataset
preview (Ben, 2026-11-04: keep organizing feedback as issues, in CalCOFI/feedback_private).

The preview service keeps each report in the private bucket as feedback/{key}/{utc}_{id}.json
(+ .png) and lists it on the dataset's landing page. This script, run on the data team's machine
(the active gcloud account reads the bucket, the gh login files the issue), files each report it
has not filed yet: the screenshot committed under shots/ in the repo, an issue labelled feedback,
preview and the dataset key, and a marker feedback/{key}/{utc}_{id}.issue.json in the bucket so
it is filed once. The repository is private: the preview link, the reviewer's name and address
and a screenshot of held data never reach a public issue.

  python3 scripts/preview_feedback_issues.py [--bucket calcofi-preview] [--repo CalCOFI/feedback_private] [--dry-run]

Schedule it (every 10 min) with a launchd agent, e.g. ~/Library/LaunchAgents/io.calcofi.preview-feedback.plist
running `source ~/.config/calcofi/env.sh; cd ~/Github/CalCOFI/workflows && python3 scripts/preview_feedback_issues.py`.
"""
import argparse
import base64
import json
import subprocess
import sys


def sh(*args, input=None):
    return subprocess.run(args, check=True, capture_output=True, text=True, input=input).stdout


def gcs_ls(bucket):
    out = subprocess.run(["gcloud", "storage", "ls", "-r", f"gs://{bucket}/feedback/**"], capture_output=True, text=True)
    return [l.strip() for l in out.stdout.splitlines() if l.strip().startswith("gs://")]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bucket", default="calcofi-preview")
    ap.add_argument("--repo", default="CalCOFI/feedback_private")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    objs = set(gcs_ls(a.bucket))
    reports = sorted(o for o in objs if o.endswith(".json") and not o.endswith(".issue.json"))
    filed = 0
    for o in reports:
        marker = o[:-5] + ".issue.json"
        if marker in objs:
            continue
        rec = json.loads(sh("gcloud", "storage", "cat", o))
        key = rec.get("dataset_key", "unknown")
        stamp = o.rsplit("/", 1)[1][:-5]
        title = f"[{key}] {rec.get('app', 'preview')}: {(rec.get('title') or rec.get('text') or '')[:70].strip() or 'feedback'}"
        lines = [f"**Dataset:** `{key}` · **app:** {rec.get('app', '')} · **build:** {rec.get('build_id', '')} · **release:** {rec.get('release', '')}",
                 f"**View:** {rec.get('url', '')}",
                 f"**Viewport:** {rec.get('viewport', '')} · **theme:** {rec.get('theme', '')} · **when:** {rec.get('recorded_utc', '')}"]
        who = ", ".join(x for x in (rec.get("name"), rec.get("email")) if x)
        if who:
            lines.append(f"**From:** {who}")
        if rec.get("link"):
            lines.append(f"**Link / DOI:** {rec['link']}")
        if rec.get("datasets"):
            lines.append(f"**Datasets in view:** {rec['datasets']}")
        lines += ["", rec.get("text") or "_(no text)_", ""]
        img = rec.get("image")
        if img:
            png = subprocess.run(["gcloud", "storage", "cat", o.rsplit("/", 1)[0] + "/" + img], capture_output=True, check=True).stdout
            path = f"shots/{img}"
            if not a.dry_run:
                sh("gh", "api", "-X", "PUT", f"repos/{a.repo}/contents/{path}", "-f", f"message=shot: {img}",
                   "-f", f"content={base64.b64encode(png).decode()}")
            lines.append(f"![the view](https://github.com/{a.repo}/blob/main/{path}?raw=true)")
        lines += ["", f"_Original: `{o}`_"]
        if a.dry_run:
            print(f"would file: {title}")
            continue
        subprocess.run(["gh", "label", "create", key, "-R", a.repo, "--color", "5319e7", "--force"], capture_output=True)
        url = sh("gh", "issue", "create", "-R", a.repo, "--title", title, "--body", "\n".join(lines),
                 "--label", f"feedback,preview,{key}").strip().splitlines()[-1]
        sh("gcloud", "storage", "cp", "-", marker, input=json.dumps({"issue_url": url, "filed_utc": stamp}))
        print(f"filed {url}  <- {o}")
        filed += 1
    print(f"{filed} filed, {len(reports)} report(s) in the bucket")


if __name__ == "__main__":
    sys.exit(main())
