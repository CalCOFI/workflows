# CTD team PostgreSQL — server accounts, upgrades, GCS backups, DuckDB bridge

**Status:** APPROVED 2026-08-19 (D6 changed to keep the 200 GB ssd; all else default) — **executed 2026-08-19**, see
"Progress" at the end for what landed and what is left.
**Written:** 2026-08-17. Repos touched: `CalCOFI/server`, `CalCOFI/docs`, `CalCOFI/calcofi4r`,
`CalCOFI/workflows` (+ `calcofi4db`).

The ask: give the CTD cast team (Rasmus, Ben G, Kelsey, Betty, Erin, Ben B) a shared,
multi-user read/write PostgreSQL on the CalCOFI server; SSH/SFTP accounts for `/share`
and SSH-tunnelled DB access; Windows + Mac instructions in `docs/`; upgrade Postgres and
pgAdmin; move DB backups off Google Drive onto a dedicated GCS bucket with cleanup and a
proven restore; bridge the PG database and the integrated DuckDB releases both ways;
and design the "whole CTD archive in the DB — originals untouched, flags and fixes as
extra columns, derived products (1 m bins) on top" pattern.

---

## 0. What I found on the server (read-only, 2026-08-17)

These reorder the work. Three of them are urgent independent of the CTD ask.

| # | Finding | Why it matters |
|---|---|---|
| **F1** | **Off-site DB backup has been failing since 2025-02-02** — every nightly `rclone sync … remote:db_backups` dies with `Drive storage quota has been exceeded` (35,854 such lines in `/share/logs/rclone`). | For 18 months the only copies of the database have been on the same VM disk as the database. This alone justifies the GCS bucket, and it goes first. |
| **F2** | **The Postgres data lives in an *anonymous* Docker volume.** Compose mounts `postgis_data:/var/lib/postgresql`, but the image declares `VOLUME /var/lib/postgresql/data`, so PGDATA got auto-volume `7ea47db1…` (6.4 GB). The named volume holds 16 KB. The official image docs say exactly this: mounts at `/var/lib/postgresql` "WILL NOT PERSIST … when the container is re-created". | A `docker compose down && up` (or `--renew-anon-volumes`, or a `docker volume prune`) starts an **empty** database. It has survived so far only because `up --force-recreate` happens to reuse anonymous volumes. Must be fixed as part of the upgrade, with a verified dump in hand first. |
| **F3** | **Debian 11 (bullseye) LTS ends 2026-08-31** — two weeks from now. Host also runs Docker 20.10.17 / Compose 2.6.0 (mid-2022). | We are about to hand out five new SSH accounts on a host that stops receiving security updates this month. Not part of the ask, but it belongs in the same maintenance window. |
| F4 | `postgis/postgresql.conf` bind-mount is a **no-op**: `SHOW config_file` = `/var/lib/postgresql/data/postgresql.conf`. The container runs plain `postgres` (no `-c config_file=`), so every setting is the 128 MB-`shared_buffers` default on a 15 GB / 4-vCPU `n2-standard-4`. | The tuning we think we have, we don't. Fix by passing `-c` flags in `command:` (or `-c config_file=`), and delete the vestigial 800-line copy of the sample conf. |
| F5 | Versions: PostgreSQL **17.1** (`postgis/postgis:17-3.5`, image pulled Nov 2024, bullseye-based), PostGIS 3.5.0, pgAdmin **8.x** (`dpage/pgadmin4:latest` pulled 21 months ago; current is **9.17**), `postgres-backup-local:17`. Available now: `postgis/postgis:18-3.6`, `pgduckdb/pgduckdb:18-v1.1.1`, `dpage/pgadmin4:9.17`, `postgres-backup-local:18`. | PG 18 + PostGIS 3.6 + pg_duckdb 1.1.1 all line up on the same major, so we can go straight to 18 rather than 17.x-then-18. |
| F6 | The `gis` database is 5.4 GB: legacy 2022 schemas `public` (89 tables), `dev`, `dev_0`, `dev_ref`, `prod`. Roles: `admin` (superuser, from `.env PASSWORD`), `mfrants`, `root` (superusers), `ro_user`. Consumers still on it: `pg_tileserv` (tile.calcofi.io), `plumber` (api.calcofi.io, superseded but live), pgAdmin (one user, one server). | Keep `gis` as-is for those; the CTD work goes in a **new database `calcofi`** — separate permissions, separate backups, no collision with the legacy schema. |
| F7 | Network: GCP firewall allows only 22/80/443 (+3389 RDP with nothing listening). Port 5432 is published `0.0.0.0` in compose but **not** reachable from the internet. `pg_hba`: `scram-sha-256` from any host, `trust` on loopback inside the container. sshd: key-only (`PasswordAuthentication no`), OS Login on at project level, `AuthorizedKeysCommand google_authorized_keys` **and** local `authorized_keys` both honoured (that is how your local `bebest`, uid 1003, logs in), SFTP subsystem on. | Tunnel-only DB access already holds; no need to open 5432. Local users + `authorized_keys` is the proven path, and it is the only way to get the requested short usernames (OS Login would mint `rswalethorp_ucsd_edu`, `bhuang0022_gmail_com`). |
| F8 | Disk: `/` 40 GB (18 free), `/ssd` 200 GB pd-ssd (66 free). `/share/pg_backups` is already 18 GB (7 daily × 1 GB gz + weekly + monthly + `_old`). | A `calcofi` DB with the 1 m CTD archive adds ~10–15 GB of tables and ~2–3 GB per daily dump. Either shrink local retention (GCS becomes the long store) or resize `ssd` — probably both. |
| F9 | Two 2022 SQL dumps sit at the top of the **public** `gs://calcofi-db/` bucket (`calcofi06282022.sql`, `calcofidb06142022.sql`). | Move them into the private backup bucket. |
| F10 | `/share/data` already has a precedent: `data_uploads/` owned by `upload_group` (gid 1005: `mfrants_ucsd_edu`, `edweber_ucsd_edu`), and Marina's `1CTD_Downcast_1993-1999.csv` … `CTD_Upcast_1993_2019wLineNo.csv` extracts (3.5 GB). | Reuse the pattern (setgid group dir), not the group name; and those CSVs are probably what the CTD team means by "the archive" — worth confirming what they are. |
| F11 | Ben already has two host identities: local `bebest` (uid 1003, key `~/.ssh/google_compute_engine`) and OS Login `bebest_ucsd_edu`. Betty appears twice in the ask. | Keep `bebest`; dedupe Betty; six accounts total, five new. |

---

## 1. Decisions I need from you (answer inline; defaults in **bold**)

The plan below is written to the bold defaults. Change any and I re-flow.

