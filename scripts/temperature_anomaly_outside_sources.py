#!/usr/bin/env python3
"""Outside sources for 2026-11_temperature-anomaly.qmd: measurements that never passed through the CalCOFI pipeline,
for the days and places of the November 2026 CTD casts.

  1. Buoys: NDBC / CDIP buoys and the NOS La Jolla tide station. NDBC's realtime2 files hold the last 45 days only,
     which is why this runs once and its small tables are kept in the repo.
       buoy_stations.csv   every station used: id, name, position, the URL read
       buoys_at_casts.csv  the water temperature reported nearest in time to each cast, for stations within MAX_KM
       buoy_series.csv     hourly mean water temperature of those stations over the whole file (about 45 days)
  2. Satellite analyses at each cast's position on the cast's day, from NOAA CoastWatch West Coast ERDDAP:
     NOAA OISST v2.1 near real time (0.25 degree; `sst` and its `anom` against 1971-2000) and
     JPL MUR v4.1 (0.01 degree; `analysed_sst`, and `sstAnom` against the 2003-2014 MUR climatology).
       satellite_at_casts.csv
  3. Argo float profiles in and around the cruise's box and dates, from the Ifremer ERDDAP.
       argo_profiles.csv
  4. The SCCOOS automated shore station on Scripps Pier (temperature and salinity at the coast, 2013 to now), as daily
     means of the values that pass the station's own quality tests, from the IOOS sensors ERDDAP (Axiom).
       pier_daily.csv
  5. sources.csv: every URL requested, and when.

usage: temperature_anomaly_outside_sources.py <casts.csv> <cache_dir> <out_dir>
  casts.csv is written by the notebook from the release (site_key, cast_id, time_utc, lat, lon, ctd_t_top3m).
  Responses are cached in cache_dir, so a second run repeats no request that already succeeded; ERDDAP answers 503
  under load, and a value it could not serve is left empty and filled by the next run. OUTSIDE_OFFLINE=1 rebuilds the
  tables from the cache alone.
Only cast positions and times go out, to public data services; nothing identifies who asks.
"""
import csv, hashlib, math, os, sys, time, urllib.request
from collections import defaultdict
from datetime import datetime, timezone, timedelta

UA      = {"User-Agent": "Mozilla/5.0 (data-check script)"}
MAX_KM  = 15.0     # a buoy is compared with a cast when it is this close
MAX_MIN = 45       # and reported within this many minutes of it
BUOYS   = ["46225", "46254", "46258", "46232", "46086", "46224", "46222", "46025", "46047", "46219", "46069", "46053",
           "46221", "46251", "46253", "46256", "LJAC1"]
SERIES  = ["46225", "46254", "LJAC1", "46258", "46232", "46086", "46221", "46219", "46047"]   # kept as hourly series
NDBC    = "https://www.ndbc.noaa.gov"
ERDDAP  = "https://coastwatch.pfeg.noaa.gov/erddap/griddap/"
ARGO    = "https://erddap.ifremer.fr/erddap/tabledap/ArgoFloats.csv"
PIER    = "https://erddap.sensors.axds.co/erddap/tabledap/scripps-pier-automated-shore-sta-1.csv"
SOURCES = []

