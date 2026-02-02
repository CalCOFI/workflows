#!/bin/bash
# sync_gdrive_to_gcs.sh
# syncs calcofi data from google drive to google cloud storage with versioning
#
# usage: ./sync_gdrive_to_gcs.sh [public|private] [--dry-run]
#
# arguments:
#   public   - sync to calcofi-files-public bucket (default)
#   private  - sync to calcofi-files-private bucket
#   --dry-run - show what would be done without making changes
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

GDRIVE_REMOTE="gdrive-ecoquants"
GCS_REMOTE="gcs-calcofi"

TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
LOG_DIR="${HOME}/.calcofi/logs"
DRY_RUN=""
BUCKET_TYPE="public"

# ─── parse arguments ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case $1 in
        public)
            BUCKET_TYPE="public"
            shift
            ;;
        private)
            BUCKET_TYPE="private"
            shift
            ;;
        --dry-run)
            DRY_RUN="--dry-run"
            echo "DRY RUN MODE: No changes will be made"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [public|private] [--dry-run]"
            exit 1
            ;;
    esac
done

# ─── set paths based on bucket type ──────────────────────────────────────────

if [ "$BUCKET_TYPE" = "public" ]; then
    GDRIVE_PATH="projects/calcofi/data-public"
    GCS_BUCKET="calcofi-files-public"
elif [ "$BUCKET_TYPE" = "private" ]; then
    GDRIVE_PATH="projects/calcofi/data-private"
    GCS_BUCKET="calcofi-files-private"
fi

# rclone uses remote:path format, not gs:// URIs
GCS_SYNC="${GCS_REMOTE}:${GCS_BUCKET}/_sync"
GCS_ARCHIVE="${GCS_REMOTE}:${GCS_BUCKET}/archive/${TIMESTAMP}"
GCS_MANIFESTS="${GCS_REMOTE}:${GCS_BUCKET}/manifests"

LOG_FILE="${LOG_DIR}/sync_${BUCKET_TYPE}_${TIMESTAMP}.log"

# ─── setup ────────────────────────────────────────────────────────────────────

mkdir -p "${LOG_DIR}"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "${LOG_FILE}"
}

log "═══════════════════════════════════════════════════════════════════════════"
log "CalCOFI Data Sync: Google Drive → Google Cloud Storage"
log "═══════════════════════════════════════════════════════════════════════════"
log "Bucket type: ${BUCKET_TYPE}"
log "Timestamp: ${TIMESTAMP}"
log "Source: ${GDRIVE_REMOTE}:${GDRIVE_PATH}"
log "Destination: ${GCS_SYNC}"
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

if ! rclone listremotes | grep -q "^${GCS_REMOTE}:$"; then
    log "ERROR: rclone remote '${GCS_REMOTE}' not configured"
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

rclone sync "${GDRIVE_REMOTE}:${GDRIVE_PATH}" "${GCS_SYNC}" \
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

# ─── create archive snapshot ─────────────────────────────────────────────────

log "Creating archive snapshot at ${GCS_ARCHIVE}..."

if [ -z "${DRY_RUN}" ]; then
    rclone copy "${GCS_SYNC}" "${GCS_ARCHIVE}" \
        --checksum \
        --log-file "${LOG_FILE}" \
        --log-level INFO
    log "Archive snapshot created"
else
    log "DRY RUN: Would create archive snapshot at ${GCS_ARCHIVE}"
fi

# ─── generate manifest ────────────────────────────────────────────────────────

log "Generating manifest..."

MANIFEST_FILE="/tmp/manifest_${TIMESTAMP}.json"
MANIFEST_LATEST="/tmp/manifest_latest.json"

# generate json listing of synced files
rclone lsjson "${GCS_SYNC}" --recursive > "${MANIFEST_FILE}"

# add metadata wrapper with archive path for immutable references
cat > "${MANIFEST_LATEST}" <<EOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "sync_timestamp": "${TIMESTAMP}",
  "bucket": "${GCS_BUCKET}",
  "archive_path": "archive/${TIMESTAMP}",
  "files": $(cat "${MANIFEST_FILE}")
}
EOF

# upload manifests (using rclone for consistency)
if [ -z "${DRY_RUN}" ]; then
    rclone copyto "${MANIFEST_LATEST}" "${GCS_MANIFESTS}/manifest_${TIMESTAMP}.json"
    rclone copyto "${MANIFEST_LATEST}" "${GCS_MANIFESTS}/manifest_latest.json"
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

# count files in _sync
SYNC_COUNT=$(rclone lsjson "${GCS_SYNC}" --recursive 2>/dev/null | jq length || echo "0")
log "Files in _sync/: ${SYNC_COUNT}"
log "Files archived: ${ARCHIVE_COUNT}"
log "═══════════════════════════════════════════════════════════════════════════"

exit 0
