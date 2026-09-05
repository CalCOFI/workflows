# Server pipeline — run the full workflows DAG on the CalCOFI server

Status: **todo** (split out of the taxon-crosswalk plan on 2026-09-02; Ben: "we do want to
eventually move everything to run on the server"). Everything measured here was read directly
from the server over ssh on 2026-09-02; re-measure before starting.

## The ask (Ben, 2026-09-02)

Run the full `targets` DAG (≈ 3 h 30 min on the laptop; `ingest_calcofi_ctd_cast` alone is
128 min) on the `shiny-server` VM routinely, so a release no longer depends on one laptop being
awake, with Google Drive sync, ERDDAP download-first, GCS upload, R/Python/package versions,
and git in a known state before every run.

## Decided (Ben, 2026-09-02)

- **Q4 · Runner and disk** — a dedicated `pipeline` compose service (same image as `rstudio`,
  `mem_limit ≈ 9 GB`, SA key mounted) and **+100 GB** on the VM (pd-balanced ≈ $10/mo).
- **Q5 · Run outputs** — the service commits the tracked outputs (`data/parquet/*/*.json`,
  `data/releases/<v>/` sidecars, `_output/*.html`, the `RELEASES.md` promotion) and **pushes
  straight to `main` with a `[pipeline]` commit prefix**. No PR.
- **Q6 · Finish the Shared Drive migration** for `cce-lter/`, `cdfw/`, `sio/` (and decide what
  `ucsd_sio 2` and `google_datasets` on the laptop are) — Ben's Drive; folded in here.

## Requirements (measured 2026-09-02)

The pipeline has only ever run on Ben's laptop (8 cores, 25.8 GB, stage dir 105 GB). Read
directly from the server over ssh today:

| | laptop | server (`shiny-server` VM) | requirement |
|---|---|---|---|
| CPU / RAM | 8 / 25.8 GB | 4 vCPU / 15 GB, **≈ 5 GB available** with the 11 containers up | a `pipeline` service with `mem_limit` and DuckDB `memory_limit` + `temp_directory` on `/ssd`; the CTD ingest is trialled alone first (a spatial join already OOM'd this box once) |
| disk | 105 GB stage | `/ssd` 197 GB, **45 GB free** (`/` 18 GB free) | a full run needs ≈ 75 GB (source mirror 18.3 + CTD zips/unzip 49 + parquet 3.6 + one release ≈ 4) → **add ≈ 100 GB** (pd-balanced ≈ $10/mo) or a `pipeline` disk |
| R | 4.6.1 | 4.6.0 (`rocker/geospatial:latest`) | fine |
| Quarto CLI | 1.8.25 | 1.9.37 | pin one version in both places |
| calcofi4db / calcofi4r | 3.28.0 / 1.16.0 | **3.4.3 / 1.12.1** | image rebuild installs from GitHub `main` at every rebuild; `pull_repos.sh` + `remotes::install_github()` before each run |
| pipeline packages | all present | **missing:** automap targets tidyjson worrms taxize quarto h3jsr rmapshaper tarchetypes | add to `server/rstudio/Dockerfile` `install2.r` |
| Python | 3.14.5 | 3.12.3 (+ calcofi4py venv) | **not used by the pipeline** (`_targets.R`, no `reticulate`); calcofi4py deploys separately — out of scope |
| source data | `~/My Drive/projects/calcofi/data-public` (personal Drive, hard-coded in `libs/ingest.R:22`) | Drive → `gs://calcofi-files-public/_sync/` nightly by the `rclone` container (631 objects, 18.3 GiB, last 2026-09-02 02:00, "nothing to transfer"); `/share/google_drive` is empty | (a) `dir_data` ← `CALCOFI_DATA_DIR`, asserted non-empty; server hydrates `/ssd/calcofi/data-public` with `rclone sync gcs-calcofi-sa:calcofi-files-public/_sync` before a run — no Drive client on the server, ever; (b) **the Shared Drive is missing `cce-lter/`, `cdfw/`, `sio/`** (present on the laptop) — finish the 2026-06 migration for those three (Ben's Drive) |
| ERDDAP / web sources | live reads in farallon (PR #77); download-first in cufes, mets, zoodb, zooscan, EDI | same | download → `data/cache/` (gitignored) → `sync_to_gcs()` archive, then read the file; `CTD_ZIP_SOURCE` already primes the CTD zips from GCS |
| GCS auth | Ben's gcloud (**expired today** — `gcloud auth login`) | host gcloud = compute default SA (storage **read-only**); `/etc/rclone/calcofi-admin-sa.json` writes `calcofi-files-public` nightly | mount the SA key as `GOOGLE_APPLICATION_CREDENTIALS` in the pipeline service; **verify it can write `gs://calcofi-db`** (release + parquet uploads) — one `buckets get-iam-policy` once Ben's gcloud is back |
| GEBCO | `CALCOFI_GEBCO_TIF` local master | only the 2023 `.nc` in `/share/data` | leave unset → `release_database.qmd` falls back to the COG over `/vsicurl/` (built for this) |
| deploy steps | `deploy_consumers`, `publish_to_erddap` ssh to the server | would ssh to itself | `CALCOFI_SSH_HOST` empty ⇒ run locally; small change in `scripts/deploy_consumers.sh` / `libs/erddap_deploy.R` |
| git | `workflows` main + **8 uncommitted files** (RELEASES.md, release_database.qmd, CLAUDE.md, notes, `_output/`); calcofi4db / calcofi4r clean and pushed | `workflows` clone at `3ee7479` (2026-08-25), behind main | the server runs `origin/main` only. Its outputs are tracked files (`data/parquet/*/*.json`, `data/releases/<v>/` sidecars, `_output/*.html`, `RELEASES.md` promotion), so **a server run must push them back** — see Q5 |
| runner | interactive laptop session (killed by the harness twice; relaunched detached) | rstudio container: shared by nine users, runs as root, no memory limit | a `pipeline` service in `server/docker-compose.yml` from the same image: `docker compose run pipeline` on demand, weekly cron, log to `/share/logs/pipeline/`, `tar_unblock_process()` on start |

**Trial sequence on the server** (each measured and appended below before the next):
1. `ingest_farallon_bird_mammal` — small; exercises download-first, GCS archive, the taxon path;
2. `release_database` under `CALCOFI_RELEASE_PREFIX=ducklake-staging/releases` — the caboose
   without touching the real prefix;
3. `ingest_calcofi_ctd_cast` alone, peak RSS and wall time recorded — the go/no-go on RAM;
4. full `tar_make()`; then the cron.


## Architecture (what changes)

```
calcofi4db
  R/stage.R   cc_data_dir()          NEW: CALCOFI_DATA_DIR (default the laptop Drive path), asserted to exist and be non-empty
workflows
  libs/ingest.R                        dir_data <- cc_data_dir()
  scripts/deploy_consumers.sh, libs/erddap_deploy.R   run locally when CALCOFI_SSH_HOST is empty
  CLAUDE.md § Deploy                   the server pipeline: how to trigger, where logs land, what it pushes
server
  rstudio/Dockerfile                   + automap targets tidyjson worrms taxize quarto h3jsr rmapshaper tarchetypes; pin quarto to one version with the laptop
  docker-compose.yml                   + pipeline service (mem_limit, GOOGLE_APPLICATION_CREDENTIALS = /etc/rclone/calcofi-admin-sa.json, /ssd/calcofi volumes, weekly cron)
  pipeline/run.sh                      NEW: pull_repos → install_github(calcofi4db, calcofi4r) → rclone sync gcs-calcofi-sa:calcofi-files-public/_sync → tar_unblock_process → tar_make → git commit "[pipeline] …" → push main
```

## Phases

| phase | what | gate | est. |
|---|---|---|---|
| A (Ben) | +100 GB disk on the VM; move `cce-lter/`, `cdfw/`, `sio/` to the Shared Drive and let the 02:00 sync mirror them; `gcloud auth login` on the laptop and confirm the SA can write `gs://calcofi-db`; commit + push the laptop's uncommitted `workflows` files. | `_sync/` shows the three folders; IAM confirmed | — |
| B | `cc_data_dir()` + `libs/ingest.R`; deploy-local switch; Dockerfile packages; compose `pipeline` service; `run.sh`. | image builds; `docker compose run pipeline Rscript -e 'targets::tar_outdated()'` lists the DAG | 5 h |
| C | The trial sequence above, each step measured and appended below: farallon → staging release → CTD alone (peak RSS is the go/no-go) → full `tar_make()`. | step 4 completes and its `[pipeline]` commit lands on `main` | 3 h + wall time |
| D | Weekly cron; CLAUDE.md § Deploy; the laptop becomes the development runner (it must `git pull` before any run, since `main` now moves without it). | one unattended weekly run succeeds | 1 h |

≈ 9 h of build time plus Ben's Phase A.

## Measured (appended per phase as it ships)

_(none yet)_

**Note from WS-F (2026-09-05):** split ichthyo's reference shards (`cruise` with its date spans, `ship`,
`grid`) into their own target, so the 15 ingests that only need the reference do not depend on the full
ichthyo ingest, and a reference-only change does not invalidate every downstream ingest. WS-F skipped the
CTD ingest with `shortcut = TRUE` behind a manual gate (the ichthyo manifest's `mismatches$cruise_uuid`
and the shard's row signature); on the server that gate should be a target dependency, not a note.
