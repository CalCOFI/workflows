#!/bin/bash
# sync_jrw_ctd_to_gcs.sh
# mirrors Jim Wilkinson's per-cruise FINAL CTD archive from Google Drive into the
# same GCS prefix ingest_calcofi_ctd-cast.qmd already primes from.
#
# usage: ./sync_jrw_ctd_to_gcs.sh [--dry-run]
#
# WHY THIS EXISTS
#   calcofi.org publishes 1 m-binned *Final* zips for 1998 and 2003 onward only, so
#   the released CTD jumps 1998 -> 2003. JRW's Drive folder covers 1993-08 through
#   2019 continuously and closes that hole: 45 final cruises calcofi.org has no
#   final for (all of 1993-2002, plus 7 more 1998 cruises).
#
#   The two sources are the SAME product, not variants. Verified 2026-08-06:
#   20-0302JD_CTDBTL_001-100D.csv extracted from 20-0302JD_CTDFinalDB.zip is
#   md5-identical (0f596ecf76099fb7d784408b908cea0b, 17,710,137 bytes) to
#   calcofi.org's copy inside 20-0302JD_CTDFinalQC.zip, and the 1993 CSVs carry the
#   same 82 columns as 2026's. The notebook re-asserts this on every run
#   (`jrw_overlap_guard` chunk) rather than trusting a one-off check.
#
# WHY ONLY *_CTDFinalDB.zip
#   Each cruise ships two archives. _CTDFinalDB.zip is the lean one: the
#   *_CTDBTL_*.csv files the ingest actually reads, plus processing notes — 111
#   cruises, 0.89 GB total. _CTDFinalQC.zip is the same CSVs buried under asc/hdr
#   scans, per-cast plot CSVs and metadata — 4.83 GB the ingest never opens. Syncing
#   it would cost 5x the storage for zero additional rows.
#
# WHY THE SAME PREFIX AS calcofi.org's ZIPS
#   There is no filename collision: calcofi.org publishes _CTDFinalQC.zip, never
#   _CTDFinalDB.zip. Landing them together means prime_zips_from_gcs() picks them up
#   with no extra plumbing, and the notebook's inventory treats "on GCS" and
#   "on calcofi.org" as one union.
#
#   This syncs ALL 111 cruises, not just the 45 gap ones — the archive has value
#   beyond the gap and it is what a future backfill of calcofi.org would draw on.
#   The notebook decides which to *read*: it drops a GCS final whose cruise already
#   has a calcofi.org final, so the ~1 hr heavy path does not re-parse 66 cruises of
#   byte-identical CSV. Archive completely; read selectively.
#
# prerequisites
#   - rclone configured with a Drive remote that can see the folder (default
#     gdrive-ecoquants) and the GCS remote (default gcs-calcofi)
#
# overridable via environment:
#   GDRIVE_REMOTE  rclone Drive remote  (default gdrive-ecoquants)
#   GCS_REMOTE     rclone GCS remote    (default gcs-calcofi)
#   JRW_FOLDER_ID  Drive folder id      (default is JRW's shared folder)

set -euo pipefail

# ─── configuration ────────────────────────────────────────────────────────────

GDRIVE_REMOTE="${GDRIVE_REMOTE:-gdrive-ecoquants}"
GCS_REMOTE="${GCS_REMOTE:-gcs-calcofi}"

# https://drive.google.com/drive/folders/11Xkcax4zvdfjxKLf3gULsBWLGcsMH6sk
# "CTD data processed by James Wilkinson, SIO-CalCOFI Technical Group"
JRW_FOLDER_ID="${JRW_FOLDER_ID:-11Xkcax4zvdfjxKLf3gULsBWLGcsMH6sk}"

DEST="${GCS_REMOTE}:calcofi-files-public/_sync/calcofi/ctd-cast/download"

LOG_DIR="${HOME}/.calcofi/logs"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
LOG_FILE="${LOG_DIR}/sync_jrw_ctd_${TIMESTAMP}.log"

DRY_RUN=""
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN="--dry-run"
    echo "DRY RUN MODE: No changes will be made"
fi

mkdir -p "${LOG_DIR}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

# ─── preflight ────────────────────────────────────────────────────────────────

if ! command -v rclone &> /dev/null; then
    log "ERROR: rclone not found on PATH"
    exit 1
fi

for remote in "${GDRIVE_REMOTE}" "${GCS_REMOTE}"; do
    if ! rclone listremotes | grep -q "^${remote}:$"; then
        log "ERROR: rclone remote '${remote}' not configured"
        log "       run: rclone config"
        exit 1
    fi
done

log "Source: ${GDRIVE_REMOTE}: (folder ${JRW_FOLDER_ID})"
log "Dest:   ${DEST}"

# ─── sync ─────────────────────────────────────────────────────────────────────

# copy, not sync: the destination also holds calcofi.org's zips and the CTDPrelim
# drops. `rclone sync` would delete every one of them.
#
# --max-depth 1 keeps us out of the nested Databases/ subfolder (the 1993-2019
# single-table Access DBs and merged decadal CSVs), which is a different product —
# same data, pre-merged for Access/SQL Server rather than per cruise.
log "Copying *_CTDFinalDB.zip (111 cruises, ~0.89 GB) ..."
rclone copy "${GDRIVE_REMOTE}:" "${DEST}" \
    --drive-root-folder-id "${JRW_FOLDER_ID}" \
    --include "*_CTDFinalDB.zip" \
    --max-depth 1 \
    --transfers 8 --checkers 16 \
    --progress --stats-one-line \
    ${DRY_RUN} 2>&1 | tee -a "${LOG_FILE}"

# provenance: JRW's own description of what the archive contains, dated 07/11/2024
log "Copying DatabaseFilesReadMe.txt (provenance) ..."
rclone copy "${GDRIVE_REMOTE}:" "${DEST}" \
    --drive-root-folder-id "${JRW_FOLDER_ID}" \
    --include "DatabaseFilesReadMe.txt" \
    --max-depth 1 \
    ${DRY_RUN} 2>&1 | tee -a "${LOG_FILE}"

# ─── verify ───────────────────────────────────────────────────────────────────

n_dest=$(rclone lsf "${DEST}" --include "*_CTDFinalDB.zip" --max-depth 1 | wc -l | tr -d ' ')
log "Done. ${n_dest} *_CTDFinalDB.zip now at ${DEST}"
log "Log: ${LOG_FILE}"
