import json, re, urllib.request, sys, time
def get(uri):
    u = uri.rstrip('/') + '/?_profile=nvs&_mediatype=application/ld%2Bjson'
    req = urllib.request.Request(u, headers={'User-Agent': 'calcofi.io probe (ben@ecoquants.com)'})
    try:
        return json.load(urllib.request.urlopen(req, timeout=30))
    except Exception as e:
        return {'error': str(e)}
def ids(x):
    if x is None: return []
    if isinstance(x, dict): x = [x]
    return [i['@id'] if isinstance(i, dict) else i for i in x]
def val(x):
    if isinstance(x, dict): return x.get('@value')
    if isinstance(x, list): return '; '.join(str(val(i)) for i in x)
    return x
codes = sys.argv[1:]
out = {}
for c in codes:
    d = get(f'http://vocab.nerc.ac.uk/collection/P01/current/{c}/')
    rec = {'pref': val(d.get('skos:prefLabel')), 'alt': val(d.get('skos:altLabel')), 'def': val(d.get('skos:definition')),
           'broader': ids(d.get('skos:broader')), 'related': ids(d.get('skos:related'))}
    links = rec['broader'] + rec['related']
    for l in links:
        coll = l.split('/collection/')[1].split('/')[0] if '/collection/' in l else l
        if coll in ('S27', 'S06', 'S26', 'P02', 'P07', 'S02', 'S03', 'S04', 'S05', 'A05', 'P06', 'S25'):
            dd = get(l)
            rec.setdefault('links', {})[coll + ' ' + l.rstrip('/').split('/')[-1]] = {
                'pref': val(dd.get('skos:prefLabel')), 'def': (val(dd.get('skos:definition')) or '')[:300],
                'alt': val(dd.get('skos:altLabel')),
                'sameAs': ids(dd.get('owl:sameAs')), 'exact': ids(dd.get('skos:exactMatch')),
                'broader': [b for b in ids(dd.get('skos:broader')) if 'A05' in b or 'S27' in b or 'CHEBI' in b.upper()],
                'related': [b for b in ids(dd.get('skos:related')) if 'A05' in b or 'chebi' in b.lower() or 'pubchem' in b.lower() or 'wikidata' in b.lower()],
                'other': {k: v for k, v in dd.items() if k not in ('@context','skos:prefLabel','skos:definition','skos:altLabel','skos:broader','skos:related','skos:narrower','pav:hasVersion','pav:hasCurrentVersion','void:inDataset','skos:inScheme','@id','@type','owl:deprecated','skos:note','dc:identifier','dce:identifier','skos:notation','owl:versionInfo','pav:version','dc:date','pav:authoredOn')}
            }
            time.sleep(0.2)
    out[c] = rec
    time.sleep(0.2)
json.dump(out, open('nvs_probe.json', 'w'), indent=1, ensure_ascii=False)
