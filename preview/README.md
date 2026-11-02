# calcofi-preview

A sign-in-only view of a dataset before its provider has confirmed it may be published. The
provider's PI signs in with their Google identity, sees the dataset as CalCOFI.io would publish
it, and records "yes, publish it as shown" or "not yet" in place. Everything runs in the
`ucsd-sio-calcofi` Google Cloud project, on its existing billing.

```
reviewer ──► Cloud Run service calcofi-preview  (IAP in front: Google sign-in, no anonymous request reaches it)
                │  verifies IAP's signed header → email
                │  access.csv: which datasets that email may see (the data team sees all)
                ▼
             gs://calcofi-preview  (private: uniform access, public access prevention, versioned)
                datasets/{key}/current.txt, datasets/{key}/{build}/build.json + pages + files
                access.csv                       ← who may see which dataset (versioned here, not in git)
                consent/{key}/{utc}_{email}.json ← one object per decision, create-only
```

- **Two gates.** IAP decides who may sign in at all (every reviewer and the team are granted
  `roles/iap.httpsResourceAccessor` on the service). The app decides which dataset each person
  sees, from `access.csv`; a dataset not granted answers the same 404 as one that does not exist.
- **The trail.** A decision records the verified email, the time, the build shown (its id and
  the SHA-256 of its `build.json`) and the consent question's id and text. The service account
  holds `storage.objectCreator`, which can create but never overwrite or delete, and the app
  writes with `if_generation_match=0`. IAP's own audit logs record each sign-in.
- **Into git.** A pull script folds each decision into the dataset's consent question in
  `questions.csv` (answer, who, answered_date), the same record a verbal or emailed yes lands in.

## Run the tests

```sh
uv venv .venv --python 3.13 && uv pip install -p .venv -r requirements-dev.txt
.venv/bin/python -m pytest -q
```

Locally without IAP: `PREVIEW_DEV_EMAIL=you@ucsd.edu` stands in for the signed header against a
local directory store; the app refuses that variable on Cloud Run (`K_SERVICE` is set there).

## One-time setup

Done 2026-10-23 as `bebest@ucsd.edu` (project editor), except the two steps marked *owner*. The
service is <https://calcofi-preview-199066946721.us-west1.run.app> (`us-west1`, the closest region
to SIO that the organization's location policy allows). An editor can enable the APIs, create the
bucket, the service account and the OAuth client, set the bucket's IAM, and deploy; only an owner
(Erin Satterthwaite, Marina Frants) can set the service's or IAP's IAM.

```sh
P=ucsd-sio-calcofi; N=199066946721; R=us-west1; SA=calcofi-preview@$P.iam.gserviceaccount.com
gcloud services enable run.googleapis.com iap.googleapis.com cloudbuild.googleapis.com \
  artifactregistry.googleapis.com --project $P

gcloud storage buckets create gs://calcofi-preview --project $P --location $R \
  --uniform-bucket-level-access --public-access-prevention
gcloud storage buckets update gs://calcofi-preview --versioning

gcloud iam service-accounts create calcofi-preview --project $P --display-name "calcofi-preview (Cloud Run)"
gcloud storage buckets add-iam-policy-binding gs://calcofi-preview --member serviceAccount:$SA --role roles/storage.objectViewer
gcloud storage buckets add-iam-policy-binding gs://calcofi-preview --member serviceAccount:$SA --role roles/storage.objectCreator
gcloud storage buckets add-iam-policy-binding gs://calcofi-preview \
  --member serviceAccount:calcofi-admin@$P.iam.gserviceaccount.com --role roles/storage.objectAdmin
gcloud storage buckets add-iam-policy-binding gs://calcofi-preview --member user:bebest@ucsd.edu --role roles/storage.admin
# a new bucket gives every project editor and viewer its objects (legacy convenience bindings); the
# project's editors include a provider's accounts, so only the principals named above keep access
for b in "projectEditor:$P roles/storage.legacyBucketOwner" "projectEditor:$P roles/storage.legacyObjectOwner" \
         "projectViewer:$P roles/storage.legacyBucketReader" "projectViewer:$P roles/storage.legacyObjectReader"; do
  set -- $b; gcloud storage buckets remove-iam-policy-binding gs://calcofi-preview --member $1 --role $2
done

gcloud run deploy calcofi-preview --source . --project $P --region $R --service-account $SA \
  --no-allow-unauthenticated --iap --min-instances 0 --max-instances 2 \
  --set-env-vars "^;^PREVIEW_BUCKET=calcofi-preview;PREVIEW_IAP_AUDIENCE=/projects/$N/locations/$R/services/calcofi-preview;PREVIEW_TEAM=bebest@ucsd.edu,esatterthwaite@ucsd.edu,bthuang@ucsd.edu"
# owner: IAP's service agent must be allowed to invoke the service (the deploy tries and, as an editor, fails)
gcloud run services add-iam-policy-binding calcofi-preview --project $P --region $R \
  --member serviceAccount:service-$N@gcp-sa-iap.iam.gserviceaccount.com --role roles/run.invoker
# owner: let the data team grant reviewers sign-in from then on
gcloud projects add-iam-policy-binding $P --member user:bebest@ucsd.edu --role roles/iap.admin
```

Then, once, in the console: Cloud Run → `calcofi-preview` → Security → IAP → **Configure in
IAP**, set the OAuth consent screen's audience to **External** and let it create the custom
OAuth client. Google's managed client admits only accounts inside the project's organization;
reviewers at NOAA, CDFW or the Farallon Institute need the custom one. Only the basic sign-in
scopes are requested, so no Google verification is needed.

A reviewer without a Google account creates one for their existing work address at
accounts.google.com/signup ("use my current email address instead"); no Gmail is involved.

## Granting a reviewer

The access list lives only in the bucket: this repository is public, and a list of reviewers'
addresses beside unreleased dataset keys does not belong in it. Object versioning keeps every
earlier list, so who was granted what, and when, stays on record. Add a row
(`dataset_key,email,status,granted,granted_by,note`), then grant sign-in:

```sh
gcloud storage cp gs://calcofi-preview/access.csv access.csv   # edit, then
gcloud storage cp access.csv gs://calcofi-preview/access.csv
gcloud iap web add-iam-policy-binding --project $P --resource-type cloud-run --service calcofi-preview \
  --region $R --member user:pi@example.org --role roles/iap.httpsResourceAccessor
```

Revoking is `status = revoked` in the same row (the app stops showing the dataset at once) and
`gcloud iap web remove-iam-policy-binding` for the sign-in.
