"""Assemble the design-study page from the probed assets.

Reads the fetched material (release record, silhouettes, photos, WoRMS / FishBase sizes, Wikipedia
extracts) and injects one `window.DATA` object into the template. Nothing on the page is typed
by hand where a source supplied it.
"""
import json, re, datetime

rec    = json.load(open('cast_record.json'))          # the release's taxa.json, cast subset
sample = json.load(open('species_media_sample.json'))  # WoRMS / Wikidata / Wikipedia / iNat / GBIF probe
sil    = json.load(open('silhouettes.json'))
photos = json.load(open('photos2.json'))

# sizes and early-life lengths come from the probes above (WoRMS attributes ← FishBase; SeaLifeBase;
# FishBase EGGS + LARVAE, references 265 = Matarese et al. 1989, 6879 = Kucas 1986, 31442 = Moser & Ahlstrom 1996)
WORMS_ATTR = 'https://www.marinespecies.org/aphia.php?p=taxdetails&id={id}#attributes'
CAST_META = {
  'sardine':     dict(key='worms:217452', sil='sardine',  sil_axis='w', photo='sardine',    drawing='sardine_plate', plate='iis_sardine',
                      size=dict(cm=39.5, kind='max length (SL)', src='WoRMS attribute, checked, from FishBase', url=WORMS_ATTR.format(id=217452)),
                      early=[dict(label='egg', mm=[1.34, 2.05], src='FishBase EGGS'), dict(label='hatches', mm=[3.5, 3.8], src='FishBase LARVAE · Matarese et al. 1989'),
                             dict(label='flexion', mm=[9, 14], src='FishBase LARVAE'), dict(label='transforms', mm=[25, 35], src='FishBase LARVAE')],
                      links=dict(inat='https://www.inaturalist.org/taxa/55535', fishbase='https://www.fishbase.se/summary/1477', wikidata='https://www.wikidata.org/wiki/Q2069084')),
  'anchovy':     dict(key='worms:272286', sil='anchovy',  sil_axis='w', photo='anchovy', drawing=None, plate='iis_anchovy',
                      size=dict(cm=24.8, kind='max length (SL)', src='WoRMS attribute, checked, from FishBase', url=WORMS_ATTR.format(id=272286)),
                      early=[dict(label='hatches', mm=[2.5, 3.0], src='FishBase LARVAE · Kucas 1986'), dict(label='flexion', mm=[6.5, 13.5], src='FishBase LARVAE'), dict(label='transforms', mm=[35, 40], src='FishBase LARVAE')],
                      links=dict(inat='https://www.inaturalist.org/taxa/63770', fishbase='https://www.fishbase.se/summary/1664', wikidata='https://www.wikidata.org/wiki/Q989747')),
  'hake':        dict(key='worms:272458', sil='hake',     sil_axis='w', photo='hake', drawing='hake', plate='iis_hake',
                      size=dict(cm=91, kind='max length (TL)', src='WoRMS attribute, checked, from FishBase', url=WORMS_ATTR.format(id=272458)),
                      early=[dict(label='egg', mm=[1.07, 1.18], src='FishBase EGGS')],
                      links=dict(inat='https://www.inaturalist.org/taxa/105599', fishbase='https://www.fishbase.se/summary/326', wikidata='https://www.wikidata.org/wiki/Q919598')),
  'lanternfish': dict(key='worms:254363', sil='lanternfish', sil_axis='w', photo='lanternfish_nc', drawing=None, plate='iis_lanternfish',
                      size=dict(cm=13, kind='max length (TL)', src='WoRMS attribute, checked, from FishBase', url=WORMS_ATTR.format(id=254363)),
                      early=[dict(label='flexion', mm=[6.5, 8], src='FishBase LARVAE · Moser & Ahlstrom 1996'), dict(label='transforms', mm=[16, 19], src='FishBase LARVAE')],
                      links=dict(inat='https://www.inaturalist.org/taxa/231540', fishbase='https://www.fishbase.se/summary/2737', wikidata='https://www.wikidata.org/wiki/Q763418')),
  'krill':       dict(key='worms:237851', sil='krill',    sil_axis='w', photo='krill', drawing=None, plate=None,
                      size=dict(cm=2.2, kind='max length (TL)', src='SeaLifeBase (WoRMS carries no size)', url='https://www.sealifebase.se/summary/Euphausia-pacifica.html'),
                      early=[], links=dict(inat='https://www.inaturalist.org/taxa/201713', wikidata='https://www.wikidata.org/wiki/Q992625')),
  'squid':       dict(key='worms:574540', sil='squid',    sil_axis='h', photo='squid', drawing=None, plate=None,
                      size=dict(cm=19.2, kind='max mantle length', src='SeaLifeBase (WoRMS carries no size)', url='https://www.sealifebase.se/summary/Doryteuthis-opalescens.html'),
                      early=[], links=dict(inat='https://www.inaturalist.org/taxa/153981', wikidata='https://www.wikidata.org/wiki/Q13596607')),
  'shearwater':  dict(key='itis:1255050', sil='shearwater', sil_axis=None, photo='shearwater', drawing=None, plate=None,
                      size=None, early=[], links=dict(inat='https://www.inaturalist.org/taxa/502899', ebird='https://ebird.org/species/sooshe', macaulay='https://media.ebird.org/catalog?taxonCode=sooshe', wikidata='https://www.wikidata.org/wiki/Q27074603')),
  'dolphin':     dict(key='worms:137094', sil='dolphin',  sil_axis='w', photo='dolphin', drawing=None, plate=None,
                      size=dict(cm=235, kind='max length, adult', src='WoRMS attribute, checked', url=WORMS_ATTR.format(id=137094)),
                      early=[], links=dict(inat='https://www.inaturalist.org/taxa/41526', wikidata='https://www.wikidata.org/wiki/Q207114')),
  'chaetoceros': dict(key='worms:148985', sil='chaetoceros', sil_axis=None, photo='chaetoceros', drawing=None, plate=None,
                      size=None, early=[], links=dict(inat='https://www.inaturalist.org/taxa/123862', wikidata='https://www.wikidata.org/wiki/Q1761179')),
  'sebastes':    dict(key='worms:126175', sil='sebastes', sil_axis='w', photo='sebastes', drawing=None, plate=None,
                      size=None, early=[], links=dict(inat='https://www.inaturalist.org/taxa/47762', wikidata='https://www.wikidata.org/wiki/Q149077')),
}
ORDER = ['sardine', 'anchovy', 'hake', 'lanternfish', 'krill', 'squid', 'shearwater', 'dolphin', 'chaetoceros', 'sebastes']
RANK_ABBR = {'Kingdom': 'K', 'Phylum': 'P', 'Class': 'C', 'Order': 'O', 'Family': 'F', 'Genus': 'G', 'Species': 'sp'}

