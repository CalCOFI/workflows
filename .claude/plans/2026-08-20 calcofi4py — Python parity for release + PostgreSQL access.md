# calcofi4py — Python parity for release + PostgreSQL access

**Status:** DONE 2026-08-19/20 — https://github.com/CalCOFI/calcofi4py (0.1.0, public, CI green
on Python 3.10–3.13; 10 tests incl. the live PG pair verified through a real tunnel against the
production `calcofi` database). Docs updated: `server-access.qmd` + `data-access.qmd` Python
sections now lead with it. Departures from the draft: repo created directly on `main` (user said
"proceed"), no PyPI publish yet (`pip install git+…`).
The CTD team works in R *and* Python; today the docs hand Python users raw `duckdb` /
`psycopg` snippets (`docs/server-access.qmd`, `docs/data-access.qmd`). This plan gives them
a pip-installable package with the same three verbs as `calcofi4r`.

## Scope (deliberately small — a thin client, no analysis functions yet)

New repo **`CalCOFI/calcofi4py`** (Ben creates the repo; the code lands via PR):

| function | mirrors | behavior |
|---|---|---|
| `cc_get_db(version="latest", tables=None, supplemental=False)` | `calcofi4r::cc_get_db()` | DuckDB connection with each release table registered as a view over the public Parquet — same `latest.txt` → `catalog.json` resolution, same partitioned-table handling (`read_parquet(..., hive_partitioning=True)`), same supplemental gating |
| `cc_pg_connect(dbname="calcofi", host=None, port=None, user=None)` | `cc_pg_connect()` | `psycopg` (v3) connection; host `postgis` on-server / `localhost` off; role from `~/.pgpass` (via `passfile`; libpq reads it natively — no password handling in Python) |
| `cc_pg_tunnel(ssh_host="calcofi", local_port=5432)` | `cc_pg_tunnel()` | `subprocess.Popen(["ssh","-N","-o","ExitOnForwardFailure=yes","-L",...])` + port-wait; registry + `cc_pg_tunnel_close()` |
| `cc_pg_attach(con, alias="pg", read_only=True)` | `cc_pg_attach()` | `INSTALL postgres; ATTACH ...` on a DuckDB connection |
| `cc_query(sql, version="latest")` | `cc_query()` | one-shot against the release |

Packaging: `pyproject.toml` (hatchling), deps `duckdb`, `psycopg[binary]`; optional
`pandas` extra. `pytest` suite mirroring `test-postgres.R` (pgpass parsing, host defaults,
port probe; live tests gated on `CALCOFI_PG_TEST`). CI: GH Action running pytest on
3.10–3.13. Docs: README quickstart + a page in `docs/` (extend `server-access.qmd` and
`data-access.qmd` Python sections to import it).

## Design decisions inherited (do not re-litigate)

- Secrets only in `~/.pgpass` / `%APPDATA%\postgresql\pgpass.conf`; never a password kwarg
  in examples.
- Release access is credential-free HTTPS Parquet; `catalog.json` is the table registry
  (respect `"partitioned": true` and the supplemental flag exactly as `cc_get_db()` does —
  read `calcofi4r/R/database.R` first and keep the two implementations in step).
- On-server detection: `/share/github/CalCOFI` + Linux, `CALCOFI_ON_SERVER` override.

## Steps

1. Ben: `gh repo create CalCOFI/calcofi4py --public` (plus PyPI name check; publishing to
   PyPI can wait — `pip install git+https://github.com/CalCOFI/calcofi4py` first).
2. Scaffold package + tests + CI (~half a day, most of it porting the catalog logic).
3. Wire into docs; announce to the team alongside the server-access page.
4. Later: mirror `cc_read_*` conveniences only when someone asks for them.
