import json, sys, urllib.request, urllib.parse
UA='calcofi-species-mockup/0.1 (https://calcofi.io; bdbest@gmail.com)'
def gj(url):
    req=urllib.request.Request(url, headers={'User-Agent':UA,'Accept':'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=40) as r: return json.loads(r.read())
    except Exception as e: return {'_error':str(e)}
def gt(url):
    req=urllib.request.Request(url, headers={'User-Agent':UA})
    with urllib.request.urlopen(req, timeout=40) as r: return r.read().decode()
build = gj('https://api.phylopic.org/ping').get('build') or gj('https://api.phylopic.org/').get('build')
print('build', build, file=sys.stderr)
def by_name(name):
    q = urllib.parse.quote(name.lower())
    d = gj(f'https://api.phylopic.org/nodes?build={build}&filter_name={q}&embed_items=true&embed_primaryImage=true&page=0')
    items = (d.get('_embedded') or {}).get('items') or []
    for n in items:
        img = (n.get('_embedded') or {}).get('primaryImage')
        if img:
            L = img['_links']
            return {'query': name, 'node': n['_links']['self'].get('title'), 'image_uuid': L['self']['href'].split('/images/')[1].split('?')[0],
                    'specific_node': (L.get('specificNode') or {}).get('title'), 'general_node': (L.get('generalNode') or {}).get('title'),
                    'contributor': L.get('contributor',{}).get('title'), 'license': L.get('license',{}).get('href'),
                    'attribution': img.get('attribution'), 'vector': L.get('vectorFile',{}).get('href')}
    return None
# walk lineage until a node with a primary image is found
CASES_ALL = {
 'anchovy':   ['Engraulis mordax','Engraulis','Engraulidae','Clupeiformes'],
 'krill':     ['Euphausia pacifica','Euphausia','Euphausiidae','Euphausiacea'],
 'squid':     ['Doryteuthis opalescens','Doryteuthis','Loliginidae','Myopsida','Decapodiformes'],
 'shearwater':['Ardenna grisea','Ardenna','Procellariidae','Procellariiformes'],
 'hake':      ['Merluccius productus','Merluccius','Merlucciidae','Gadiformes'],
 'lanternfish':['Stenobrachius leucopsarus','Stenobrachius','Myctophidae','Myctophiformes'],
 'pseudonitzschia':['Pseudo-nitzschia','Bacillariaceae','Bacillariales','Bacillariophyceae','Bacillariophyta'],
 'human':     ['Homo sapiens'],
 'sardine_species': ['Sardinops sagax','Sardinops'],
 'sebastes_jordani': ['Sebastes jordani','Sebastes','Sebastidae'],
}
import os
out = json.load(open('phylopic_by_name.json')) if os.path.exists('phylopic_by_name.json') else {}
CASES = {k:v for k,v in CASES_ALL.items() if not out.get(k)}
for k, chain in CASES.items():
    hit = None
    for name in chain:
        hit = by_name(name)
        if hit:
            hit['steps_up'] = chain.index(name); break
    if hit and hit.get('vector'):
        try: hit['svg'] = gt(hit['vector'])
        except Exception as e: hit['svg_error'] = str(e)
    out[k] = hit
    print(k, '->', hit and (hit['query'], hit['node'], hit['specific_node'], hit['license'][-15:], hit['contributor'], 'up', hit['steps_up'], 'svg', len(hit.get('svg','')) if hit else None), file=sys.stderr)
json.dump(out, open('phylopic_by_name.json','w'), indent=1)
