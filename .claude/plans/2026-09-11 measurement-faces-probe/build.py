# build the mockup's data: every number read from the probe files in this folder
import json, re, csv, collections

REL = json.load(open('measurements.json'))
M = {m['key']: m for m in REL['measurements']}
CHEBI = json.load(open('chebi.json'))
NVS = json.load(open('nvs_probe.json'))
WP = json.load(open('wp.json'))
CALC = json.load(open('chem_calc.json'))

def svg(name):
    s = open(f'svg/{name}.svg').read()
    vb = re.search(r"viewBox='([^']+)'", s).group(1)
    inner = s.split('<!-- END OF HEADER -->', 1)[1].rsplit('</svg>', 1)[0]
    inner = re.sub(r"<rect[^>]*fill:none[^>]*>\s*</rect>", '', inner)
    inner = re.sub(r"\s+", ' ', inner)
    # tight viewBox from every coordinate the paths draw, so a small ion fills its slot like a big molecule
    xs, ys = [], []
    for d in re.findall(r"d='([^']+)'", inner):
        nums = [float(n) for n in re.findall(r'-?\d+(?:\.\d+)?', d)]
        xs += nums[0::2]; ys += nums[1::2]
    pad = 6
    vb = f'{min(xs) - pad:.1f} {min(ys) - pad:.1f} {max(xs) - min(xs) + 2 * pad:.1f} {max(ys) - min(ys) + 2 * pad:.1f}'
    return {'viewBox': vb, 'inner': inner.strip(), 'bytes': len(inner)}

SV = {k: svg(k) for k in ['nitrate', 'ammonium', 'ammonia', 'dioxygen', 'chlorophyll_a', 'pheophytin_a',
                          'carbon_dioxide', 'hydrogencarbonate', 'carbonate', 'sulfate']}

# anomaly per depth band (per cruise mean, then per year, vs the release's 1993–2013 climatology; anom_bands.sql)
BANDS = ['0-10', '10-50', '50-100', '100-200', '200-500', '500-1000', '1000-2000', '2000+']
AB = collections.defaultdict(lambda: collections.defaultdict(list))
for r in csv.DictReader(open('anom_bands.csv')):
    AB[r['measurement_type']][r['band']].append([int(r['year']), float(r['anom']), int(r['n_cruises']), int(r['n_values'])])
BN = collections.defaultdict(dict)
for r in csv.DictReader(open('band_n.csv')):
    BN[r['measurement_type']][r['band']] = int(r['n_obs'])

def trend(v, y0, y1):
    pts = [(y, a) for y, a, nc, n in v if y0 <= y <= y1 and nc >= 2]
    n = len(pts); mx = sum(p[0] for p in pts) / n; my = sum(p[1] for p in pts) / n
    b = sum((x - mx) * (y - my) for x, y in pts) / sum((x - mx) ** 2 for x, y in pts)
    return {'per_decade': round(b * 10, 3), 'from': y0, 'to': y1, 'n_years': n, 'intercept': round(my - b * mx, 4)}

def extremes(v):
    ok = [x for x in v if x[2] >= 2]
    hi = max(ok, key=lambda x: x[1]); lo = min(ok, key=lambda x: x[1])
    return {'hi': hi[:2], 'lo': lo[:2]}

def anomaly(key, units):
    bands, deeper = [], []
    for bd in BANDS:
        v = AB[key].get(bd)
        n_obs = BN[key].get(bd, 0)
        if not n_obs: continue
        # the climatology stops at the 500 m bin: 500-1000 m matches only its first 10 m, deeper bands nothing
        if v and bd in ('0-10', '10-50', '50-100', '100-200', '200-500'):
            bands.append({'band': bd, 'series': v, 'trend': trend(v, 1984, 2021), 'ext': extremes(v),
                          'n_values': sum(x[3] for x in v), 'n_obs': n_obs})
        else:
            deeper.append({'band': bd, 'n_obs': n_obs})
    ok = [x[1] for b_ in bands for x in b_['series'] if x[2] >= 2]
    spark = max(bands, key=lambda b_: b_['n_values'])['band']
    return {'units': units, 'bands': bands, 'deeper': deeper, 'ymax': round(max(abs(min(ok)), abs(max(ok))), 3), 'spark_band': spark}

# NOAA CPC ONI: strong El Niño years (any 3-month ONI ≥ +1.5)
oni = [l.split() for l in open('oni.txt').read().splitlines()[1:] if l.strip()]
mx = collections.defaultdict(lambda: -9.0)
for s, y, tot, a in oni: mx[int(y)] = max(mx[int(y)], float(a))
ONI = {'strong_el_nino': [y for y in sorted(mx) if mx[y] >= 1.5], 'latest': oni[-1]}

def rec(key):
    m = M[key]
    return {'label': m['label'], 'units': m['units'], 'totals': m['totals'], 'bounds': m['bounds'], 'flags': m['flags'],
            'climatology': m['climatology'], 'related': m['related'],
            'series': [{k: s[k] for k in ['measurement_type', 'dataset_key', 'source_column', 'qual_column', 'n_values', 'n_roots',
                                          'n_cruises', 'year_min', 'year_max', 'depth_min_m', 'depth_max_m', 'observed',
                                          'depth_bands', 'flags', 'units']} for s in m['series']]}

def chem(k, role='the thing'):
    c = CHEBI[k]
    return {'key': k, 'chebi': c['chebi'], 'name': re.sub('<[^>]+>', '', c['name']), 'formula': c['formula'], 'charge': c['charge'],
            'mass': c['mass'], 'definition': c.get('definition'), 'role': role}

