import json, urllib.request, urllib.parse, time
UA = {'User-Agent': 'calcofi.io measurement-faces probe (ben@ecoquants.com)'}
def get(u):
    return json.load(urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=60))
chebi = {'nitrate':17632,'nitrite':16301,'phosphate':18367,'silicate':29241,'orthosilicic_acid':26675,'ammonium':28938,'ammonia':16134,
         'dioxygen':15379,'chlorophyll_a':18230,'pheophytin_a':44898,'carbon':27594,'carbon_dioxide':16526,'hydrogencarbonate':17544,
         'carbonate':41609,'hydron':15378,'chloride':17996,'sodium':29101,'sulfate':16189,'magnesium':18420,'calcium':29108,'potassium':29103,'bromide':15858,'water':15377}
out = {}
for k, i in chebi.items():
    try:
        d = get(f'https://www.ebi.ac.uk/chebi/backend/api/public/compound/CHEBI:{i}/')
        s = d.get('default_structure') or {}
        c = d.get('chemical_data') or {}
        out[k] = {'chebi': f'CHEBI:{i}', 'name': d.get('name'), 'definition': d.get('definition'), 'stars': d.get('stars'),
                  'smiles': s.get('smiles'), 'inchikey': s.get('standard_inchi_key'), 'formula': c.get('formula'), 'charge': c.get('charge'), 'mass': c.get('mass'),
                  'roles': [r.get('name') if isinstance(r, dict) else r for r in (d.get('roles_classification') or [])][:8]}
    except Exception as e:
        out[k] = {'chebi': f'CHEBI:{i}', 'error': str(e)}
    time.sleep(0.3)
json.dump(out, open('chebi.json', 'w'), indent=1, ensure_ascii=False)
for k, v in out.items(): print(k, '|', v.get('name'), '|', v.get('formula'), v.get('charge'), '|', v.get('smiles'), '|', (v.get('definition') or '')[:110], '|', v.get('roles'))
wp = {}
for t in ['Ocean_deoxygenation','Ocean_acidification','Upwelling','Nitrate','Ammonium','Chlorophyll_a','Salinity','Seawater','Synechococcus','Sea_surface_temperature','Dissolved_inorganic_carbon','PH','Winkler_test_for_dissolved_oxygen','CTD_(instrument)','Niskin_bottle','Salinometer','Flow_cytometry','California_Current','2014–2016_Northeast_Pacific_marine_heatwave','Phytoplankton','Total_inorganic_carbon','Alkalinity']:
    try:
        d = get('https://en.wikipedia.org/api/rest_v1/page/summary/' + urllib.parse.quote(t))
        wp[t] = {'title': d.get('title'), 'url': d.get('content_urls', {}).get('desktop', {}).get('page'), 'revision': d.get('revision'), 'timestamp': d.get('timestamp'), 'extract': d.get('extract'),
                 'thumb': (d.get('originalimage') or {}).get('source')}
    except Exception as e:
        wp[t] = {'error': str(e)}
    time.sleep(0.2)
json.dump(wp, open('wp.json', 'w'), indent=1, ensure_ascii=False)
for k, v in wp.items(): print('WP', k, '|', v.get('title'), v.get('revision'), '|', (v.get('extract') or v.get('error') or '')[:160])
