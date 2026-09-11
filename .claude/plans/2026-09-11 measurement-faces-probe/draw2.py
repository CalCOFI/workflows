import json, re
from rdkit import Chem
from rdkit.Chem.Draw import rdMolDraw2D
ids = {'chlorophyll_a':18230,'pheophytin_a':44898,'nitrate':17632,'ammonium':28938,'ammonia':16134,'dioxygen':15379,'hydrogencarbonate':17544,
       'carbonate':41609,'carbon_dioxide':16526,'orthosilicic_acid':26675,'phosphate':18367,'nitrite':16301,'sulfate':16189}
meta = {}
for k, i in ids.items():
    m = Chem.MolFromMolFile(f'mol/{i}.mol', sanitize=False, removeHs=False)
    try: Chem.SanitizeMol(m)
    except Exception as e: m.UpdatePropertyCache(strict=False); print('nosanitize', k, e)
    n = m.GetNumHeavyAtoms()
    big = n > 20
    W, H = (600, 440) if big else (220, 180)
    for fmt in ('svg','png'):
        d = rdMolDraw2D.MolDraw2DSVG(W, H) if fmt == 'svg' else rdMolDraw2D.MolDraw2DCairo(W, H)
        o = d.drawOptions(); o.useBWAtomPalette(); o.clearBackground = (fmt == 'png')
        o.bondLineWidth = 1.5 if big else 2.2; o.padding = 0.06; o.minFontSize = 12 if big else 16; o.maxFontSize = 26
        o.addStereoAnnotation = False
        d.DrawMolecule(m); d.FinishDrawing()
        t = d.GetDrawingText()
        if fmt == 'svg':
            t = re.sub(r'<\?xml[^>]*\?>\s*', '', t).replace('#000000', 'currentColor').replace('#FFFFFF','none')
            open(f'svg/{k}.svg','w').write(t); meta[k] = {'bytes': len(t), 'heavy': n}
        else: open(f'png/{k}.png','wb').write(t)
print(meta)
