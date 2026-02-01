#!/bin/bash
# sync_gdrive_to_gcs.sh
# syncs calcofi data from google drive to google cloud storage with versioning
#
# usage: ./sync_gdrive_to_gcs.sh [--dry-run]
#
# prerequisites:
#   - rclone installed and configured with 'gdrive' and 'gcs' remotes
#   - gcloud cli authenticated with calcofi project
#
# rclone configuration example:
#   rclone config
#   # for gdrive: type=drive, scope=drive.readonly
#   # for gcs: type=google cloud storage, project_number=ucsd-sio-calcofi

set -euo pipefail

# ─── configuration ────────────────────────────────────────────────────────────

# GDRIVE_REMOTE="gdrive"
# GDRIVE_PATH="calcofi/data"
GDRIVE_REMOTE="gdrive-ecoquants"
GDRIVE_PATH="projects/calcofi/data"

GCS_BUCKET="calcofi-files"
GCS_CURRENT="gs://${GCS_BUCKET}/current"

TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
GCS_ARCHIVE="gs://${GCS_BUCKET}/archive/${TIMESTAMP}"
GCS_MANIFESTS="gs://${GCS_BUCKET}/manifests"

LOG_DIR="${HOME}/.calcofi/logs"
LOG_FILE="${LOG_DIR}/sync_${TIMESTAMP}.log"

DRY_RUN=""

# ─── parse arguments ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN="--dry-run"
            echo "DRY RUN MODE: No changes will be made"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ─── setup ────────────────────────────────────────────────────────────────────

mkdir -p "${LOG_DIR}"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "${LOG_FILE}"
}

log "═══════════════════════════════════════════════════════════════════════════"
log "CalCOFI Data Sync: Google Drive → Google Cloud Storage"
log "═══════════════════════════════════════════════════════════════════════════"
log "Timestamp: ${TIMESTAMP}"
log "Source: ${GDRIVE_REMOTE}:${GDRIVE_PATH}"
log "Destination: ${GCS_CURRENT}"
log "Archive: ${GCS_ARCHIVE}"

# ─── check prerequisites ──────────────────────────────────────────────────────

if ! command -v rclone &> /dev/null; then
    log "ERROR: rclone is not installed"
    log "Install with: brew install rclone"
    exit 1
fi

if ! command -v gcloud &> /dev/null; then
    log "ERROR: gcloud CLI is not installed"
    exit 1
fi

# verify rclone remotes exist
if ! rclone listremotes | grep -q "^${GDRIVE_REMOTE}:$"; then
    log "ERROR: rclone remote '${GDRIVE_REMOTE}' not configured"
    log "Run: rclone config"
    exit 1
fi

log "Prerequisites verified"

# ─── sync google drive to gcs ─────────────────────────────────────────────────

log "Starting sync..."

# rclone sync with --backup-dir for versioning
# - checksum: compare by hash, not just size/time
# - backup-dir: move changed/deleted files to archive before overwriting
# - drive-export-formats: export google docs as csv
# - exclude: skip system files and temp files

rclone sync "${GDRIVE_REMOTE}:${GDRIVE_PATH}" "${GCS_CURRENT}" \
    ${DRY_RUN} \
    --checksum \
    --backup-dir "${GCS_ARCHIVE}" \
    --drive-export-formats csv \
    --exclude ".DS_Store" \
    --exclude "*.tmp" \
    --exclude "~*" \
    --log-file "${LOG_FILE}" \
    --log-level INFO \
    --stats 30s \
    --stats-one-line

SYNC_EXIT=$?

if [ $SYNC_EXIT -ne 0 ]; then
    log "ERROR: rclone sync failed with exit code ${SYNC_EXIT}"
    exit $SYNC_EXIT
fi

log "Sync completed successfully"

# ─── generate manifest ────────────────────────────────────────────────────────

log "Generating manifest..."

MANIFEST_FILE="/tmp/manifest_${TIMESTAMP}.json"
MANIFEST_LATEST="/tmp/manifest_latest.json"

# generate json listing of current files
rclone lsjson "${GCS_CURRENT}" --recursive > "${MANIFEST_FILE}"

# add metadata wrapper
cat > "${MANIFEST_LATEST}" <<EOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "sync_timestamp": "${TIMESTAMP}",
  "bucket": "${GCS_BUCKET}",
  "files": $(cat "${MANIFEST_FILE}")
}
EOF

# upload manifests
if [ -z "${DRY_RUN}" ]; then
    gcloud storage cp "${MANIFEST_LATEST}" "${GCS_MANIFESTS}/manifest_${TIMESTAMP}.json"
    gcloud storage cp "${MANIFEST_LATEST}" "${GCS_MANIFESTS}/manifest_latest.json"
    log "Manifests uploaded to ${GCS_MANIFESTS}"
else
    log "DRY RUN: Would upload manifests to ${GCS_MANIFESTS}"
fi

# cleanup temp files
rm -f "${MANIFEST_FILE}" "${MANIFEST_LATEST}"

# ─── check for archive entries ────────────────────────────────────────────────

log "Checking archive for changed files..."

ARCHIVE_COUNT=$(rclone lsjson "${GCS_ARCHIVE}" --recursive 2>/dev/null | jq length || echo "0")

if [ "${ARCHIVE_COUNT}" -gt 0 ]; then
    log "Archived ${ARCHIVE_COUNT} file(s) that were updated or deleted"
    log "Archive location: ${GCS_ARCHIVE}"
else
    log "No files were changed (archive is empty)"
    # optionally remove empty archive folder
    if [ -z "${DRY_RUN}" ]; then
        rclone rmdir "${GCS_ARCHIVE}" 2>/dev/null || true
    fi
fi

# ─── summary ──────────────────────────────────────────────────────────────────

log "═══════════════════════════════════════════════════════════════════════════"
log "Sync Summary"
log "═══════════════════════════════════════════════════════════════════════════"
log "Log file: ${LOG_FILE}"

# count files in current
CURRENT_COUNT=$(rclone lsjson "${GCS_CURRENT}" --recursive 2>/dev/null | jq length || echo "0")
log "Files in current/: ${CURRENT_COUNT}"
log "Files archived: ${ARCHIVE_COUNT}"
log "═══════════════════════════════════════════════════════════════════════════"

exit 0