def fetch(url, cache_dir, name=None, tries=3, wait=4):
  """the body of a URL, from the cache when a previous run already has it; None when the server will not serve it"""
  f = os.path.join(cache_dir, name or hashlib.sha1(url.encode()).hexdigest()[:16] + ".txt")
  if os.path.exists(f) and os.path.getsize(f) > 0:
    SOURCES.append((url, datetime.fromtimestamp(os.path.getmtime(f), timezone.utc).strftime("%Y-%m-%dT%H:%MZ"), "ok"))
    return open(f, encoding="utf-8", errors="replace").read()
  if os.environ.get("OUTSIDE_OFFLINE"):                        # build the tables from the cache alone, asking no server
    return None
  err = None
  for i in range(tries):
    try:
      with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=45) as r:
        body = r.read()
      open(f, "wb").write(body)
      SOURCES.append((url, datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%MZ"), "ok"))
      return body.decode("utf-8", "replace")
    except Exception as e:
      err = e; time.sleep(wait * (i + 1))
  print(f"  not served: {url} ({err})", file=sys.stderr, flush=True)
  SOURCES.append((url, datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%MZ"), f"failed: {err}"))
  return None

def km(lat1, lon1, lat2, lon2):
  p1, p2 = math.radians(lat1), math.radians(lat2)
  a = math.sin((p2 - p1) / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(math.radians(lon2 - lon1) / 2) ** 2
  return 6371.0 * 2 * math.asin(math.sqrt(a))

def write(path, rows, fields=None):
  with open(path, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=fields or list(rows[0].keys())); w.writeheader(); w.writerows(rows)
  print(f"wrote {path} ({len(rows)} rows)", flush=True)

def main():
  casts_csv, cache, out = sys.argv[1:4]
  os.makedirs(cache, exist_ok=True); os.makedirs(out, exist_ok=True)
  casts = list(csv.DictReader(open(casts_csv)))
  for c in casts:
    c["t"] = datetime.strptime(c["time_utc"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    c["lat"], c["lon"] = float(c["lat"]), float(c["lon"])

  # ---- 1. buoys ----
  tbl = fetch(f"{NDBC}/data/stations/station_table.txt", cache, "station_table.txt")
  pos = {}
  for ln in tbl.splitlines():
    p = ln.split("|")
    if len(p) > 6 and p[0].upper() in BUOYS:
      w = p[6].split()                                         # "32.933 N 117.391 W (...)"
      pos[p[0].upper()] = dict(name=p[4].split(" - ")[0].strip(), lat=float(w[0]) * (1 if w[1] == "N" else -1),
                               lon=float(w[2]) * (-1 if w[3] == "W" else 1))
  stations, pairs, series = [], [], []
  for b in BUOYS:
    url = f"{NDBC}/data/realtime2/{b}.txt"
    txt = fetch(url, cache, f"ndbc_{b}.txt")
    if not txt or b not in pos: continue
    obs = []
    for ln in txt.splitlines():
      p = ln.split()
      if ln.startswith("#") or len(p) < 15 or p[14] == "MM": continue          # column 15 is WTMP, degC
      obs.append((datetime(*map(int, p[:5]), tzinfo=timezone.utc), float(p[14])))
    if not obs: continue
    near = min(km(c["lat"], c["lon"], pos[b]["lat"], pos[b]["lon"]) for c in casts)
    stations.append(dict(buoy=b, name=pos[b]["name"], lat=pos[b]["lat"], lon=pos[b]["lon"], km_to_nearest_cast=round(near, 1),
                         first_utc=min(o[0] for o in obs).strftime("%Y-%m-%dT%H:%MZ"), last_utc=max(o[0] for o in obs).strftime("%Y-%m-%dT%H:%MZ"),
                         n_obs=len(obs), url=url, page=f"{NDBC}/station_page.php?station={b.lower()}"))
    for c in casts:
      d = km(c["lat"], c["lon"], pos[b]["lat"], pos[b]["lon"])
      if d > MAX_KM: continue
      t, v = min(obs, key=lambda o: abs(o[0] - c["t"]))
      if abs(t - c["t"]) > timedelta(minutes=MAX_MIN): continue
      day = [x for tt, x in obs if abs(tt - c["t"]) <= timedelta(hours=12)]
      pairs.append(dict(site_key=c["site_key"], cast_time_utc=c["time_utc"], ctd_t_top3m=c["ctd_t_top3m"], buoy=b, buoy_name=pos[b]["name"],
                        km_apart=round(d, 1), buoy_time_utc=t.strftime("%Y-%m-%dT%H:%MZ"), buoy_wtmp=v,
                        buoy_minus_ctd=round(v - float(c["ctd_t_top3m"]), 2), buoy_24h_min=min(day), buoy_24h_max=max(day)))
    if b in SERIES:
      hours = defaultdict(list)
      for t, v in obs: hours[t.strftime("%Y-%m-%dT%H:00Z")].append(v)
      series += [dict(buoy=b, hour_utc=h, wtmp=round(sum(v) / len(v), 2), n=len(v)) for h, v in sorted(hours.items())]
  pairs.sort(key=lambda r: (r["cast_time_utc"], r["km_apart"]))
  write(os.path.join(out, "buoy_stations.csv"), stations)
  write(os.path.join(out, "buoys_at_casts.csv"), pairs)
  write(os.path.join(out, "buoy_series.csv"), series)

  # ---- 3. Argo (before the satellites: it is one quick request) ----
  t0 = (min(c["t"] for c in casts) - timedelta(days=16)).strftime("%Y-%m-%dT00:00:00Z")
  t1 = (max(c["t"] for c in casts) + timedelta(days=6)).strftime("%Y-%m-%dT00:00:00Z")
  box = (min(c["lat"] for c in casts) - 0.7, max(c["lat"] for c in casts) + 0.8, min(c["lon"] for c in casts) - 0.6, max(c["lon"] for c in casts) + 0.4)
  url = (f"{ARGO}?platform_number,cycle_number,time,latitude,longitude,pres,temp,psal,temp_qc&time%3E={t0}&time%3C={t1}"
         f"&latitude%3E={box[0]:.2f}&latitude%3C={box[1]:.2f}&longitude%3E={box[2]:.2f}&longitude%3C={box[3]:.2f}&pres%3C=160")
  txt = fetch(url, cache, "argo.csv")
  if txt:
    rows = list(csv.reader(txt.strip().splitlines()))
    write(os.path.join(out, "argo_profiles.csv"), [dict(zip(rows[0], r)) for r in rows[2:]], rows[0])

  # ---- 4. Scripps Pier: daily means of temperature and of salinity, each where its own QC aggregate is 1 (pass) ----
  day = {}
  for var, key in (("sea_water_temperature_ctd", "temp"), ("sea_water_practical_salinity_ctd", "sal")):
    txt = fetch(f"{PIER}?time,{var}&{var}_qc_agg=1&orderByMean(%22time/1day%22)", cache, f"pier_{key}_daily.csv")
    for ln in (txt or "").strip().splitlines()[2:]:
      t, v = ln.split(",")[:2]
      if v not in ("NaN", ""): day.setdefault(t[:10], {})[key] = round(float(v), 3)
  if day:
    write(os.path.join(out, "pier_daily.csv"), [dict(date=d, temp=v.get("temp", ""), sal=v.get("sal", "")) for d, v in sorted(day.items())])

  # ---- 2. satellite analyses ----
  # OISST: one gridded request per day over the cruise's box. MUR: one point request per cast and variable.
  lat0, lat1 = min(c["lat"] for c in casts) - 0.3, max(c["lat"] for c in casts) + 0.3
  lon0, lon1 = min(c["lon"] for c in casts) - 0.3, max(c["lon"] for c in casts) + 0.3
  def oisst(var, day):
    q = f"{var}%5B({day}T12:00:00Z)%5D%5B(0.0)%5D%5B({lat0:.2f}):1:({lat1:.2f})%5D%5B({lon0:.2f}):1:({lon1:.2f})%5D"
    txt = fetch(f"{ERDDAP}ncdcOisst21NrtAgg_LonPM180.csv?{q}", cache, f"oisst_{var}_{day}.csv")
    pts = []
    for ln in (txt or "").strip().splitlines()[2:]:
      p = ln.split(",")
      if p[-1] not in ("NaN", ""): pts.append((float(p[-3]), float(p[-2]), float(p[-1])))
    return pts
  def nearest(pts, c, max_km=25):
    if not pts: return None
    la, lo, v = min(pts, key=lambda q: km(c["lat"], c["lon"], q[0], q[1]))
    return round(v, 2) if km(c["lat"], c["lon"], la, lo) <= max_km else None
  def mur(ds, var, c):
    day = c["t"].strftime("%Y-%m-%d")
    q = f"{var}%5B({day}T09:00:00Z)%5D%5B({c['lat']:.3f})%5D%5B({c['lon']:.3f})%5D"
    txt = fetch(f"{ERDDAP}{ds}.csv?{q}", cache, f"mur_{var}_{day}_{c['site_key'].replace(' ', '_')}.csv", tries=2)
    try: return round(float(txt.strip().splitlines()[2].split(",")[-1]), 2)
    except Exception: return None
  grids = {day: (oisst("sst", day), oisst("anom", day)) for day in sorted({c["t"].strftime("%Y-%m-%d") for c in casts})}
  sat = []
  for c in casts:
    g = grids[c["t"].strftime("%Y-%m-%d")]
    sat.append(dict(site_key=c["site_key"], cast_time_utc=c["time_utc"], lat=c["lat"], lon=c["lon"], ctd_t_top3m=c["ctd_t_top3m"],
                    oisst_sst=nearest(g[0], c), oisst_anom=nearest(g[1], c),
                    mur_sst=mur("jplMURSST41", "analysed_sst", c), mur_anom=mur("jplMURSST41anom1day", "sstAnom", c)))
    print("  ", sat[-1]["site_key"], sat[-1]["ctd_t_top3m"], sat[-1]["oisst_sst"], sat[-1]["oisst_anom"], sat[-1]["mur_sst"], sat[-1]["mur_anom"], flush=True)
  write(os.path.join(out, "satellite_at_casts.csv"), sat)
  for k in ("oisst_sst", "oisst_anom", "mur_sst", "mur_anom"):
    print(f"  {k}: {sum(r[k] is not None for r in sat)} of {len(sat)} casts", flush=True)

  write(os.path.join(out, "sources.csv"), [dict(url=u, accessed_utc=t, status=s) for u, t, s in SOURCES])

if __name__ == "__main__":
  main()
