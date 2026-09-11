import json, sys, time, urllib.request, urllib.parse, re
UA = 'calcofi-species-mockup/0.1 (https://calcofi.io; bdbest@gmail.com)'
def get(url, hdr=None, timeout=40):
    req = urllib.request.Request(url, headers={'User-Agent': UA, 'Accept': 'application/json', **(hdr or {})})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()
def gj(url, **k):
    try: return json.loads(get(url, **k))
    except Exception as e: return {'_error': str(e)}

TAXA = [  # (label, worms_id or None, name, calcofi key)
  ('sardine', 217452, 'Sardinops sagax', 'worms:217452'),
  ('anchovy', 272286, 'Engraulis mordax', 'worms:272286'),
  ('krill', 237851, 'Euphausia pacifica', 'worms:237851'),
  ('squid', 574540, 'Doryteuthis opalescens', 'worms:574540'),
  ('shearwater', None, 'Ardenna grisea', 'itis:1255050'),
  ('dolphin', 137094, 'Delphinus delphis', 'worms:137094'),
  ('chaetoceros', 148985, 'Chaetoceros', 'worms:148985'),
  ('hake', 272458, 'Merluccius productus', 'worms:272458'),
  ('sebastes', 126175, 'Sebastes', 'worms:126175'),
  ('lanternfish', None, 'Stenobrachius leucopsarus', None),
  ('pseudonitzschia', None, 'Pseudo-nitzschia', None),
  ('human', None, 'Homo sapiens', None),
]
out = {}
for label, wid, name, key in TAXA:
    rec = {'name': name, 'calcofi_key': key}
    # --- WoRMS
    if wid is None:
        m = gj('https://www.marinespecies.org/rest/AphiaIDByName/' + urllib.parse.quote(name) + '?marine_only=false')
        wid = m if isinstance(m, int) else None
    rec['worms_id'] = wid
    if wid:
        r = gj(f'https://www.marinespecies.org/rest/AphiaRecordByAphiaID/{wid}')
        rec['worms'] = {k: r.get(k) for k in ['scientificname','authority','status','rank','citation']}
        a = gj(f'https://www.marinespecies.org/rest/AphiaAttributesByAphiaID/{wid}')
        sizes = []
        def walk(lst, ctx):
            for x in (lst if isinstance(lst, list) else []):
                c = dict(ctx); c[x.get('measurementType')] = x.get('measurementValue')
                if x.get('measurementType') == 'Body size':
                    sizes.append(c)
                if x.get('children'): walk(x['children'], c)
        walk(a, {})
        # flatten body size entries (unit/type/dimension live in children)
        def flat(a):
            res = []
            for x in (a if isinstance(a, list) else []):
                if x.get('measurementType') == 'Body size':
                    d = {'value': x.get('measurementValue'), 'quality': x.get('qualitystatus'), 'source_id': x.get('source_id')}
                    def kids(l):
                        for y in l or []:
                            d[y.get('measurementType')] = y.get('measurementValue'); kids(y.get('children'))
                    kids(x.get('children')); res.append(d)
                res += flat(x.get('children'))
            return res
        rec['worms_body_size'] = flat(a)
        # --- PhyloPic by WoRMS id (nearest-ancestor fallback)
        p = gj(f'https://api.phylopic.org/resolve/marinespecies.org/taxname/{wid}?embed_primaryImage=true')
        img = (p.get('_embedded') or {}).get('primaryImage')
        if img:
            L = img['_links']
            rec['phylopic'] = {
                'resolved_node': (p.get('_links') or {}).get('self', {}).get('title') or p.get('names',[{}])[0].get('text') if p.get('names') else None,
                'node_title': p.get('_links',{}).get('self',{}).get('title'),
                'image_uuid': L['self']['href'].split('/images/')[1].split('?')[0] if 'self' in L else None,
                'image_of': L.get('generalNode',{}).get('title') or L.get('specificNode',{}).get('title'),
                'specific_node': L.get('specificNode',{}).get('title'),
                'general_node': L.get('generalNode',{}).get('title'),
                'contributor': L.get('contributor',{}).get('title'),
                'license': L.get('license',{}).get('href'),
                'attribution': img.get('attribution'),
                'sponsor': img.get('sponsor'),
                'vector': L.get('vectorFile',{}).get('href'),
                'raster': (L.get('rasterFiles') or [{}])[0].get('href'),
                'nodes': [n.get('title') for n in L.get('nodes',[])],
            }
            try:
                svg = get(rec['phylopic']['vector'], hdr={'Accept':'image/svg+xml'}).decode()
                rec['phylopic']['svg'] = svg
            except Exception as e: rec['phylopic']['svg_error'] = str(e)
        else:
            rec['phylopic'] = {'_error': p.get('_error') or 'no primaryImage', 'raw_keys': list(p.keys())}
    # --- Wikidata by WoRMS id or by taxon name
    if wid:
        where = f'?item wdt:P850 "{wid}".'
    else:
        where = f'?item wdt:P225 "{name}".'
    q = f'''SELECT ?item ?image ?len ?lenUnitLabel ?mass ?inat ?ebird ?fishbase ?gbif ?itis ?enwiki ?commonscat WHERE {{ {where}
      OPTIONAL{{?item wdt:P18 ?image}} OPTIONAL{{?item p:P2043 ?ls. ?ls psv:P2043 ?lv. ?lv wikibase:quantityAmount ?len; wikibase:quantityUnit ?lenUnit}}
      OPTIONAL{{?item wdt:P2067 ?mass}} OPTIONAL{{?item wdt:P3151 ?inat}} OPTIONAL{{?item wdt:P3444 ?ebird}} OPTIONAL{{?item wdt:P938 ?fishbase}}
      OPTIONAL{{?item wdt:P846 ?gbif}} OPTIONAL{{?item wdt:P815 ?itis}} OPTIONAL{{?item wdt:P373 ?commonscat}}
      OPTIONAL{{?enwiki schema:about ?item; schema:isPartOf <https://en.wikipedia.org/>}}
      SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }} }} LIMIT 3'''
    w = gj('https://query.wikidata.org/sparql?format=json&query=' + urllib.parse.quote(q))
    b = (w.get('results') or {}).get('bindings') or []
    rec['wikidata'] = [{k: v['value'] for k, v in row.items()} for row in b]
    wd = rec['wikidata'][0] if rec['wikidata'] else {}
    # --- Wikipedia summary
    if wd.get('enwiki'):
        title = wd['enwiki'].split('/wiki/')[1]
        s = gj('https://en.wikipedia.org/api/rest_v1/page/summary/' + title)
        rec['wikipedia'] = {k: s.get(k) for k in ['title','description','extract','thumbnail','originalimage','revision','timestamp']}
        rec['wikipedia']['url'] = wd['enwiki']
    # --- Commons extmetadata for P18
    if wd.get('image'):
        fn = urllib.parse.unquote(wd['image'].split('Special:FilePath/')[1])
        c = gj('https://commons.wikimedia.org/w/api.php?action=query&titles=' + urllib.parse.quote('File:' + fn) + '&prop=imageinfo&iiprop=extmetadata|url&iiurlwidth=900&format=json')
        for pg in (c.get('query') or {}).get('pages', {}).values():
            ii = (pg.get('imageinfo') or [{}])[0]; em = ii.get('extmetadata', {})
            rec['commons'] = {'file': fn, 'thumb': ii.get('thumburl'), 'descurl': ii.get('descriptionurl'),
                              **{k: re.sub('<[^>]+>', '', em.get(k, {}).get('value') or '')[:200] for k in ['LicenseShortName','LicenseUrl','Artist','Credit','AttributionRequired','Copyrighted','DateTimeOriginal']}}
    # --- iNaturalist
    i = gj('https://api.inaturalist.org/v1/taxa?q=' + urllib.parse.quote(name) + '&per_page=3')
    res = [r for r in (i.get('results') or []) if r.get('name') == name] or (i.get('results') or [])
    if res:
        r = res[0]
        full = gj(f"https://api.inaturalist.org/v1/taxa/{r['id']}")
        fr = (full.get('results') or [r])[0]
        dp = fr.get('default_photo') or {}
        rec['inat'] = {'id': fr.get('id'), 'name': fr.get('name'), 'common': fr.get('preferred_common_name'), 'rank': fr.get('rank'),
                       'n_obs': fr.get('observations_count'), 'wikipedia_summary': re.sub('<[^>]+>', '', fr.get('wikipedia_summary') or '')[:600],
                       'default_photo': {k: dp.get(k) for k in ['id','license_code','attribution','medium_url','square_url','original_dimensions']},
                       'taxon_photos': [{'license': tp['photo'].get('license_code'), 'attribution': tp['photo'].get('attribution'), 'medium_url': tp['photo'].get('medium_url')} for tp in (fr.get('taxon_photos') or [])[:8]],
                       'conservation_status': (fr.get('conservation_status') or {}).get('status_name')}
    # --- GBIF licence-filtered occurrence images
    g = gj('https://api.gbif.org/v1/species/match?name=' + urllib.parse.quote(name))
    if g.get('usageKey'):
        rec['gbif_key'] = g['usageKey']
        o = gj(f"https://api.gbif.org/v1/occurrence/search?taxonKey={g['usageKey']}&mediaType=StillImage&license=CC0_1_0&license=CC_BY_4_0&limit=4")
        rec['gbif_media'] = {'count': o.get('count'), 'items': [{'license': m.get('license'), 'creator': m.get('rightsHolder') or m.get('creator'), 'url': m.get('identifier'), 'dataset': occ.get('datasetName') or occ.get('datasetKey')} for occ in (o.get('results') or []) for m in (occ.get('media') or [])[:1]]}
    out[label] = rec
    print(label, '| worms', wid, '| phylopic', (rec.get('phylopic') or {}).get('general_node'), (rec.get('phylopic') or {}).get('license','')[-12:], '| size', [(s.get('value'), s.get('Unit'), s.get('Type')) for s in rec.get('worms_body_size', [])][:2], '| wiki', bool(rec.get('wikipedia')), '| commons', (rec.get('commons') or {}).get('LicenseShortName'), '| inat', (rec.get('inat') or {}).get('default_photo',{}).get('license_code'), '| gbif', (rec.get('gbif_media') or {}).get('count'), file=sys.stderr)
    time.sleep(0.6)
json.dump(out, open('species_media_sample.json', 'w'), indent=1)
print('wrote', len(out), file=sys.stderr)
