# Step 0 of the sigma-theta flag-inheritance dry run (4_sigma_inherit_diff.R): write the SQL that copies
# the slices of release v2026.10.19 the diff reads into $CC_DIFF_DIR as local parquet. Run
#   python3 0_extract_release.py && duckdb -f $CC_DIFF_DIR/extract.sql
# Needs $CC_DIFF_DIR/catalog.json (gcloud storage cp gs://calcofi-db/ducklake/releases/v2026.10.19/catalog.json).
import json, os
S = os.environ["CC_DIFF_DIR"]
B = "https://storage.googleapis.com/calcofi-db/"
T = {t["name"]: t for t in json.load(open(S + "/catalog.json"))["tables"]}

def urls(name, pred=lambda p: True):
    return [B + o["path"] for o in T[name]["objects"] if pred(o["path"])]

def lst(u):
    return "[" + ",".join("'%s'" % x for x in u) + "]"

sql = ["INSTALL httpfs; LOAD httpfs;"]
sql.append(f"""COPY (SELECT cruise_key, sample_key, depth_min_m, measurement_type, measurement_value, measurement_qual
  FROM read_parquet({lst(urls('obs_ctd_full'))})
  WHERE measurement_type IN ('temperature_1','temperature_2','salinity_1','salinity_2','sigma_theta_1','sigma_theta_2'))
  TO '{S}/rel6.parquet' (FORMAT parquet);""")
# obs_env and climatology are partitioned by measurement_type: the column lives in the path, so hive_partitioning
env = urls("obs_env", lambda p: "measurement_type=sigma_theta_1/" in p or "measurement_type=sigma_theta_ave/" in p)
sql.append(f"COPY (SELECT * FROM read_parquet({lst(env)}, hive_partitioning=true)) TO '{S}/rel_obs_env_sigma.parquet' (FORMAT parquet);")
sql.append(f"COPY (SELECT * FROM read_parquet({lst(urls('sample'))})) TO '{S}/rel_sample.parquet' (FORMAT parquet);")
sql.append(f"COPY (SELECT * FROM read_parquet({lst(urls('sample_measurement'))}) WHERE measurement_type LIKE 'mld%') TO '{S}/rel_sm_mld.parquet' (FORMAT parquet);")
clim = urls("climatology", lambda p: any(k in p for k in ("sigma_theta_1/", "sigma_theta_ave/", "mld_sigma_theta_002/", "mld_sigma_theta_0125/")))
sql.append(f"COPY (SELECT * FROM read_parquet({lst(clim)}, hive_partitioning=true)) TO '{S}/rel_clim_sigma.parquet' (FORMAT parquet);")
open(S + "/extract.sql", "w").write("\n".join(sql))