def sentences(text, n=2, max_chars=320):
    parts = re.split(r'(?<=[.!?])\s+(?=[A-Z])', (text or '').strip())
    out = []
    for p in parts:
        if len(' '.join(out + [p])) > max_chars and out: break
        out.append(p)
        if len(out) >= n: break
    return ' '.join(out)

cast = []
for k in ORDER:
    m = CAST_META[k]; r = rec[m['key']]; s = sample[k]
    lin = r['lineage'] or {}
    lineage = [dict(rank=rk, abbr=RANK_ABBR[rk], name=lin[key]) for rk, key in [('Kingdom', 'kingdom'), ('Phylum', 'phylum'), ('Class', 'class'), ('Order', 'order'), ('Family', 'family')] if lin.get(key)]
    if r['rank'] == 'Species':
        lineage.append(dict(rank='Genus', abbr='G', name=r['name'].split()[0], italic=True))
    ds = []
    for d in r['datasets']:
        ds.append(dict(k=d['k'], name=d['name'], color=d['color'], n_obs=d['n_obs'], n_samples=d['n_samples'], y0=d['y0'], y1=d['y1'], stages=d['stages'], peak=d['peak'], names_used=d['names_used']))
    wp = s.get('wikipedia') or {}
    wdl = (s.get('wikidata') or [{}])[0]
    sil_rec = sil[m['sil']]
    stand_in = sil_rec.get('image_of') and sil_rec['image_of'].lower() != r['name'].lower()
    cast.append(dict(
        id=k, key=r['key'], slug=r['slug'], name=r['name'], common=r['common'], rank=r['rank'], status=r['status'], checked=r['checked'],
        authority=(s.get('worms') or {}).get('authority'), italic=r['rank'] in ('Species', 'Genus'),
        lineage=lineage, ids=r['ids'], groups=r['groups'], notes=r['notes'], direct=r['direct'], rollup=r['rollup'], datasets=ds,
        worms_citation=(s.get('worms') or {}).get('citation'),
        sil=m['sil'], sil_axis=m['sil_axis'], sil_stand_in=bool(stand_in), photo=m['photo'], drawing=m['drawing'], plate=m['plate'],
        size=m['size'], early=m['early'], links=dict(m['links'], worms='https://www.marinespecies.org/aphia.php?p=taxdetails&id=%s' % r['ids']['worms_id'] if r['ids'].get('worms_id') else None,
                                                     itis='https://www.itis.gov/servlet/SingleRpt/SingleRpt?search_topic=TSN&search_value=%s' % r['ids']['itis_id'] if r['ids'].get('itis_id') else None,
                                                     gbif='https://www.gbif.org/species/%s' % (r['ids'].get('gbif_id') or wdl.get('gbif')) if (r['ids'].get('gbif_id') or wdl.get('gbif')) else None,
                                                     wikipedia=wp.get('url')),
        blurb=dict(text=sentences(wp.get('extract')), full=wp.get('extract'), title=wp.get('title'), url=wp.get('url'), revision=wp.get('revision'), timestamp=(wp.get('timestamp') or '')[:10],
                   about_genus=bool(wp.get('title') and r['rank'] == 'Species' and ' ' not in wp['title'].strip()) or (wp.get('description') or '').lower().startswith('genus') and r['rank'] == 'Species',
                   inat_summary=(s.get('inat') or {}).get('wikipedia_summary')),
        inat=dict(id=(s.get('inat') or {}).get('id'), n_obs=(s.get('inat') or {}).get('n_obs'), default_license=((s.get('inat') or {}).get('default_photo') or {}).get('license_code'),
                  photo_licenses=[p.get('license') for p in (s.get('inat') or {}).get('taxon_photos', [])]),
        gbif_media=dict(count=(s.get('gbif_media') or {}).get('count')),
        commons=dict(file=(s.get('commons') or {}).get('file'), license=(s.get('commons') or {}).get('LicenseShortName')),
    ))

