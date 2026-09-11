"""Convert the probe into taxa_media.sample.json, the sidecar shape of the plan's Appendix A (URLs, not bytes)."""
import json, datetime
cast = json.load(open('cast_data.json')); sil = json.load(open('silhouettes.json')); cands = json.load(open('cand/cands.json'))
photos = json.load(open('photos2.json'))
src_by_key = {l.split('|')[0]: l.split('|')[1] for l in open('photos.txt').read().strip().splitlines()}
src_by_key.update({'sardine': cands[9]['thumb'], 'sardine_plate': cands[22]['thumb'], 'krill': cands[33]['thumb'],
                   'anchovy': src_by_key['anchovy_pd'], 'hake': src_by_key['hake_pd'], 'shearwater': src_by_key['shearwater_commons'], 'sebastes': src_by_key['sebastes_pd']})
LIC = {'https://creativecommons.org/publicdomain/zero/1.0/': 'CC0 1.0', 'https://creativecommons.org/publicdomain/mark/1.0/': 'Public Domain Mark',
       'https://creativecommons.org/licenses/by/3.0/': 'CC BY 3.0', 'https://creativecommons.org/licenses/by-sa/3.0/': 'CC BY-SA 3.0'}
def photo(k, kind):
    if not k: return None
    p = photos[k]; slug = k
    return {'source': 'noaa_iis' if kind == 'plate' else 'commons' if 'Commons' in p['via'] else 'inat', 'id': k, 'page': p['page'], 'url': src_by_key.get(k) or p['page'],
            'license': p['license'], 'credit': p['by'], 'via': p['via'], 'shows': p['shows'], 'curated': True, 'cached': None, 'focal': [0.5, 0.5]}
out = {'schema_version': '1.0', 'release': 'v2026.09.06', 'fetched': datetime.date.today().isoformat(), 'note': 'FIXTURE from the 2026-09-11 probe: ten cast taxa; cached paths are null (use url)',
       'policy': {'allow': ['CC0', 'PD', 'PDM', 'CC BY', 'CC BY-SA', 'CC BY-NC', 'CC BY-NC-SA'], 'deny': ['ND', 'ARR', 'unknown']}, 'taxa': {},
       'refs': {'265': 'Matarese, A.C., A.W. Kendall, D.M. Blood and M.V. Vinter. 1989. Laboratory guide to early life history stages of Northeast Pacific fishes. NOAA Tech. Rep. NMFS 80.',
                '6879': 'Kucas, S.T. 1986. Species profiles: life histories and environmental requirements of coastal fishes and invertebrates (Pacific southwest) - northern anchovy.',
                '31442': 'Moser, H.G. and E.H. Ahlstrom. 1996. Myctophidae: lanternfishes. In Moser (ed.) CalCOFI Atlas 33.'}}
STAGE = {'egg': 'egg', 'hatches': 'hatching', 'flexion': 'flexion', 'transforms': 'transformation'}
for c in cast:
    s = sil[c['sil']]
    out['taxa'][c['key']] = {
        'silhouette': {'source': 'phylopic', 'uuid': s['image_uuid'], 'url': 'https://www.phylopic.org/images/' + s['image_uuid'], 'svg_url': f"https://images.phylopic.org/images/{s['image_uuid']}/vector.svg", 'license': LIC.get(s['license'], s['license']),
                       'license_url': s['license'], 'credit': s['contributor'], 'taxon_shown': s['image_of'], 'node': s['node'], 'resolved_by': s.get('resolved_by') or 'name', 'steps_up': s.get('steps_up') or 0,
                       'aspect': s['aspect'], 'length_axis': c['sil_axis']},
        'photo': photo(c['photo'], 'photo'), 'drawing': photo(c['drawing'], 'drawing'), 'plate': photo(c['plate'], 'plate'),
        'size': ({'m': c['size']['cm'] / 100, 'kind': c['size']['kind'], 'source': c['size']['src'], 'url': c['size']['url']} if c['size'] else None),
        'early': [{'stage': STAGE.get(e['label'], e['label']), 'mm': e['mm'], 'source': e['src']} for e in c['early']],
        'text': {'source': 'wikipedia', 'title': c['blurb']['title'], 'url': c['blurb']['url'], 'revision': c['blurb']['revision'], 'timestamp': c['blurb']['timestamp'], 'license': 'CC BY-SA 4.0',
                 'about': 'genus' if c['blurb']['about_genus'] else 'taxon', 'extract': c['blurb']['full'], 'lead': c['blurb']['text']},
        'links': c['links']}
out['coverage'] = {'taxa': len(out['taxa']), **{k: sum(1 for t in out['taxa'].values() if t.get(k)) for k in ['silhouette', 'photo', 'drawing', 'plate', 'size', 'text']}}
json.dump(out, open('taxa_media.sample.json', 'w'), ensure_ascii=False, indent=1); print(out['coverage'])