- **D1 — Order of operations.** **Backups → GCS first (today), then PG/pgAdmin upgrade + accounts (one maintenance window), then the CTD archive schema/bridge.** Alternative: accounts first so the team can start uploading to `/share` while the DB is upgraded.
- **D2 — PostgreSQL major.** **Go to 18 + PostGIS 3.6 now** (dump/restore, ~1–2 h downtime for `gis` consumers: tile.calcofi.io, api.calcofi.io, pgadmin). Alternative: 17.x latest minor (in-place, ~10 min) and revisit 18 later. Only real argument for staying on 17 is caution; every piece we need has an 18 build.
- **D3 — Where the CTD work lives.** **New database `calcofi`** (schemas `ctd`, `work`, one personal schema per user), `gis` untouched. Alternative: new schemas inside `gis`.
- **D4 — pgAdmin login.** **Google sign-in (OAuth2/OIDC) with an explicit allowlist**, internal `admin` account kept as break-glass. Alternative: internal pgAdmin accounts (email + password) that I create with `setup.py add-user`. Google needs a one-time OAuth client in `ucsd-sio-calcofi` (~20 min); consent screen in *Testing* mode with the six emails as test users, so Betty's gmail works and no one else can log in. Internal accounts are simpler to set up and one more password for users to lose.
- **D5 — Host OS.** **In-place upgrade Debian 11 → 12 (bookworm) plus Docker/Compose from Docker's repo, in the same window, after a disk snapshot.** Alternative: defer (accepting an unpatched host), or rebuild the VM on Debian 13 (bigger, its own plan).
- **D6 — Disk.** **Maintain `ssd` 200 GB + short local backup retention + no raw 24 Hz archive.** Alternative: Resize `ssd` 200 → 500 GB pd-ssd (~+$50/mo) online, no downtime.
- **D7 — Which "original data" goes in first.** **The calcofi.org db-CSV products (1 m-binned final/preliminary, every column verbatim; ~8 GB CSV, ~13 M scans, all 22 QC columns).** Then, as phase 2 if wanted, the Sea-Bird `.asc`/`.hdr`/`.btl` full-rate files (32.7 GB text, ~300–400 M scans — needs D6 and partitioning). Also confirm what Marina's `*CTD_Downcast_*.csv` files in `/share/data` are.
- **D8 — Flag model.** **Separate ledger table `ctd.flag` (one row per scan × variable × proposal, mutable status, audit-trailed) + views that present "the wide table with extra `_qc` columns"**. Alternative: literal extra columns on the scan table with column-level `GRANT UPDATE` — simpler to see in pgAdmin, but one proposal per cell, no history, and mutable and immutable data in the same row.
- **D9 — DuckDB ↔ PG bridge depth.** **Phase 1: DuckDB's `postgres` extension only** (works today from R/Python/CLI, no server change; loads the archive and joins PG with the release). **Phase 2: custom `postgis + pg_duckdb` image** so `read_parquet('https://storage.googleapis.com/calcofi-db/…')` works *inside* Postgres/pgAdmin. pg_duckdb is 1.1.1 and its PostGIS coexistence needs a smoke test before it goes near `gis`.
- **D10 — RStudio Server accounts too?** **Yes, as an optional extra** (same usernames/uids inside the `rstudio` container so rstudio.calcofi.io works with `host = "postgis"` and no tunnel). Costs an image rebuild (~1 h) or a runtime `useradd`; per-user passwords instead of the shared `.env PASSWORD` the current `add_users.sh` bakes in.
- **D11 — Bucket name.** **`gs://calcofi-backups`** (private, versioned, lifecycle) with prefixes `postgres/`, `pgadmin/`, `server-config/`. Alternative: `calcofi-db-backups` (DB-only) or a `pg_backups/` prefix in the existing private `calcofi-files-private`.
- **D12 — sudo/docker for the new users?** **No.** `docker` group is root-equivalent. Only `bebest`/`admin` keep it. Users get their home, `/share/data/ctd` (group-writable), the DB roles, and nothing else.

---

## 2. Target state (one picture)

```
laptop (Mac / Windows / Linux)                        shiny-server (GCE, us-central1-a)
────────────────────────────                          ─────────────────────────────────
ssh -N calcofi   ───── 22 (key only) ─────►  sshd ─┐   /share/data/ctd/{incoming,archive,exports}
  (LocalForward 5432 → localhost:5432)             │   users: rswalethorp bmgire kdvogel bhuang
sftp / Cyberduck / WinSCP ─── 22 ─────────►        │          esatterthwaite bebest  (group calcofi)
                                                   ▼
psql / pgAdmin-desktop / DBeaver / R (RPostgres)  127.0.0.1:5432 ──► [postgis] postgis/postgis:18-3.6 (+ pg_duckdb, phase 2)
Python (psycopg / SQLAlchemy) / DuckDB ATTACH        │                 db gis      (legacy, unchanged)
                                                     │                 db calcofi  schemas ctd | work | <user>
browser ── https://pgadmin.calcofi.io (Google login) ─┘ ◄── caddy ──► [pgadmin] dpage/pgadmin4:9.17
                                                                              │
[pg_backups] postgres-backup-local:18  ──► /share/pg_backups/{daily,weekly,monthly}
[rclone]     nightly  rclone sync ──────► gs://calcofi-backups/postgres/   (SA key, versioning, lifecycle)
                                          + weekly restore drill into a scratch DB, result → GCS + log

DuckDB release  gs://calcofi-db/ducklake/releases/{version}/parquet  ◄──── read_parquet() from PG (pg_duckdb)
                 ▲                                                    ────► ATTACH … TYPE postgres from any DuckDB client
                 └── accepted flags/fixes snapshotted to GCS parquet → ingest_calcofi_ctd-cast.qmd (measurement_qual)
```

---

## 3. Workstreams

### WS0 — Safety net *before anything else* (today, ~30 min, no downtime)

1. Snapshot both disks (`gcloud compute disks snapshot shiny-server ssd --zone us-central1-a`).
2. Take a manual full dump off-box now, using the SA the `rclone` container already has
   (it holds `objectAdmin` on `calcofi-files-private`, which is private):
   `docker exec postgis pg_dumpall -U admin --globals-only` + `pg_dump -U admin -Fc gis` →
   `/share/pg_backups/manual/2026-08-17/` → `rclone copy … gcs-calcofi-sa:calcofi-files-private/pg_backups_manual/`.
3. Verify the copy (`rclone check`), record sizes/md5 in the session notes.

Everything after this is recoverable.

### WS1 — Backups: local rotation → GCS, with cleanup, a restore drill and a heartbeat

**Bucket** (`server/rclone/setup_service_account.sh` gets `calcofi-backups` added to `BUCKETS`; a
sibling `setup_backup_bucket.sh` creates it):
- `gs://calcofi-backups`, `us-central1`, uniform bucket-level access, **no** public IAM,
  Standard class, **Object Versioning on**, lifecycle: delete noncurrent versions after 90 d;
  optionally `SetStorageClass NEARLINE` at age 30 d for `postgres/monthly/`.
- IAM: `calcofi-admin@…` SA → `roles/storage.objectAdmin` on this bucket only (it already
  cannot list buckets project-wide, fine). Ben's user gets viewer.
- Move F9's two public dumps here (`postgres/legacy-2022/`) and delete them from `calcofi-db`.