# the silhouettes the page uses (cast + the human reference), trimmed to what the page reads
sil_out = {}
for k in set([c['sil'] for c in cast] + ['human']):
    v = sil[k]
    sil_out[k] = dict(vb=v['vb'], w=v['w'], h=v['h'], aspect=v['aspect'], inner=v['inner'], image_of=v['image_of'], node=v['node'], contributor=v['contributor'],
                      license=v['license'], uuid=v['image_uuid'], steps_up=v.get('steps_up'), url='https://www.phylopic.org/images/' + v['image_uuid'])

LIC_SHORT = {'https://creativecommons.org/publicdomain/zero/1.0/': 'CC0 1.0', 'https://creativecommons.org/publicdomain/mark/1.0/': 'Public Domain Mark',
             'https://creativecommons.org/licenses/by/3.0/': 'CC BY 3.0', 'https://creativecommons.org/licenses/by-sa/3.0/': 'CC BY-SA 3.0'}
for v in sil_out.values(): v['license_short'] = LIC_SHORT.get(v['license'], v['license'])

REFS = [  # the size ladder's reference objects — in the real build a size_reference.csv with these sources
  dict(k='hair',    label='a human hair',      m=7.0e-5, note='≈ 70 µm across'),
  dict(k='mesh',    label='bongo-net mesh',    m=5.05e-4, note='505 µm, the CalCOFI standard mesh'),
  dict(k='quarter', label='a US quarter',      m=0.02426, note='24.26 mm across (US Mint)'),
  dict(k='ring',    label='bongo-net ring',    m=0.71,   note='71 cm mouth diameter'),
  dict(k='person',  label='a person',          m=1.70,   note='1.7 m tall'),
  dict(k='ship',    label='R/V Reuben Lasker', m=63.8,   note='63.8 m, NOAA’s CalCOFI ship'),
]

data = dict(built=datetime.date.today().isoformat(), release='v2026.09.06', cast=cast, sil=sil_out, photos=photos, refs=REFS)
tpl = open('species_faces.template.html').read()
html = tpl.replace('/*__DATA__*/', 'window.DATA = ' + json.dumps(data, ensure_ascii=False) + ';')
open('species_faces.html', 'w').write(html)
print('cast', [c['id'] for c in cast]); print('html KB', round(len(html.encode()) / 1024))
for c in cast:
    print(' ', c['id'], '| blurb:', (c['blurb']['text'] or '')[:70], '| about_genus', c['blurb']['about_genus'], '| stand_in', c['sil_stand_in'], sil_out[c['sil']]['image_of'])

json.dump(cast, open("cast_data.json", "w"), ensure_ascii=False, indent=1)