def p01(code):
    r = NVS[code]
    return {'code': code, 'url': f'http://vocab.nerc.ac.uk/collection/P01/current/{code}/', 'pref': r['pref'], 'def': r['def'],
            'links': {k: {'pref': v['pref'], 'sameAs': v['sameAs']} for k, v in (r.get('links') or {}).items()}}

BOTTLE = 'https://calcofi.org/sampling-info/methods/bottle-sampling-methods/'
CTDFAQ = 'https://calcofi.org/sampling-info/methods/ctd-faq-circa-2020/'
frag = lambda url, text: url + '#:~:text=' + text.replace(' ', '%20').replace('&', '%26').replace('-', '%2D')
GOOS = lambda doc: f'https://goosocean.org/document/{doc}'

cast = [
  { 'key': 'temperature', 'glyph': 'T', 'icon': 'cat-physical', 'category': 'Physical Oceanography', 'units_disp': '°C',
    'kind': 'scale', 'kind_note': 'a property, not a substance: its face is the scale it is read on',
    'p01': p01('TEMPPR01'), 'property': {'id': 'S06 S0600082', 'name': 'Temperature', 'sameAs': 'http://qudt.org/vocab/quantitykind/Temperature'},
    'eov': {'name': 'Subsurface temperature', 'doc': GOOS(17467), 'version': 'GOOS spec sheet', 'a05': 'EV_SEATEMP', 'membership': 'A05 lists this P01 as its narrower',
            'phenomena': ['Heat storage', 'Water mass', 'Sea level', 'Circulation', 'Stratification', 'Upwelling', 'Mixed layer', 'Coastal shelf exchange']},
    'how': [
      {'dataset': 'calcofi_bottle', 'platform': 'bottle', 'instrument': 'Reversing thermometers on the bottles, then the CTD',
       'principle': 'Originally 20 Nansen/Niskin bottles hung on the wire with reversing thermometers, read on deck after ~45 min; the CTD arrived in the early 1990s under protocols that keep it comparable to the bottle method.',
       'url': frag(CTDFAQ, 'reversing thermometers'), 'page': 'CTD FAQ circa 2020'},
      {'dataset': 'calcofi_ctd-cast', 'platform': 'ctd', 'instrument': 'Sea-Bird CTD, pumped dual temperature and conductivity sensors',
       'principle': 'The average of the two temperature sensors in 1 m bins; pumps push water past the sensors whatever the ship’s roll; lowered at 30 m/min to 100 m, then 60 m/min to 515 m.',
       'url': frag(CTDFAQ, 'Lowering at 30m/min'), 'page': 'CTD FAQ circa 2020'}],
    'scale': {'type': 'linear', 'domain': [-4, 42], 'refs': [
        {'v': CALC['t_freezing_S35'], 'label': 'seawater (S 35) freezes', 'src': 'TEOS-10, gsw.t_freezing', 'kind': 'physical'},
        {'v': 37, 'label': 'a human body', 'src': 'Wikipedia: Human body temperature', 'kind': 'familiar'}],
      'flags': [{'text': 'CTD: 18 values above 35 °C on 2 cruises (1994-01-31JD, 2003-04-31JD), inside the declared 40 °C bound', 'v': 39.86}]},
    'anomaly': anomaly('temperature', '°C'),
    'why': {'text': 'Temperature sets the water’s density, and so the layering that decides whether deep nutrients reach the sunlit surface; off California the warm years are El Niño years and marine heatwaves.',
            'cites': [['bond2015', 'Bond et al. 2015', 'https://doi.org/10.1002/2015GL063306']]},
    'wp': None },

  { 'key': 'salinity', 'glyph': 'S', 'icon': 'cat-physical', 'category': 'Physical Oceanography', 'units_disp': 'PSS-78',
    'kind': 'composition', 'kind_note': 'dissolved ions, not one molecule: its face is what a kilogram of it holds',
    'p01': p01('PSLTZZ01'), 'property': {'id': 'S06 S0600083', 'name': 'Practical salinity'},
    'eov': {'name': 'Subsurface salinity', 'doc': GOOS(17471), 'a05': 'EV_SALIN', 'membership': 'A05 lists this P01 as its narrower',
            'phenomena': ['Water masses', 'Sea level', 'Freshwater storage', 'Circulation', 'Stratification', 'Upwelling', 'Mixed layer', 'Coastal shelf exchange']},
    'composition': {'src': 'TEOS-10 Manual (IOC, SCOR & IAPSO 2010) Table D.3, mass fractions of Reference-Composition sea salt (Millero et al. 2008)',
      'url': 'https://www.teos-10.org/pubs/TEOS-10_Manual.pdf',
      'ions': [['Cl⁻', 'chloride', 0.5503396, 'CHEBI:17996'], ['Na⁺', 'sodium', 0.3065958, 'CHEBI:29101'], ['SO₄²⁻', 'sulfate', 0.0771319, 'CHEBI:16189'],
               ['Mg²⁺', 'magnesium', 0.0365055, 'CHEBI:18420'], ['Ca²⁺', 'calcium', 0.0117186, 'CHEBI:29108'], ['K⁺', 'potassium', 0.0113495, 'CHEBI:29103'],
               ['HCO₃⁻', 'bicarbonate', 0.0029805, 'CHEBI:17544'], ['Br⁻', 'bromide', 0.0019134, 'CHEBI:15858'],
               ['other 7', 'Sr²⁺, CO₃²⁻, B(OH)₄⁻, F⁻, OH⁻, B(OH)₃, CO₂', 0.0002260 + 0.0004078 + 0.0002259 + 0.0000369 + 0.0000038 + 0.0005527 + 0.0000121, None]],
      'sp_med': 33.472, 'sr_med': CALC['SR_med_g_kg'], 'med_src': 'median practical salinity of the bottle series above 10 m, v2026.09.10'},
    'how': [
      {'dataset': 'calcofi_bottle', 'platform': 'bottle', 'instrument': 'Guildline Portasal 8410A salinometer, two per cruise',
       'principle': 'About 225 mL drawn from every Niskin into a numbered KIMAX bottle; the salinometer compares the sample’s conductivity with a reference seawater standard and salinity is computed from the ratio.',
       'precision': 'accuracy ±0.003, precision 0.0003 (Guildline’s specification)', 'url': frag(BOTTLE, 'Salinity Sampling'), 'page': 'Bottle sampling methods'},
      {'dataset': 'calcofi_ctd-cast', 'platform': 'ctd', 'instrument': 'Sea-Bird CTD, dual conductivity cells',
       'principle': 'In-situ conductivity profiles, corrected against the bottle salts, which also confirm each bottle closed at its target depth.',
       'url': frag(BOTTLE, 'dual conductivity'), 'page': 'Bottle sampling methods'}],
    'scale': {'type': 'linear', 'domain': [0, 45], 'refs': [
        {'v': 0, 'label': 'fresh water', 'src': 'definition', 'kind': 'familiar'},
        {'v': 35, 'label': 'standard seawater', 'src': 'TEOS-10 / IAPSO', 'kind': 'physical'}],
      'flags': [{'text': 'bottle minimum 9.50 is the corrupt 2020-07-33P4 cast whose 99 °C was dropped; its salinity still ships', 'v': 9.5},
                {'text': 'CTD: 2,797 values below 20 on 8+ cruises, inside the declared bound of 0', 'v': 9.95}]},
    'anomaly': anomaly('salinity', ''),
    'why': {'text': 'Salinity tags the water masses: the California Current carries fresher Subarctic water south and the Undercurrent carries saltier water from the south; with temperature it sets density.',
            'cites': [['lynn1987', 'Lynn & Simpson 1987', 'https://doi.org/10.1029/JC092iC12p12947']]},
    'wp': WP['Salinity'] },

  { 'key': 'oxygen_umol_kg', 'glyph': 'O₂', 'icon': 'cat-physical', 'category': 'Physical Oceanography', 'units_disp': 'µmol/kg',
    'kind': 'structure', 'kind_note': 'one molecule, drawn from ChEBI’s own coordinates',
    'p01': p01('DOXMZZXX'), 'chem': [chem('dioxygen')], 'svg': ['dioxygen'], 'cas': '7782-44-7', 's27': 'CS002779',
    'eov': {'name': 'Oxygen', 'doc': GOOS(17473), 'a05': 'EV_OXY', 'membership': 'A05 EV_OXY names DOXMZZXX exactly',
            'questions': ['How large are the ocean’s “dead zones” and how fast are they changing?', 'How is the ocean carbon content changing?']},
    'how': [
      {'dataset': 'calcofi_bottle', 'platform': 'bottle', 'instrument': 'Automated Winkler titrator with a UV end-point detector',
       'principle': 'Carpenter’s (1965) modification of Winkler’s 1889 method: oxygen oxidises manganous hydroxide, acid frees iodine in proportion, thiosulfate titrates it, and the end point is read by the UV absorbance of tri-iodide.',
       'steps': ['Mn²⁺ + 2OH⁻ → Mn(OH)₂', '2Mn(OH)₂ + O₂ → 2MnO(OH)₂', 'MnO(OH)₂ + 4H⁺ + 2I⁻ → Mn²⁺ + I₂ + 3H₂O', 'I₂ titrated with thiosulfate'],
       'nm': 350, 'nm_label': 'tri-iodide absorbs at 350 nm', 'url': frag(BOTTLE, 'Dissolved Oxygen Sampling'), 'page': 'Bottle sampling methods'},
      {'dataset': 'calcofi_ctd-cast', 'platform': 'ctd', 'instrument': 'Sea-Bird SBE 43 oxygen sensor',
       'principle': 'A membrane sensor on the pumped CTD line, soaked at 10 m before the downcast, then station-corrected to the Winkler bottles.',
       'url': frag(CTDFAQ, 'SBE43'), 'page': 'CTD FAQ circa 2020'}],
    'scale': {'type': 'linear', 'domain': [0, 520], 'refs': [
        {'v': 0, 'label': 'anoxic', 'src': 'definition', 'kind': 'physical'},
        {'v': 61.0, 'label': 'hypoxic (1.4 ml/L)', 'src': 'Bograd et al. 2008 threshold, converted', 'kind': 'threshold'},
        {'v': CALC['o2sat_umol_kg_at_Tmed_Smed'], 'label': 'air-saturated at 16.1 °C, S 33.5', 'src': 'Garcia & Gordon 1992 via TEOS-10 gsw.O2sol, at the record’s surface medians', 'kind': 'physical'}],
      'flags': [{'text': 'CTD: 37 values above 450 µmol/kg on 5 cruises, inside the declared 700 bound', 'v': 691.4}]},
    'anomaly': anomaly('oxygen_umol_kg', 'µmol/kg'),
    'why': {'text': 'Below the mixed layer off Southern California oxygen has fallen since the 1980s and the hypoxic boundary has risen toward the shelf, squeezing the habitat of fish and invertebrates.',
            'cites': [['bograd2008', 'Bograd et al. 2008', 'https://doi.org/10.1029/2008GL034185']]},
    'wp': WP['Ocean_deoxygenation'] },

  { 'key': 'nitrate', 'glyph': 'NO₃⁻', 'icon': 'cat-nutrients', 'category': 'Nutrients & Chemistry', 'units_disp': 'µmol/L',
    'kind': 'structure', 'kind_note': 'one ion, drawn from ChEBI’s own coordinates',
    'p01': p01('NTRAZZXX'), 'chem': [chem('nitrate')], 'svg': ['nitrate'], 'cas': '14797-55-8', 's27': 'CS002879',
    'eov': {'name': 'Nutrients', 'doc': GOOS(17474), 'a05': None, 'membership': 'GOOS sub-variable “Nitrate (NO3-)”; A05 EV_NUTS lists other nitrate P01s, not NTRAZZXX',
            'questions': ['How do the eutrophication and pollution impact ocean productivity and water quality?', 'Is the biomass of the ocean changing?']},
    'how': [
      {'dataset': 'calcofi_bottle', 'platform': 'bottle', 'instrument': 'Seal Analytical AutoAnalyzer 3, continuous flow',
       'principle': 'A cadmium column reduces nitrate to nitrite; sulfanilamide and N-(1-naphthyl)ethylenediamine couple it into a red azo dye read in a 10 mm flow cell. Nitrate is nitrate-plus-nitrite minus the nitrite run without the column.',
       'steps': ['NO₃⁻ → NO₂⁻ (cadmium column, 98–100 % efficient)', 'NO₂⁻ + sulfanilamide + NED → red azo dye', 'absorbance read at 520 nm'],
       'nm': 520, 'nm_label': 'the red dye absorbs green light, 520 nm', 'url': frag(BOTTLE, 'Nutrient Sampling'), 'page': 'Bottle sampling methods'}],
    'scale': {'type': 'linear', 'domain': [0, 100], 'refs': [
        {'v': 714, 'label': 'US drinking-water limit (10 mg/L as N)', 'src': 'US EPA National Primary Drinking Water Regulations, converted', 'kind': 'familiar', 'off': True}],
      'flags': [{'text': 'no bound declared; the maximum is 95 µmol/L', 'v': 95}]},
    'anomaly': anomaly('nitrate', 'µmol/L'),
    'why': {'text': 'Nitrate is the fertiliser upwelling lifts into the light; the spring blooms, and the fisheries above them, run on it. At depth it has risen as oxygen fell, the fingerprint of changing source waters.',
            'cites': [['bograd2015', 'Bograd et al. 2015', 'https://doi.org/10.1016/j.dsr2.2014.04.009']]},
    'wp': WP['Upwelling'] },

  { 'key': 'ammonia', 'glyph': 'NH₄⁺', 'icon': 'cat-nutrients', 'category': 'Nutrients & Chemistry', 'units_disp': 'µmol/L',
    'kind': 'structure', 'kind_note': 'two species in equilibrium; the key says ammonia, NERC and the method say ammonium',
    'p01': p01('AMONZZXX'), 'p01_borrowed_from': ['r_ammonium', 'btl_ammonium'], 'chem': [chem('ammonium'), chem('ammonia', 'its conjugate base')],
    'svg': ['ammonium', 'ammonia'], 'cas': '14798-03-9', 's27': 'CS026908',
    'eov': {'name': 'Nutrients', 'doc': GOOS(17474), 'a05': None, 'membership': 'GOOS sub-variable “Ammonium (NH4)”',
            'questions': ['Is the biomass of the ocean changing?']},
    'how': [
      {'dataset': 'calcofi_bottle', 'platform': 'bottle', 'instrument': 'Seal Analytical AutoAnalyzer 3, continuous flow',
       'principle': 'The Berthelot reaction: hypochlorous acid and phenol react with ammonium in alkaline solution to form indophenol blue, read in a 10 mm flow cell (Koroleff 1969, 1970).',
       'steps': ['NH₄⁺ + phenol + hypochlorite (alkaline) → indophenol blue', 'absorbance read at 660 nm'],
       'nm': 660, 'nm_label': 'indophenol blue absorbs red light, 660 nm', 'url': frag(BOTTLE, 'Nutrient Sampling'), 'page': 'Bottle sampling methods'}],
    'scale': {'type': 'linear', 'domain': [0, 2], 'refs': [], 'zero_pct': 57.8,
      'flags': [{'text': '57.8 % of values are exactly zero; the maximum, 33.58 µmol/L, is off this scale', 'v': 33.58, 'off': True}]},
    'anomaly': None, 'anomaly_none': 'Not drawn: 57.8 % of the values are exactly zero (left-censored), so a yearly mean anomaly is a statement about the detection limit, not the ocean.',
    'why': {'text': 'Ammonium is nitrogen recycled by zooplankton and bacteria; phytoplankton take it up before nitrate, so production fed by it is “regenerated” rather than “new”.',
            'cites': [['dugdale1967', 'Dugdale & Goering 1967', 'https://doi.org/10.4319/lo.1967.12.2.0196']]},
    'wp': WP['Ammonium'] },

  { 'key': 'chlorophyll_a', 'glyph': 'Chl a', 'icon': 'cat-productivity', 'category': 'Productivity & Pigments', 'units_disp': 'µg/L',
    'kind': 'structure', 'kind_note': 'one molecule, 65 heavy atoms; ChEBI’s layout keeps the magnesium in the ring',
    'p01': p01('CPHLZZXX'), 'chem': [chem('chlorophyll_a'), chem('pheophytin_a', 'what acid turns it into')], 'svg': ['chlorophyll_a', 'pheophytin_a'],
    'cas': '479-61-8', 's27': 'CS002896',
    'eov': {'name': 'Phytoplankton biomass and diversity', 'doc': GOOS(17507), 'a05': 'EV_CHLA', 'membership': 'A05 EV_CHLA is a broader of this P01',
            'phenomena': ['Status and trends', 'Role in transport and cycling of elements', 'HAB occurrence']},
    'how': [
      {'dataset': 'calcofi_bottle', 'platform': 'bottle', 'instrument': 'Filter, acetone extraction, benchtop fluorometer',
       'principle': 'A known volume is filtered onto a GF/F filter, cold-extracted in 90 % acetone for 24–48 h and read on a fluorometer; the extract is then acidified, which strips the magnesium and turns chlorophyll into phaeopigment, and read again (Yentsch & Menzel 1963; Holm-Hansen et al. 1965; Lorenzen 1967).',
       'acid': True, 'url': frag(BOTTLE, 'Chlorophyll-a & Phaeopigment Sampling'), 'page': 'Bottle sampling methods'}],
    'scale': {'type': 'log', 'domain': [0.01, 100], 'refs': [],
      'flags': [{'text': 'no bound declared; the maximum is 66.11 µg/L', 'v': 66.11}]},
    'anomaly': anomaly('chlorophyll_a', 'µg/L'),
    'why': {'text': 'Every phytoplankter carries chlorophyll-a, so it is the standard measure of how much plant life the sunlit layer holds: the base of the food web the rest of the survey counts.',
            'cites': []},
    'wp': WP['Phytoplankton'] },

  { 'key': 'ph', 'glyph': 'pH', 'icon': 'cat-carbonate', 'category': 'Carbonate System', 'units_disp': 'pH',
    'kind': 'scale', 'kind_note': 'minus the log of the hydrogen ion: its face is the scale everyone learned in school',
    'p01': p01('PHXXZZXX'), 'chem': [{'key': 'hydron', 'chebi': 'CHEBI:15378', 'name': 'hydron', 'formula': 'H', 'charge': 1, 'mass': '1.008', 'definition': None, 'role': 'the ion it counts'}],
    'property': {'id': 'S06 S0600281', 'name': 'pH (unspecified scale)'},
    'eov': {'name': 'Inorganic carbon', 'doc': GOOS(17475), 'a05': None, 'membership': 'GOOS sub-variable pH; A05 EV_CO2 reached only through the P06 unit',
            'questions': ['What are rates and impacts of ocean acidification?']},
    'how': [
      {'dataset': 'calcofi_ctd-cast', 'platform': 'ctd', 'instrument': 'A pH sensor on the CTD (model not on record)',
       'principle': 'The CTD cast files carry a p_h column with its own p_hq quality code, 2009 onward; the FAQ notes newer pH sensors need fewer calibration seawater samples. The scale (total, seawater or NBS) is not stated anywhere in the record.',
       'url': frag(CTDFAQ, 'pH sensors'), 'page': 'CTD FAQ circa 2020'}],
    'scale': {'type': 'linear', 'domain': [0, 14], 'refs': [
        {'v': 2.5, 'lo': 2, 'hi': 3, 'label': 'vinegar', 'src': 'Wikipedia: pH', 'kind': 'familiar'},
        {'v': 5.0, 'label': 'black coffee', 'src': 'Wikipedia: pH', 'kind': 'familiar'},
        {'v': 6.65, 'lo': 6.5, 'hi': 6.8, 'label': 'milk', 'src': 'Wikipedia: pH', 'kind': 'familiar'},
        {'v': 7.0, 'label': 'pure water (25 °C)', 'src': 'Wikipedia: pH', 'kind': 'physical'},
        {'v': 7.4, 'lo': 7.34, 'hi': 7.45, 'label': 'blood', 'src': 'Wikipedia: pH', 'kind': 'familiar'},
        {'v': 11.25, 'lo': 11.0, 'hi': 11.5, 'label': 'household ammonia', 'src': 'Wikipedia: pH', 'kind': 'familiar'},
        {'v': 12.5, 'label': 'bleach', 'src': 'Wikipedia: pH', 'kind': 'familiar'},
        {'v': 8.15, 'label': 'ocean surface 1950', 'src': 'Wikipedia: Ocean acidification', 'kind': 'threshold'},
        {'v': 8.05, 'label': '2020', 'src': 'Wikipedia: Ocean acidification', 'kind': 'threshold'}],
      'flags': [{'text': '378 values below 7 and 13 sitting on the declared bound of 9', 'v': 6.0}]},
    'anomaly': None, 'anomaly_none': 'Not drawn: the release builds no climatology for pH (the record’s climatology flag is false), and the sensor series starts in 2009.',
    'why': {'text': 'Upwelling brings water that is naturally low in pH and carbonate onto the shelf; ocean acidification pushes it further toward water that is corrosive to shells.',
            'cites': [['feely2008', 'Feely et al. 2008', 'https://doi.org/10.1126/science.1155676']]},
    'wp': WP['Ocean_acidification'] },

  { 'key': 'dic', 'glyph': 'DIC', 'icon': 'cat-carbonate', 'category': 'Carbonate System', 'units_disp': 'µmol/kg',
    'kind': 'composition', 'kind_note': 'three species in one pool: its face is how the pool splits at seawater pH',
    'p01': p01('TCO2MSXX'), 'chem': [chem('carbon_dioxide', 'dissolved CO₂'), chem('hydrogencarbonate', 'bicarbonate'), chem('carbonate', 'carbonate')],
    'svg': ['carbon_dioxide', 'hydrogencarbonate', 'carbonate'], 'cas': '7440-44-0', 's27': 'CS002894',
    'bjerrum': {'pH': CALC['pH_total'], 'co2': CALC['frac_co2'], 'hco3': CALC['frac_hco3'], 'co3': CALC['frac_co3'], 'omega_arag': CALC['omega_arag'],
                'pco2': CALC['pco2'], 'curve': CALC['bjerrum'],
                'src': 'PyCO2SYS 1.8.3 (Lueker et al. 2000 constants) from the record’s surface medians: DIC 2009.8, TA 2234.65 µmol/kg, 16.08 °C, S 33.47'},
    'eov': {'name': 'Inorganic carbon', 'doc': GOOS(17475), 'a05': 'EV_CO2', 'membership': 'A05 EV_CO2 is a broader of this P01',
            'questions': ['How is the ocean carbon content changing?', 'What are rates and impacts of ocean acidification?']},
    'how': [
      {'dataset': 'calcofi_dic', 'platform': 'bottle', 'instrument': 'Drawn from the rosette, analysed ashore',
       'principle': 'Samples from the Niskins at selected stations; NCEI accession 0301029 lists a CO₂ gas analyser for DIC and a titrator for alkalinity, calibrated to the reference materials Andrew Dickson’s Scripps laboratory makes for the world.',
       'url': frag(BOTTLE, 'Dissolved Inorganic Carbon (DIC) Sampling'), 'page': 'Bottle sampling methods'}],
    'scale': None,
    'anomaly': None, 'anomaly_none': 'Not drawn: 1,028 values on 99 cruises since 1983 leave the climatology only 4 cells, all at 10 m.',
    'why': {'text': 'The ocean takes up about a quarter of the CO₂ people emit and DIC is where it sits; with alkalinity it fixes pH and the carbonate that shells are built from.',
            'cites': [['friedlingstein2025', 'Global Carbon Budget', 'https://globalcarbonbudget.org/']]},
    'calcofi_quote': 'first, the long-term characterization of the inorganic carbon system and its response to changing ocean climate, and second, measurements of pH in the coastal zone in order to monitor the impact of ‘corrosive’ waters on benthic ecosystems in the Southern California Bight.',
    'wp': WP['Dissolved_inorganic_carbon'] },

  { 'key': 'synechococcus', 'glyph': 'Syn', 'icon': 'cat-picoplankton', 'category': 'Picoplankton & Bacteria', 'units_disp': 'cells/mL',
    'kind': 'organism', 'kind_note': 'a count of a living thing: its face is the species face, found through NERC’s WoRMS id',
    'p01': p01('P700A90Z'), 'taxon': {'s25': 'BE005403', 'worms': 160572, 'name': 'Synechococcus', 'species_page': 404,
                                      'size_um': [0.8, 1.5], 'size_src': 'Wikipedia: Synechococcus', 'hair_um': 70},
    'eov': {'name': 'Microbe biomass and diversity (pilot)', 'doc': GOOS(36264), 'a05': None, 'membership': 'GOOS pilot EOV, August 2026',
            'phenomena': ['Status and trends', 'Role in cycling of elements']},
    'how': [
      {'dataset': 'cce-lter_picoplankton-bacteria', 'platform': 'lab', 'instrument': 'Beckman-Coulter EPICS Altra flow cytometer',
       'principle': 'A 2 mL subsample from the Niskin is fixed with paraformaldehyde, frozen in liquid nitrogen and kept at −80 °C; ashore the cells are counted one by one as they stream past the laser, Synechococcus resolved by its own pigment fluorescence.',
       'url': frag(BOTTLE, 'Picophytoplankton & Prokaryotes'), 'page': 'Bottle sampling methods'}],
    'scale': {'type': 'log', 'domain': [10, 1000000], 'refs': [
        {'v': 10671 * 5, 'label': 'in a 5 mL teaspoon, at the median', 'src': 'the record’s median × 5 mL', 'kind': 'familiar'}],
      'flags': []},
    'anomaly': None, 'anomaly_none': 'Not drawn: one to three cruises a year since 2004 is too thin for a yearly anomaly of a count.',
    'why': {'text': 'One of the most abundant photosynthesisers on Earth, too small for any net: the survey sees it only by counting cells in a bottle of water.',
            'cites': []},
    'wp': WP['Synechococcus'] },

  { 'key': 'wind_speed_ms', 'glyph': 'U', 'icon': 'cat-meteorology', 'category': None, 'units_disp': 'm/s',
    'kind': 'none', 'kind_note': 'no NERC concept on the key and no category in the registry: the face falls back to the scale',
    'p01': None, 'a05_only': {'code': 'EV_WSPD', 'pref': 'Wind speed', 'def': 'The speed of the air (absolute) in the atmosphere.'},
    'eov': {'name': 'Surface wind (GCOS ECV)', 'doc': 'http://vocab.nerc.ac.uk/collection/A05/current/EV_WSPD/', 'a05': 'EV_WSPD', 'membership': 'no P01 on the key, so no link is drawn',
            'phenomena': ['Upwelling', 'Mixed layer', 'Air-sea fluxes']},
    'how': [
      {'dataset': 'calcofi_mets', 'platform': 'mast', 'instrument': 'Meteorological sensors on the ship’s mast, logged underway',
       'principle': 'About one-minute values while the ship steams between stations. calcofi.org’s underway page renders client-side, so a fetcher reads an empty shell; the sensor model and the unit’s source are not in the record.',
       'url': 'https://calcofi.org/sampling-info/methods/underway_methods/', 'page': 'Underway methods'}],
    'scale': {'type': 'beaufort', 'domain': [0, 46],
      'beaufort': [[0, 0, 0.3, 'Calm'], [1, 0.3, 1.5, 'Light air'], [2, 1.6, 3.3, 'Light breeze'], [3, 3.4, 5.4, 'Gentle breeze'], [4, 5.5, 7.9, 'Moderate breeze'],
                   [5, 8.0, 10.7, 'Fresh breeze'], [6, 10.8, 13.8, 'Strong breeze'], [7, 13.9, 17.1, 'Near gale'], [8, 17.2, 20.7, 'Gale'],
                   [9, 20.8, 24.4, 'Strong gale'], [10, 24.5, 28.4, 'Storm'], [11, 28.5, 32.6, 'Violent storm'], [12, 32.7, 46, 'Hurricane force']],
      'src': 'Wikipedia: Beaufort scale (WMO m/s bands)', 'refs': [],
      'flags': [{'text': '217 values at hurricane force (≥ 32.7 m/s) on 7 cruises; read as knots, the median falls from Beaufort 5 to 3 and the 95th percentile from 9 to 6', 'v': 44.19}]},
    'anomaly': None, 'anomaly_none': 'Not drawn: the underway series has no climatology and covers 22 cruises, 2016–2022.',
    'why': {'text': 'Winds blowing toward the equator along the coast push surface water offshore and pull cold, nutrient-rich water up from below: the engine of the California Current’s productivity.',
            'cites': [['bakun1973', 'Bakun 1973', 'https://repository.library.noaa.gov/view/noaa/9031'], ['jacox2018', 'Jacox et al. 2018', 'https://doi.org/10.1029/2018JC014187']]},
    'wp': None },
  { 'key': 'est_nitrate_sta_corr', 'glyph': 'NO₃⁻*', 'icon': 'cat-nutrients', 'category': 'Nutrients & Chemistry', 'units_disp': 'µmol/L',
    'kind': 'standsin', 'kind_note': 'no NERC concept on the key: it borrows nitrate\u2019s face and says so',
    'p01': None, 'stands_in': {'face_of': 'nitrate', 'label': 'Nitrate', 'why': 'estimated from the ISUS sensor'},
    'chem': [chem('nitrate')], 'svg': ['nitrate'],
    'eov': {'name': 'Nutrients', 'doc': GOOS(17474), 'a05': None, 'membership': 'through the face it borrows: GOOS sub-variable \u201cNitrate (NO3-)\u201d',
            'questions': ['How do the eutrophication and pollution impact ocean productivity and water quality?']},
    'how': [
      {'dataset': 'calcofi_ctd-cast', 'platform': 'ctd', 'instrument': 'ISUS in-situ ultraviolet nitrate sensor on the CTD',
       'principle': 'The ISUS voltage is converted to nitrate by a regression fitted per cast against that cast\u2019s bottle nitrates (about 20, fliers omitted), from 1 m bin-averaged sensor data; a 500 m cast with ten or more bottles is required, so shallow or bottle-poor casts carry none by design.',
       'url': frag(CTDFAQ, 'bottle'), 'page': 'CTD FAQ circa 2020', 'src_note': 'principle: the record\u2019s derivation text for est_nitrate_sta_corr'}],
    'scale': {'type': 'linear', 'domain': [0, 100], 'refs': [
        {'v': 714, 'label': 'US drinking-water limit (10 mg/L as N)', 'src': 'US EPA National Primary Drinking Water Regulations, converted', 'kind': 'familiar', 'off': True}],
      'flags': []},
    'anomaly': None, 'anomaly_none': 'Not drawn in the mock: the record carries a climatology for this key, so the page would draw its own bands; the face it borrows is only the picture.',
    'why': {'text': 'A sensor on the CTD reads nitrate every metre where the bottles sample a couple of dozen depths, so it resolves the nitracline the bottles straddle.', 'cites': []},
    'wp': None },
]

