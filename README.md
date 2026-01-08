# workflows

scripts to explore and load data into the CalCOFI database

## notebooks

See rendered notebooks at <https://calcofi.github.io/workflows/>.

## TODO

### strategy: csv to parquet to duckdb

PROMPT: Help me develop a comprehensive strategy of reproducibly producing a duckdb database from parquet files in a Google Cloud Storage bucket that draws from the @workflows (especially @scrape_ctd.qmd and @ingest_swfsc.noaa.gov_calcofi-db.qmd) without repeating like in @create_db.qmd with strategy in @db.qmd and principles like using rclone and Google Drive sourcing from [Versioned Data Lake Strategy - Google Docs](https://docs.google.com/document/d/1O7CeNEyPBfQgo77zR-0QI1WHS2lzyb7Z3yGbLv9RP5Q/edit?tab=t.0).
