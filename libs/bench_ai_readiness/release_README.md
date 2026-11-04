# CalCOFI integrated database, release v2026.10.21

`release.duckdb` in this folder holds the integrated CalCOFI database (DOI 10.5281/zenodo.23566406)
as DuckDB views over its Parquet tables. Query it read-only with the DuckDB CLI, for example:

    duckdb -readonly release.duckdb -c "show tables"
    duckdb -readonly release.duckdb -c "describe obs_env"

Use `describe` on any table, and the metadata tables `dataset`, `measurement_type` and `lookup`,
to learn what the columns and codes mean.