for c in cast:
    c['rec'] = rec(c['key'])
    c['label'] = {'ammonia': 'Ammonium', 'nitrate': 'Nitrate', 'chlorophyll_a': 'Chlorophyll-a', 'ph': 'pH', 'dic': 'Dissolved inorganic carbon',
                  'synechococcus': 'Synechococcus', 'wind_speed_ms': 'Wind speed', 'est_nitrate_sta_corr': 'Estimated nitrate', 'oxygen_umol_kg': 'Dissolved oxygen'}.get(c['key'], c['rec']['label'])
    c['label_record'] = c['rec']['label']

# the why: one pick on the page, the rest collapsed under "other ways to say why" (Ben, 2026-09-11)
ALTS = {
  'temperature': [('authored', 'A warm year off California is usually a lean one: warmer, more layered water brings fewer nutrients up, and the plankton the rest of the food web eats decline.', [['roemmich1995', 'Roemmich & McGowan 1995', 'https://doi.org/10.1126/science.267.5202.1324']])],
  'salinity': [('authored', 'Salinity and temperature together set seawater\u2019s density, which drives the currents and decides how deep winter mixing reaches.', [['teos10', 'IOC et al. 2010 (TEOS-10)', 'https://www.teos-10.org/pubs/TEOS-10_Manual.pdf']])],
  'oxygen_umol_kg': [('authored', 'Oxygen is the balance of what the ocean takes in at the surface and what animals and bacteria use below; a warmer ocean holds less and mixes less, so it is losing oxygen.', [['breitburg2018', 'Breitburg et al. 2018', 'https://doi.org/10.1126/science.aam7240']])],
  'nitrate': [('authored', 'Nitrate at the surface is a fingerprint of recent upwelling: where it is high, cold deep water has just arrived and a bloom follows.', [])],
  'ammonia': [('authored', 'Most nitrogen in the sunlit layer is recycled several times before it sinks; ammonium measures that recycling, excreted by animals and released as bacteria break organic matter down.', [])],
  'chlorophyll_a': [('authored', 'Chlorophyll is what satellites see as ocean colour, and bottle chlorophyll like CalCOFI\u2019s is among the ground truth their algorithms were fitted to.', [['oreilly1998', 'O\u2019Reilly et al. 1998', 'https://doi.org/10.1029/98JC02160']])],
  'ph': [('authored', 'Lower pH means less carbonate in the water, and the shells of pteropods off California already show dissolution where corrosive water reaches the surface.', [['bednarsek2014', 'Bednaršek et al. 2014', 'https://doi.org/10.1098/rspb.2014.0123']])],
  'dic': [],
  'synechococcus': [('authored', 'Where the water is warm and poor in nutrients the smallest cells win, so the picoplankton counts show the community shifting in warm years.', [])],
  'wind_speed_ms': [('authored', 'Wind also mixes the surface layer: a windy spell deepens the mixed layer and brings nutrients up even far from the coast.', [])],
  'est_nitrate_sta_corr': [('authored', 'Nitrate is the fertiliser upwelling lifts into the light; the spring blooms, and the fisheries above them, run on it.', [['bograd2015', 'Bograd et al. 2015', 'https://doi.org/10.1016/j.dsr2.2014.04.009']])],
}
for c in cast:
    a = [{'kind': k, 'text': t, 'cites': ci} for k, t, ci in ALTS.get(c['key'], [])]
    for q in (c['eov'].get('questions') or []):
        a.append({'kind': 'goos', 'text': q, 'cites': [['goos', 'GOOS EOV sheet: ' + c['eov']['name'], c['eov']['doc']]]})
    if c.get('calcofi_quote'):
        a.append({'kind': 'calcofi', 'text': 'CalCOFI samples it for ' + c['calcofi_quote'], 'cites': [['calcofi', 'calcofi.org', c['how'][0]['url']]]})
    if c.get('wp') and c['wp'].get('extract'):
        ex = re.split(r'(?<=\.)\s', c['wp']['extract'])
        a.append({'kind': 'wikipedia', 'text': ' '.join(ex[:2]), 'cites': [['wp', 'Wikipedia: ' + c['wp']['title'] + ', rev. ' + str(c['wp']['revision']) + ', CC BY-SA 4.0', c['wp']['url'] + '?oldid=' + str(c['wp']['revision'])]]})
    c['why']['alts'] = a