**Producer** (`pg_backups` service): bump image to `:18` after WS2 (pg_dump must be ≥ server);
`POSTGRES_DB=gis,calcofi` (comma list is supported); keep `-Z6 --blobs` plain-SQL gz (the
README's `gunzip | psql` restore path stays valid; `-Fc` would enable parallel/partial
restore — optional, revisit once `calcofi` is big); retention **local** `KEEP_DAYS=7 / WEEKS=4 / MONTHS=3`,
**GCS** = mirror of local + versioning (a bad day still leaves 90 d of noncurrent copies).
Also dump `/share/pgadmin/pgadmin4.db` (pgAdmin users/servers) and the `server/.env` +
`/share/rclone/rclone.conf` into `server-config/` (encrypted with `rclone crypt` or `age`
— they contain secrets; decide, default **`age` with a key kept in Ben's password manager**).

**Shipper** (`server/rclone/backup.sh`, container cron `30 0 * * *`): replace `remote:db_backups`
(Drive, quota-dead) with
`rclone sync /share/pg_backups gcs-calcofi-sa:calcofi-backups/postgres --links --exclude "_old/**" -v`
(`--links` fixes the four `*-latest.sql.gz` symlink NOTICEs). Then write
`postgres/_status/last_success.json` (timestamp, files, bytes) so "did last night's backup
run" is a one-line `rclone cat`. Retire the Drive `[remote]` from the backup path (leave the
remote for now; delete once nothing references it).

**Restore drill** (`server/scripts/pg_restore_drill.sh`, weekly cron on host, ~10 min):
pull `postgres/daily/gis-latest.sql.gz` from GCS (not local — the drill must prove the
off-site copy), restore into `gis_drill` on the live server (`createdb` → `gunzip | psql`),
compare table count and a few row counts against live, `dropdb`, append a line to
`/share/logs/pg_restore_drill` and to `_status/last_drill.json`. This is the "confirm that
backup works" step, and it keeps confirming.

**Heartbeat**: a `healthchecks.io` (free) ping at the end of `backup.sh` and the drill, or
an Uptime check in the existing `CalCOFI/uptime` repo against a tiny status page Caddy
serves from `_status/`. Default **healthchecks.io ping** — zero code, emails on silence.

**README**: rewrite the `Restore database` section (it still says Drive; add the GCS path,
`calcofi` DB, and the drill).

### WS2 — PostgreSQL 18 + PostGIS 3.6, fixed volume, real config, new `calcofi` DB

Maintenance window ~1.5 h (only `gis` consumers notice: tile/api/pgadmin; rstudio, shiny,
erddap, h3t unaffected).

1. **Compose changes** (`server/docker-compose.yml`, service `postgis`):
   - `image: postgis/postgis:18-3.6` (or the WS7 custom image `calcofi-postgis:18-3.6-duckdb`).
   - Volume: `postgis_data:/var/lib/postgresql` — *keep the same mount* because 18's
     `VOLUME` **is** `/var/lib/postgresql` (PGDATA `/var/lib/postgresql/18/docker`). The
     anonymous PGDATA volume becomes irrelevant; keep it until the restore is verified, then
     `docker volume rm 7ea47db1…`. Add a comment block explaining F2 so nobody "cleans it up".
   - `command:` with explicit settings (fixes F4; conservative for a shared 15 GB box):
     `shared_buffers=2GB effective_cache_size=6GB work_mem=64MB maintenance_work_mem=1GB
     max_wal_size=4GB random_page_cost=1.1 max_parallel_workers_per_gather=2
     shared_preload_libraries=pg_stat_statements[,pg_duckdb] log_connections=on
     log_min_duration_statement=5s log_statement=ddl track_io_timing=on timezone=UTC`.
     Delete `postgis/postgresql.conf` (dead) or replace it with a 20-line file used via
     `-c config_file=` — default **`-c` flags** (visible in the diff, no mount).
   - `ports: "127.0.0.1:5432:5432"` (defense in depth; the tunnel and the containers'
     `host=postgis` are unaffected). Same treatment for pgadmin 8088 while there.
   - `healthcheck: pg_isready -U admin` instead of `exit 0`.
