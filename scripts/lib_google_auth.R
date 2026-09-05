# Google auth for the sheet-sync scripts — the calcofi-admin SERVICE ACCOUNT, never
# an individual's OAuth token (Ben, 2026-09-05: interactive gs4_auth() is brittle and
# needs a human at the keyboard; the same key already drives gcloud and rclone).
#
# source()d by scripts/sync_questions_sheets.R and scripts/sync_dataset_meta_sheets.R.
# The key is resolved, in order, from:
#   1. QS_GOOGLE_SA_JSON        (kept for the runs documented in .claude/calcofi_notes.md)
#   2. CALCOFI_GOOGLE_SA_JSON   (the name the server pipeline plan uses)
#   3. the key's home in the private Drive folder on a laptop that syncs it
#   4. /etc/rclone/calcofi-admin-sa.json (root-owned copy on the CalCOFI server)
# and nothing else: if no file exists, the script stops with the paths it looked at.
#
# A service account has NO My Drive storage, so the spreadsheets live in a folder on
# the org Shared Drive (see qs_ensure_folder() in sync_questions_sheets.R); every
# sheet the account writes must already be there or be created there.

CC_GOOGLE_SA_CANDIDATES <- c(
  Sys.getenv("QS_GOOGLE_SA_JSON", ""),
  Sys.getenv("CALCOFI_GOOGLE_SA_JSON", ""),
  file.path("~/Library/CloudStorage/GoogleDrive-ben@ecoquants.com/My Drive/private",
            "2026-06-07 ucsd-sio-calcofi_36230b2795e6_calcofi-admin-sa.json"),
  file.path("~/My Drive/private", "2026-06-07 ucsd-sio-calcofi_36230b2795e6_calcofi-admin-sa.json"),
  "/etc/rclone/calcofi-admin-sa.json")

CC_GOOGLE_SCOPES <- c("https://www.googleapis.com/auth/spreadsheets",
                      "https://www.googleapis.com/auth/drive")

#' Path to the service-account key, or an error naming every place it was looked for
cc_google_sa_key <- function(candidates = CC_GOOGLE_SA_CANDIDATES) {
  candidates <- path.expand(candidates[nzchar(candidates)])
  hit <- candidates[file.exists(candidates)]
  if (!length(hit))
    stop("no Google service-account key found. Looked at:\n  ",
         paste(candidates, collapse = "\n  "),
         "\n  Set QS_GOOGLE_SA_JSON (or CALCOFI_GOOGLE_SA_JSON) to the calcofi-admin key,",
         " or place it at one of the paths above. Interactive gs4_auth() is not used.", call. = FALSE)
  hit[1]
}

#' Authenticate googlesheets4 + googledrive as the service account, once per process.
#' Returns the account's e-mail (lower-case) so callers can skip sharing with it.
cc_google_auth <- function(scopes = CC_GOOGLE_SCOPES, quiet = FALSE) {
  key <- cc_google_sa_key()
  googlesheets4::gs4_auth(path = key, scopes = scopes)
  googledrive::drive_auth(token = googlesheets4::gs4_token())
  who <- tryCatch(googlesheets4::gs4_user(), error = function(e) NA_character_)
  if (length(who) != 1 || is.na(who))
    who <- tryCatch(jsonlite::fromJSON(key)$client_email, error = function(e) NA_character_)
  if (!quiet) cat("authenticated as service account ", if (is.na(who)) "<unknown>" else who,
                  " (", basename(key), ")\n", sep = "")
  tolower(who)
}