# the 37 keys with no concept: whose face each borrows ("stands in", Ben 2026-09-11), or the scale alone
STANDS = {'r_temperature': 'temperature', 'tsg1_temp_c': 'temperature', 'sst_c': 'temperature', 'air_temp_c': 'temperature',
          'tsg1_salinity_psu': 'salinity', 'sss_psu': 'salinity',
          'isus_v': 'nitrate', 'est_nitrate_cruise_corr': 'nitrate', 'est_nitrate_sta_corr': 'nitrate',
          'fluorescence_v': 'chlorophyll_a', 'est_chlorophyll_a_sta_corr': 'chlorophyll_a', 'est_chlorophyll_a_cruise_corr': 'chlorophyll_a', 'chl_fluor': 'chlorophyll_a',
          'c14_mean': 'hydrogencarbonate', 'c14_dark': 'hydrogencarbonate', 'c14_rep1': 'hydrogencarbonate', 'c14_rep2': 'hydrogencarbonate',
          'oxygen': 'oxygen_umol_kg', 'sw_ph': 'ph', 'ammonia': 'ammonium (P01 being registered)'}
SCALE_ONLY = ['r_dynamic_height', 'r_salinity_sva', 'dynamic_height', 'specific_volume_anomaly', 'transmissometer', 'par', 'spar', 'light_pct',
              'long_wave_rad', 'short_wave_rad', 'par_surf', 'atm_pressure_mb', 'wind_dir_deg', 'wind_speed_ms', 'rel_humidity_pct', 'bottom_depth_m']
NONE_LEFT = ['uws_flow']

DATA = {'built': '2026-09-11', 'release': REL['release'], 'counts': REL['counts'], 'svg': SV, 'oni': ONI, 'cast': cast,
        'kinds': {'structure': 26, 'composition': 13, 'scale': 9, 'organism': 4, 'none': 37},
        'stands': {'borrow': len(STANDS), 'scale_only': len(SCALE_ONLY), 'left': NONE_LEFT, 'map': STANDS, 'scale_keys': SCALE_ONLY},
        'datasets': {d['dataset_key']: {'name': d['dataset_name_short'], 'color': d['color']} for d in REL['datasets']}}
DATA['datasets']['cce-lter_picoplankton-bacteria'] = DATA['datasets'].get('cce-lter_picoplankton-bacteria', {'name': 'Picoplankton & Bacteria', 'color': '#1f88cc'})
open('data.json', 'w').write(json.dumps(DATA, ensure_ascii=False, separators=(',', ':')))
print(len(json.dumps(DATA)), 'bytes;', [(c['key'], (c['anomaly'] or {}).get('spark_band')) for c in cast])