2. **Migration** (`server/scripts/pg_upgrade_18.sh`, idempotent steps, dry-run first):
   `pg_dumpall --globals-only` + `pg_dump -Fc gis` (fresh, into `/share/pg_backups/manual/`)
   → `docker compose stop postgis pg_backups pg_tileserv plumber pgadmin` → `up -d postgis`
   with the new image (initdb creates `admin` from `.env PASSWORD`, so tileserv/plumber/pgAdmin
   credentials survive) → restore globals (drop `root` superuser? — **keep**, restore is
   noisy otherwise; revoke SUPERUSER from `mfrants`/`root` later with Marina's OK) → `createdb gis`
   → `pg_restore -j4 -d gis` (PostGIS 3.5 → 3.6 via dump/restore is supported; if
   `pg_restore` chokes on postgis internals use `postgis_restore.pl`) → sanity queries
   (`postgis_full_version()`, table counts vs pre-dump) → start dependents → check
   tile.calcofi.io, api.calcofi.io, pgadmin.calcofi.io. Rollback = the old image tag + the
   untouched anonymous volume (that is why it stays until verified).
3. **New database `calcofi`** (`server/postgis/init/calcofi.sql`, applied by the script — *not*
   via `docker-entrypoint-initdb.d`, which only runs on an empty cluster):
   - Extensions: `postgis`, `pg_stat_statements`, `pgcrypto`, `pg_trgm` (+ `pg_duckdb` phase 2).
   - Group roles: `calcofi_reader` (SELECT everywhere), `calcofi_writer` (reader + INSERT/UPDATE/DELETE
     in `work` and on `ctd.flag*`; CREATE in `work` and own schema), `calcofi_curator`
     (writer + accept/reject flags), `calcofi_loader` (INSERT into `ctd.file`/`ctd.scan`),
     `calcofi_admin` (owns schemas; CREATEROLE). Service roles: `calcofi_pipeline`
     (reader; used by workflows), `calcofi_app` (reader; ctd-qaqc app).
   - Schemas: `ctd` (owner `calcofi_admin`), `work` (shared scratch), `"$user"` personal
     schemas; `ALTER DATABASE calcofi SET search_path = "$user", work, ctd, public`.
   - **Default privileges per creating role** — the classic multi-user trap: a table Rasmus
     creates in `work` is his and nobody else can write it unless
     `ALTER DEFAULT PRIVILEGES FOR ROLE rswalethorp IN SCHEMA work GRANT … TO calcofi_writer`
     was run. The provisioning script (WS4) does this for every user it creates.
   - `pg_hba` stays image-default (`scram-sha-256` from any host); no `trust` beyond loopback.
4. **Consumers of `gis`**: `pg_tileserv:latest` (already floating; recreate), `plumber`
   (RPostgres in the image, fine), `pgadmin` (re-register server after WS3).
5. **calcofi4r's deprecated `cc_db_connect()`** still targets `gis`/`admin`/`~/.calcofi_db_pass.txt`;
   WS6 supersedes it.

### WS3 — pgAdmin 9.17, Google login, pre-registered shared server

- `image: dpage/pgadmin4:9.17` (pin; bump deliberately). `/share/pgadmin` stays the mapped
  dir (`pgadmin4.db` upgrades in place; keep the `.prev.bak` habit — the container makes one).
- **Auth (D4 default)** via `PGADMIN_CONFIG_*` env → `config_distro.py`:
  `AUTHENTICATION_SOURCES = ['oauth2','internal']`,
  `OAUTH2_CONFIG = [{'OAUTH2_NAME':'google','OAUTH2_DISPLAY_NAME':'Google',
  'OAUTH2_CLIENT_ID':…,'OAUTH2_CLIENT_SECRET':…,
  'OAUTH2_SERVER_METADATA_URL':'https://accounts.google.com/.well-known/openid-configuration',
  'OAUTH2_SCOPE':'openid email profile','OAUTH2_ICON':'fa-google','OAUTH2_BUTTON_COLOR':'#4285F4'}]`,
  **`OAUTH2_AUTO_CREATE_USER = False`** (allowlist, not open door) — users pre-created with
  `python /pgadmin4/setup.py add-user <email> <random>` (their password is irrelevant under
  OAuth), plus the Google consent screen in *Testing* mode listing the six emails. Redirect
  URI `https://pgadmin.calcofi.io/oauth2/authorize`. Client id/secret go in `.env`.
  `MASTER_PASSWORD = True` so saved DB passwords are encrypted per user.
- **Server registration**: as `ben@ecoquants.com`, register `calcofi @ postgis:5432` and
  `gis @ postgis:5432` and **share** them (pgAdmin "shared servers") — every user sees them
  and supplies *their own* DB password on connect. `PGADMIN_SERVER_JSON_FILE` only loads on
  first launch, so sharing via the UI (or `setup.py load-servers --user`) is the reliable path.
- Optional hardening: `PGADMIN_CONFIG_ENHANCED_COOKIE_PROTECTION=True`, session expiry.
- Doc it in `server/README.md` (currently silent on pgAdmin beyond the compose block).

### WS4 — Host accounts (SSH + SFTP), shared folder, DB roles, one script

**Registry** in `server/users/`:
- `users.csv`: `username,uid,full_name,email,groups,pg_roles`
- `keys/<username>.pub` — public keys are safe in git; users email theirs (or paste into a
  Google Form / issue). Ben's stays as is.

| username | uid | name | email | pg roles |
|---|---|---|---|---|
| `bebest` | 1003 (exists) | Ben Best | bebest@ucsd.edu | writer, curator, admin, loader |
| `rswalethorp` | 1004 | Rasmus Swalethorp | rswalethorp@ucsd.edu | writer, curator |
| `bmgire` | 1005 | Benjamin Gire | bmgire@ucsd.edu | writer, curator |
| `kdvogel` | 1006 | Kelsey Vogel | kdvogel@ucsd.edu | writer, curator |
| `bhuang` | 1007 | Betty Huang | bhuang0022@gmail.com | writer |
| `esatterthwaite` | 1008 | Erin Satterthwaite | esatterthwaite@ucsd.edu | writer, curator |

(uids 1004–1008 are free on the host; gids 1004/1005 are taken by `bebest`/`upload_group`,
which is why users get primary group `calcofi` rather than a per-user group. Who is a
`curator` — allowed to accept/reject flags — is the team's call; default everyone but Betty.)

**Group + folder**: `groupadd -g 1500 calcofi`; `/share/data/ctd/{incoming,archive,exports}`
owned `root:calcofi`, mode `2775` (setgid → new files inherit the group), and
`/etc/profile.d/calcofi.sh` sets `umask 002` for members. Optional: reuse `upload_group`
too — no, it's Marina/Ed's; leave it. Home dirs stay on `/` (small); big files go under
`/share/data/ctd` (on `/ssd`), and the docs say so.

**Script** `server/scripts/add_user.sh <username>` (idempotent, reads the registry; `--dry-run`):
1. `useradd -m -u $uid -g calcofi -s /bin/bash -c "$full_name" $username`; install
   `keys/$username.pub` → `~/.ssh/authorized_keys` (700/600); symlinks `~/share → /share`,
   `~/data → /share/data`, `~/ctd → /share/data/ctd`.
2. Generate a 24-char DB password; `docker exec postgis psql -U admin -d calcofi -c
   "CREATE ROLE $username LOGIN PASSWORD '…' IN ROLE calcofi_writer[, calcofi_curator];
   CREATE SCHEMA AUTHORIZATION $username; ALTER DEFAULT PRIVILEGES FOR ROLE $username IN
   SCHEMA work GRANT ALL ON TABLES TO calcofi_writer; …"`.
3. Write `~/.pgpass` (`localhost:5432:*:$username:$password` and `postgis:5432:*:…` for the
   rstudio path), mode 600, owned by the user. **The secret never leaves the server**: the
   user SSHes in and reads it (`cat ~/.pgpass`), copies it to their laptop's `~/.pgpass`
   (Windows: `%APPDATA%\postgresql\pgpass.conf`), and can rotate it with `psql -c '\password'`.
   No emailed passwords.
4. (D10) `docker exec rstudio` mirror: same uid/username, `groupadd -g 1500 calcofi`,
   per-user RStudio password (`chpasswd`), the same symlinks — and add the row to
   `rstudio/users.csv` so the next image rebuild recreates them.
5. Print a one-screen summary; append to `users/PROVISIONED.md`.

`remove_user.sh` = `usermod -L`, `ALTER ROLE … NOLOGIN`, archive home to
`/share/data/_offboarded/`, revoke pgAdmin user. Offboarding is part of onboarding.

**Key policy** (goes in the docs): ed25519, passphrase-protected, one key per device is
fine, send only the `.pub`. Rotation on request. No shared accounts.

### WS5 — Documentation (`CalCOFI/docs`, public site — no secrets, no usernames)

New chapter **`server-access.qmd` — "Server Access: SSH, SFTP & PostgreSQL"**, in
`_quarto.yml` after `data-access.qmd`; cross-linked from `db.qmd` (whose Postgres section is
stale — dev/prod two-schema story, `cc_db_connect()` — prune it to point here) and from
`data-access.qmd` ("the *release* is public Parquet; the *working* CTD QC database is
Postgres, access here"). Sections, each with a Mac (Terminal) and Windows (PowerShell —
OpenSSH is built into Windows 10+, so the commands are identical) tab, PuTTY as the
alternative for people who already use it:

1. **Who this is for / getting an account** — generate a key (`ssh-keygen -t ed25519 -C you@ucsd.edu`),
   send the `.pub` to Ben; what you get (username, `/share/data/ctd`, a database role).
2. **SSH** — the `~/.ssh/config` block (`Host calcofi / HostName ssh.calcofi.io / User <you> /
   IdentityFile ~/.ssh/id_ed25519 / LocalForward 5432 localhost:5432`), then `ssh calcofi`.
   Windows: same file at `C:\Users\<you>\.ssh\config`; PuTTY: PuTTYgen import → `.ppk`,
   Pageant, Session + Connection ▸ SSH ▸ Tunnels (Source 5432, Destination localhost:5432).
   VS Code Remote-SSH gets one paragraph — it reuses the same config and gives a file browser.
3. **SFTP** — `sftp calcofi` / `scp`; GUIs: Cyberduck (Mac/Win), FileZilla, WinSCP (`.ppk`);
   where to put things (`~/ctd/incoming/`), group permissions, don't fill `/home`.
4. **PostgreSQL through the tunnel** — `ssh -N calcofi` in one terminal, then:
   `psql -h localhost -U <you> calcofi`; `~/.pgpass` (and the Windows path; line endings);
   **pgAdmin 4 desktop with its built-in SSH-tunnel tab** (no separate tunnel — likely the
   simplest GUI for Windows users), **pgadmin.calcofi.io** (zero install, Google login),
   DBeaver (also has an SSH tab). "Address already in use" → change the local port to 15432
   in both places.
5. **From R** — `calcofi4r::cc_pg_connect()` (WS6) + the plain `RPostgres` equivalent;
   `dbplyr` example; `sf::st_read(con, query=…)` for PostGIS.
6. **From Python** — `psycopg` (v3) / SQLAlchemy `postgresql+psycopg://<you>@localhost/calcofi`
   (password from `.pgpass`), `pandas.read_sql`, `geopandas.read_postgis`; and the same
   `.pgpass`. Note that a `calcofi4py` mirroring `calcofi4r` is planned (WS6).
7. **DuckDB ↔ Postgres** — `ATTACH 'dbname=calcofi user=<you> host=localhost' AS pg (TYPE postgres)`
   from R/Python/CLI DuckDB, joined with the release Parquet; and (phase 2) `read_parquet()`
   inside Postgres.
8. **The CTD QC schema** — what `ctd.scan`, `ctd.flag`, `ctd.v_scan_qc`, `ctd.scan_1m` are and
   the rules (originals never change; propose → review → accept). Written once WS8 lands.
9. **Etiquette & limits** — shared 4-vCPU box; `LIMIT` first; `\timing`; ask before
   `CREATE INDEX` on `ctd.scan`; nightly backups + weekly drill; who to contact.

Also: `docs/README.md` mentions rendering; the GH Action publishes. Screenshots for the
PuTTY/pgAdmin tunnel dialogs (I can capture them via the browser/desktop when we do it).

### WS6 — Client helpers: `calcofi4r` now, `calcofi4py` scaffold

`calcofi4r` **1.8.0** (+ NEWS, tests with `skip_if_not(nzchar(Sys.getenv("CALCOFI_PG_TEST")))`):
- `cc_pg_connect(dbname = "calcofi", host = Sys.getenv("PGHOST","localhost"), port = 5432,
  user = Sys.getenv("PGUSER", Sys.info()[["user"]]), password = NULL)` → `RPostgres`;
  `password = NULL` lets libpq read `~/.pgpass`, so nothing is hard-coded. Detects the
  server (`host = "postgis"` inside the rstudio container, as `cc_db_connect()` does).
- `cc_pg_tunnel(host = "calcofi", local_port = 5432)` — starts `ssh -N -L … <host>` via
  `processx` (works with Windows' built-in `ssh.exe`), returns the process; `cc_pg_connect()`
  can auto-start it. Optional but it turns "open a second terminal" into one R call.
- `cc_pg_attach(con_duckdb, alias = "pg", read_only = TRUE)` — `INSTALL/LOAD postgres; ATTACH …`
  so `cc_get_db()`'s DuckDB connection can join release tables with `pg.ctd.flag`.
- Formally point `cc_db_connect()`'s deprecation at `cc_pg_connect()`.

`calcofi4py` (new repo `CalCOFI/calcofi4py`, **scaffold only in this plan**): `cc_get_db()`
parity = a DuckDB connection with the release tables registered as views (same
`catalog.json` logic as R), `cc_pg_connect()` = `psycopg`, `cc_pg_attach()`. Worth
doing right after this because the CTD team is R *and* Python; I'd write it as a
follow-on plan rather than fold it in here.

### WS7 — Bidirectional DuckDB ↔ PostgreSQL

**Phase 1 (no server change) — DuckDB's `postgres` extension** (writes are fully supported:
`CREATE TABLE pg.ctd.scan AS …`, `INSERT`, `UPDATE`, `DELETE`, `COPY FROM DATABASE`,
transactions, `CALL postgres_execute('pg', '<raw SQL>')`; libpq env/`.pgpass` honoured):
- Load path for WS8: a `workflows/load_pg_ctd.qmd` (or `calcofi4db::pg_load_ctd_archive()`)
  runs **on the server** (rstudio container / host DuckDB CLI, `host=postgis`) — no tunnel
  bandwidth — reading the archive from `gs://calcofi-files-public/_sync/calcofi/ctd-cast/download/`
  (already synced nightly) or from the staged parquet on GCS, and streams into `ctd.scan`
  via binary COPY. Idempotent on `ctd.file.sha256`.
- Read path for users: `ATTACH` over the tunnel; `pg_use_ctid_scan`/binary copy make full
  scans of `ctd.flag` fast; join with `read_parquet('https://storage.googleapis.com/calcofi-db/…')`.
- Read path for the pipeline: `ingest_calcofi_ctd-cast.qmd` must not depend on a live PG
  during a run — so a nightly job on the server snapshots the *accepted* flags to
  `gs://calcofi-db/qc/ctd/flag_accepted.parquet` (DuckDB CLI on the host with `httpfs` +
  the SA's HMAC key, or pg_duckdb `COPY … TO 'gs://…'`), and the ingest reads that,
  applying it as `measurement_qual` on `obs`/`obs_ctd_full`. That is the round trip.

**Phase 2 — `pg_duckdb` inside Postgres** (`server/postgis/Dockerfile`):
`FROM postgis/postgis:18-3.6` + `COPY --from=pgduckdb/pgduckdb:18-v1.1.1` of what its
`make install` produced — `/usr/lib/postgresql/18/lib/*duckdb*` (`pg_duckdb.so` and the
`libduckdb.so` it links) and `/usr/share/postgresql/18/extension/pg_duckdb*` — plus
`apt-get install libcurl4` (the pgduckdb image is built `FROM postgres:18-bookworm`, the
same base as `postgis/postgis:18-3.6`, same PG major → ABI-compatible; verify with
`CREATE EXTENSION pg_duckdb` and a `read_parquet()` of a release file). Fallback if the copy
misbehaves: build pg_duckdb from source in a builder stage on top of the postgis image
(their Dockerfile is a straight `make -j && make install` against `postgresql-server-dev-18`). `shared_preload_libraries='pg_duckdb'` via the compose `-c`. Then in `calcofi`:
`SELECT duckdb.install_extension('httpfs')` and views like
`ctd.release_sample AS SELECT r['sample_key']::text … FROM read_parquet('https://storage.googleapis.com/calcofi-db/ducklake/releases/<v>/parquet/sample.parquet') r`
so pgAdmin users can join their flags to the release without leaving SQL. Keep
`duckdb.force_execution=false` (default): PG plans normal queries, DuckDB only runs the
lake functions; PostGIS geometry columns are not DuckDB types, so `gis` never touches it.
Smoke-test on a throwaway container before it becomes the live image.

**Considered, not now**: DuckLake with the Postgres catalog + Parquet on GCS (multi-writer
lake from any DuckDB client) — genuinely the "working DuckLake" the design docs imagined,
but consumers of the public release read HTTPS-only and could not see a PG catalog. Note it
in `db.qmd` as future direction; don't build.

### WS8 — The CTD archive in Postgres: originals immutable, flags beside, products on top

Sizing (measured from the local extraction, 151 archives): db-CSV products 16,576 files /
8.0 GB → ~13 M scan rows × ~85 columns ≈ 10–12 GB table + ~3 GB indexes; `.asc` full-rate
23,150 files / 32.7 GB → several hundred million rows (phase 2, partition by cruise).

**Schema `ctd`** (sketch; DDL lands in `server/postgis/init/ctd.sql`, loader in workflows):
- `ctd.file` — one row per source file: `file_id`, `cruise_key`, `study` (source cruise id
  `2304SH`), `archive`, `path`, `data_stage`, `cast_dir`, `sha256`, `n_bytes`, `n_rows`,
  `gcs_uri`, `loaded_at`, `loaded_by`. `UNIQUE (archive, path)`.
- `ctd.scan` — one row per scan (line), **every source column verbatim** (snake_case,
  typed numeric/smallint; blank/`NaN` → NULL; the `-99` sentinel **kept** — it *is* the
  original, the QC layer flags it), plus `scan_id`, `file_id`, `row_num` (exact line
  provenance). Indexes: `(file_id, row_num)`, `(cast_key, depth)`.
- `ctd.cast` — one row per physical cast derived from the header columns (`cruise_key`,
  `sta_id`, `cast_key`, `cast_dir`, `datetime_utc`, `lat`, `lon`, `geom`, `bottom_depth`),
  with `sample_key` = the release's `calcofi_ctd-cast:cast:<uuid>` for joins. Materialized
  from `scan` (deterministic → immutable too).
- `ctd.qual_code` — the vocabulary, seeded from `workflows/metadata/measurement_qual.csv`
  (`ctd` code set: 0 good, 1 use_primary, 2 use_secondary, 8 questionable, 9 bad_or_missing)
  plus a CalCOFI-QC-2026 set for what the team adds (bad, suspect, corrected, sentinel …),
  each with an IODE primary-flag mapping.
- `ctd.flag` (D8) — `flag_id`, `scan_id` (NULL for cast-level) / `file_id`, `variable`
  (column name or `*`), `qual_code`, `proposed_value` (NULL = flag only), `rule_key`
  (`ctd_spike_v1` when the ctd-qaqc engine proposed it), `reason`, `status`
  (`proposed|accepted|rejected|withdrawn`), `created_by DEFAULT current_user`,
  `created_at`, `reviewed_by`, `reviewed_at`, `review_note`. RLS: writers may INSERT and
  UPDATE *their own* `proposed` rows; `calcofi_curator` may set `status`; every UPDATE is
  copied to `ctd.flag_audit` by trigger. `UNIQUE (scan_id, variable) WHERE status='accepted'`.
- **Immutability**: `ctd.file/scan/cast` owned by `calcofi_admin`; `GRANT SELECT` to reader,
  `INSERT` to `calcofi_loader` only; a `BEFORE UPDATE OR DELETE` trigger that raises unless
  `SET ctd.allow_mutation = on` — belt-and-braces against an admin slip.
- **Views**: `ctd.v_scan_qc` — the wide table with an extra `<var>_qc` (accepted code) and
  `<var>_fix` (accepted proposed value) column per variable (generated by a small
  plpgsql builder over `information_schema.columns`, so it tracks the column list);
  `ctd.v_scan_clean` — accepted-bad → NULL, accepted-fix → substituted.
- **Derived**: `ctd.scan_1m` (materialized; 1 m-bin means from `v_scan_clean`, `n`, `sd`),
  `ctd.refresh_derived()` (`REFRESH … CONCURRENTLY`), nightly + on demand. Same pattern for
  standard depths / any product the team wants; each documents its SQL in the view definition.
- **Automation hooks**: the ctd-qaqc app's 16 rules (`workflows/metadata/qc_rules/`) run
  against `v_scan_qc` and INSERT `proposed` flags with `rule_key`; humans accept/reject in
  pgAdmin (or a small Shiny/`DT` editor later — the app's "review ledger" was single-writer
  DuckDB precisely because there was no PG; this is what fixes that).
- **Upload path for new cruises**: SFTP into `/share/data/ctd/incoming/<cruise>/`, then
  `ctd.load_incoming()` (loader notebook run by Ben, or a cron that only *stages*), files
  moved to `archive/`, sha256 recorded, GCS copy.

Open questions for the team (put in `metadata/calcofi/ctd-cast/questions.csv` as proposals):
which files constitute "the archive" (D7); the flag vocabulary they actually want; who is a
curator; whether the 1 m bins should be recomputed from `.asc` (phase 2) or taken from the
db-CSVs; how they want to see history (audit table vs. versioned rows).

### WS9 — Host hygiene (bundle into the same window)

- Debian 11 → 12 in place (`apt full-upgrade` bullseye→bookworm; snapshot first; expect a
  Docker package refresh; ~1 h; reboot). Docker Engine + Compose plugin from Docker's repo.
- Delete firewall rule `default-allow-rdp` (nothing listens on 3389).
- Bind Caddy-fronted container ports to `127.0.0.1` (rstudio 8787/3838, pgadmin 8088,
  plumber 8888, tileserv 7800, erddap 8090, postgis 5432) — GCP already blocks them, this
  makes it not depend on the firewall.
- `unattended-upgrades` on; 15 packages currently upgradable.
- Note `.env` holds `PASSWORD` (also RStudio `admin`), `ROPASS`, `ERDDAP_flagKeyKey`; adds
  `PGADMIN_OAUTH2_CLIENT_ID/SECRET`. Back it up encrypted (WS1).

---

## 4. Sequencing, effort, downtime

| Step | What | Downtime | Effort |
|---|---|---|---|
| 0 | WS0 snapshot + manual off-box dump | none | 0.5 h |
| 1 | WS1 bucket + IAM + `backup.sh` + drill + heartbeat; move public dumps | none | 3 h |
| 2 | WS9 OS/Docker upgrade (D5) + disk resize (D6) | ~20 min reboot; all services | 2 h |
| 3 | WS2 PG 18 + volume fix + config + `calcofi` DB + roles | ~1.5 h for gis consumers | 3 h (+ script writing 3 h) |
| 4 | WS3 pgAdmin 9.17 + Google login + shared servers | minutes | 2 h (+ OAuth client) |
| 5 | WS4 registry + `add_user.sh` + five accounts + `/share/data/ctd` | none | 3 h |
| 6 | WS5 docs chapter + screenshots; WS6 `calcofi4r` 1.8.0 | none | 6 h |
| 7 | WS7 phase 1 loader + WS8 schema + first load (db-CSV) | none | 8–12 h |
| 8 | WS7 phase 2 pg_duckdb image (smoke-tested) + release views | ~5 min restart | 3 h |
| 9 | Nightly flag snapshot → GCS → ingest round trip; ctd-qaqc rules → `ctd.flag` | none | 6 h |

Steps 0–1 this week regardless. 2–5 in one announced window (a weekday morning; tell Marina
and Ed since `gis`/tileserv/api blink). 6 in parallel. 7–9 after the team has logged in once.

Rollback per step: 0 (snapshots), 3 (old image tag + untouched anonymous volume until
verified), 4 (`pgadmin4.db.prev.bak`), 2 (disk snapshot restore).

---

## 5. Things this might remind you of (not in the ask, flagged, not planned)

- **Marina's superuser roles** (`mfrants`, `root`) — fine to keep, but the new DB should not
  inherit "everyone is superuser". Ask her before revoking on `gis`.
- **`ro_user` / `ROPASS`** — who uses it (`plumber`? old apps?). *Audited 2026-08-19 with `log_connections=on`: in 8 h of traffic, zero `ro_user` connections — everything on `gis` connects as `admin` (909 conns: tileserv/plumber/pgadmin). Safe to retire `ro_user` after a longer observation window; the bigger cleanup is that the services share the superuser.*
- **`plumber` api.calcofi.io** is documented as superseded but runs against `gis` — the PG18
  restore keeps it alive; decide separately whether to retire it.
- **Email/SMTP** — pgAdmin password resets and (if we skip healthchecks.io) backup alerts
  need an outbound mail path; the VM has none. Google login sidesteps the first.
- **Betty's gmail** vs a UCSD account: fine for SSH and internal pgAdmin; for Google OAuth
  it just needs to be on the test-user list. If the consent screen is made *Internal* later
  she would be locked out — note in the doc.
- **The `rstudio` image bakes users at build with one shared password** (`add_users.sh`,
  `.env PASSWORD`). D10 fixes the new users; the existing three inherit the old model.
- **`/share/data` is a flat 7.6 GB dumping ground** (2022–2025 CSVs, `cast_match_geom*.csv`,
  three app data dirs). Not touching it, but the CTD landing zone gives a home for the CTD
  ones, and a later tidy is worth a line in the notes.
- **OS Login is on but unused for new users**; the mixed model (OS Login for Google-identity
  admins, local users for collaborators) is fine — document it in `server/README.md` so the
  next admin does not "fix" one of the two.

---

## 6. File-by-file (what changes where)

**`CalCOFI/server`**
- `docker-compose.yml`: postgis (image 18-3.6 / custom, volume comment, `command:` flags,
  `127.0.0.1` ports, healthcheck), pg_backups (`:18`, `POSTGRES_DB=gis,calcofi`, retention),
  pgadmin (`9.17`, `PGADMIN_CONFIG_*`, OAuth env), rclone (unchanged mounts).
- `postgis/Dockerfile` (phase 2), `postgis/init/{calcofi.sql,ctd.sql,roles.sql}`,
  delete `postgis/postgresql.conf` (or shrink to overrides).
- `rclone/backup.sh` (GCS target, `--links`, status json), `rclone/setup_service_account.sh`
  (`calcofi-backups` in `BUCKETS`), new `scripts/setup_backup_bucket.sh`,
  `scripts/pg_restore_drill.sh`, `scripts/pg_upgrade_18.sh`, `scripts/add_user.sh`,
  `scripts/remove_user.sh`, `users/users.csv`, `users/keys/*.pub`, `rstudio/users.csv` (+5),
  `README.md` (backups/restore/pgadmin/users sections rewritten; F2/F4 explained).
- `.env` (not committed): `PGADMIN_OAUTH2_CLIENT_ID`, `PGADMIN_OAUTH2_CLIENT_SECRET`,
  `HEALTHCHECKS_URL`.

**`CalCOFI/docs`**: `server-access.qmd` (new), `_quarto.yml` (chapter), `db.qmd` (prune stale
Postgres, link), `data-access.qmd` (one paragraph + link), `figs/` (screenshots).

**`CalCOFI/calcofi4r`**: `R/database.R` (`cc_pg_connect`, `cc_pg_tunnel`, `cc_pg_attach`),
`DESCRIPTION` 1.8.0 (+ `processx` in Suggests), `NEWS.md`, `tests/testthat/test-pg.R`,
`man/`, `NAMESPACE`.

**`CalCOFI/workflows`**: `load_pg_ctd.qmd` (loader; `calcofi:` block with
`workflow_type: load`, excluded from release), `metadata/calcofi/ctd-cast/questions.csv`
(D7/D8 questions as `proposed`), `ingest_calcofi_ctd-cast.qmd` (read
`gs://calcofi-db/qc/ctd/flag_accepted.parquet` → `measurement_qual`, later step),
`libs/pg_ctd_ddl.R` (the `_qc/_fix` view builder if it stays in R), CLAUDE.md note.

**`calcofi4db`**: `pg_load_ctd_archive()` if the loader logic should be package-tested rather
than notebook-only (CLAUDE.md rule: scientific logic in the package).

---

## 7. First commands when you say go (WS0 + WS1 kickoff)

```bash
# WS0 — snapshots + manual off-box dump (no downtime)
gcloud compute disks snapshot shiny-server ssd --zone us-central1-a --project ucsd-sio-calcofi \
  --snapshot-names shiny-server-pre-pg18-20260817,ssd-pre-pg18-20260817
ssh calcofi 'sudo mkdir -p /share/pg_backups/manual/2026-08-17 && \
  docker exec postgis pg_dumpall -U admin --globals-only | sudo tee /share/pg_backups/manual/2026-08-17/globals.sql >/dev/null && \
  docker exec postgis pg_dump -U admin -Fc gis | sudo tee /share/pg_backups/manual/2026-08-17/gis.dump >/dev/null && \
  docker exec rclone rclone copy /share/pg_backups/manual gcs-calcofi-sa:calcofi-files-private/pg_backups_manual -v && \
  docker exec rclone rclone check /share/pg_backups/manual gcs-calcofi-sa:calcofi-files-private/pg_backups_manual'
```

Then WS1 (bucket, IAM, `backup.sh`, drill), which I would do the same day.

---

## 8. What I verified while writing this (so you don't have to re-check)

- Server facts in §0: gathered over `ssh calcofi` with read-only commands (`docker ps/inspect`,
  `psql -c` selects, `sshd -T`, metadata server, `ls`, log tails) and `gcloud … list/describe`.
- Docker Hub tags (queried 2026-08-17): `postgis/postgis:18-3.6`, `pgduckdb/pgduckdb:18-v1.1.1`
  (built `FROM postgres:18-bookworm` per its `docker-bake.hcl`/`Dockerfile`),
  `dpage/pgadmin4:9.17` (2026-07-31), `prodrigestivill/postgres-backup-local:18`.
- Official `postgres` image docs: PG 18 moved `VOLUME` to `/var/lib/postgresql` and PGDATA to
  `/var/lib/postgresql/18/docker`; for ≤17, mounting at `/var/lib/postgresql` "WILL NOT
  PERSIST" (anonymous volume) — F2. https://github.com/docker-library/docs/blob/master/postgres/content.md
- `postgres-backup-local` README: `POSTGRES_DB` accepts a comma/space list; `BACKUP_KEEP_*`,
  `BACKUP_ON_START`, `POSTGRES_EXTRA_OPTS`, `POSTGRES_CLUSTER`.
- pgAdmin: container `PGADMIN_CONFIG_*` → `config_distro.py`; `PGADMIN_SERVER_JSON_FILE` loads
  on first launch only; OAuth2 keys (`AUTHENTICATION_SOURCES`, `OAUTH2_CONFIG[…]`,
  `OAUTH2_SERVER_METADATA_URL`, `OAUTH2_AUTO_CREATE_USER`, redirect `/oauth2/authorize`);
  `setup.py add-user <email> <password> [--role|--admin] [--active]`,
  `setup.py load-servers file.json --user <email>`.
  https://www.pgadmin.org/docs/pgadmin4/latest/container_deployment.html ·
  https://www.pgadmin.org/docs/pgadmin4/latest/oauth2.html ·
  https://www.pgadmin.org/docs/pgadmin4/latest/user_management.html
- DuckDB `postgres` extension: `ATTACH '…' AS pg (TYPE postgres[, READ_ONLY])`, libpq env and
  `~/.pgpass` honoured, full write support, `COPY FROM DATABASE`, `postgres_execute()`.
  https://duckdb.org/docs/current/core_extensions/postgres/overview.html
- pg_duckdb README: `read_parquet()`/GCS via `duckdb.create_simple_secret`, `duckdb.force_execution`,
  `duckdb.install_extension('httpfs')`. https://github.com/duckdb/pg_duckdb
- Debian 11 LTS ends 2026-08-31. https://www.debian.org/releases/bullseye/ ·
  https://tuxcare.com/blog/debian-11-bullseye-hits-end-of-life/


---

## Progress (2026-08-19)

| WS | status | where |
|---|---|---|
| WS0 safety net | ✅ disk snapshots `shiny-server-pre-pg18-20260817` / `ssd-pre-pg18-20260817`; manual globals + `gis.dump` (-Fc) off-box at `gs://calcofi-backups/postgres/manual/2026-08-19/` (md5 verified) | — |
| WS1 backups → GCS | ✅ `gs://calcofi-backups` (private, versioned, lifecycle); `rclone/backup.sh` ships daily/weekly/monthly (allow-list) + `manual/` + `pgadmin4.db` nightly 00:30 UTC; `scripts/pg_restore_drill.sh` (Sun 03:15, `DRILL_DBS="gis calcofi"`) **passed**: gis 138/138 tables, rows match, 166 s; `scripts/backup_status.sh` hourly → `https://file.calcofi.io/status/pg_backup.{json,ok}`; upptime check `db-backup`; legacy 2022 dumps moved out of the public bucket; `_old/` archived to `postgres/legacy-2024/` and deleted locally | server `b80abb7..`, uptime `6b584b5` |
| WS9 host | ✅ Debian 12 (bookworm) + Docker 29.7.2 / Compose 5.5.0, kernel 6.1, rebooted, all services verified; `default-allow-rdp` deleted; unattended-upgrades on | `scripts/os_upgrade_bookworm.sh`, log `/share/logs/os_upgrade_bookworm.log` |
| WS2 PostgreSQL 18 | ✅ 18.6 + PostGIS 3.6.4 by dump/restore (`scripts/pg_upgrade_18.sh`, 0 errors, 138/138 tables, row counts match); data now in the NAMED volume; `-c` flags live (shared_buffers 2 GB…); 5432/8088 loopback; `calcofi` DB + roles + `ctd`/`work` schemas (`postgis/init/10,20,30`); pg_backups :18 dumps `gis calcofi`. **Old anonymous volume `7ea47db1…` still present for rollback — remove when comfortable (`docker volume rm`)** | log `/share/logs/pg_upgrade_18.log` |
| WS3 pgAdmin | ✅ 9.17; internal accounts for the six emails (password = their DB password via `add_user.sh`); shared servers *calcofi (CTD QA/QC)* + *gis (legacy 2022)*; OAuth plumbing in compose gated on `.env`. ⏳ **Google sign-in needs the OAuth client from the Cloud Console (README "pgAdmin" has the 3 steps)** — the console asked for Ben's Google password, which I do not enter | — |
| WS4 accounts | ✅ six host users (uid 1003–1008, group `calcofi`), DB roles + personal schemas + `~/.pgpass`, rstudio-container mirrors, `/share/data/ctd/{incoming,archive,exports}`; verified cross-user sharing in `work`, read-only `ctd`, R in rstudio with zero config. ⏳ **SSH public keys**: none received yet → `users/keys/<username>.pub` + `add_user.sh <username>` installs them | `users/users.csv`, `scripts/add_user.sh` |
| WS5 docs | ✅ `docs/server-access.qmd` (Mac/Windows/PuTTY tabs; pgAdmin desktop SSH tab; R/Python/DuckDB), `db.qmd` overview brought current, link from `data-access.qmd`; GH Action published | docs `6abf813` |
| WS6 calcofi4r | ✅ 1.8.0: `cc_pg_connect()`, `cc_pg_tunnel()`/`_close()`, `cc_pg_attach()`; tests; verified live from the laptop (tunnel 15432 → RPostgres → DuckDB ATTACH) | calcofi4r `af6eeab` |
| WS7 bridge | ✅ phase 1 (DuckDB `postgres` ext) in calcofi4r + loader; ✅ phase 2: `calcofi-postgis:18-3.6-duckdb` image (postgis + pg_duckdb 1.1.1) **live**, `duckdb.postgres_role=calcofi_reader`, `release.{cruise,ship,dataset}` views over the public Parquet (`postgis/init/50_release_views.sql`; version pinned — re-run per release). see WS7 round trip row below | — |
| WS8 CTD schema | ✅ `postgis/init/40_ctd.sql` applied: immutable `ctd.file`/`ctd.scan`/`ctd.scan_issue`, `ctd.scan_column` dictionary (54 columns mapped to measurement types + units), IODE `ctd.qual_code` + `ctd.source_qual_code`, `ctd.flag` (RLS + audit), `ctd.cast` matview, `v_scan_best`/`v_scan_qc`/`v_scan_clean`, `refresh_derived()`; rules verified in a rolled-back test. **Archive LOADED 2026-08-19**: 409 files / **10,812,360 scans** (all 82 columns verbatim), 2,558 untypable cells in `scan_issue`, 24,928 casts (20,521 best-stage, 1993-08-11 → 2026-07-13, 142 studies, every study mapped to a `cruise_key`), one best archive per study×direction, calcofi db 5.9 GB. Loader: `workflows/libs/pg_ctd.R` + `load_pg_ctd.qmd`; parquet mirror at `gs://calcofi-db/pg/ctd_scan_raw/`; manifest `data/pg/ctd_scan_raw_files.csv`. Q25 (flag vocabulary/curators) + Q26 (issue cells) filed as `proposed` in `metadata/calcofi/ctd-cast/questions.csv` | — |
| WS7 round trip | ✅ nightly `scripts/pg_flag_snapshot.sh` (host cron 01:20 UTC) exports accepted + full ledger to `gs://calcofi-db/qc/ctd/{flag_accepted,flag_ledger}.parquet` + `flag_meta.json` (public; verified). ⏳ ingest side: teach `ingest_calcofi_ctd-cast.qmd` to apply `flag_accepted.parquet` as `measurement_qual` — deliberately left until the team has accepted its first real flags | — |

Ben-only follow-ups: (1) OAuth client → `.env` → `docker compose up -d pgadmin`; (2) tell the team to send SSH public keys; (3) `docker volume rm 7ea47db1d8f315179c606ec6548b3cb3481d2c5d240c6650d4d49d218200946b` once happy (6.4 GB back); (4) your own RStudio-Server password for `bebest` is now the value in `/home/bebest/.pgpass` on the host (add_user.sh mirrored it); (5) `calcofi4py` scaffold as a follow-on plan.
