#!/usr/bin/env python3
"""Split an ERDDAP datasets.xml into one file per <dataset> block.

Used to benchmark PRODUCTION dataset definitions verbatim: rather than
hand-writing bench blocks that drift from what is actually served, extract the
live blocks and feed them straight to scripts/bench_download.sh. The bench
container mounts the live dataset tree read-only at the same /datasets path the
production ERDDAP uses, so fileDir/sourceUrl resolve unchanged.

Blocks are written as <prefix><datasetID>.xml so the cell name (== datasetID ==
block filename) convention the bench scripts rely on still holds.

Usage:
  extract_erddap_blocks.py <datasets.xml> <out-dir> [--prefix live_] [--only id,id]
"""
import re
import sys
import pathlib
import xml.etree.ElementTree as ET

if len(sys.argv) < 3:
    sys.exit(__doc__)

src, out_dir = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
args = sys.argv[3:]


def opt(name, default=""):
    return args[args.index(name) + 1] if name in args else default


prefix = opt("--prefix", "live_")
only = {s for s in opt("--only").split(",") if s}
out_dir.mkdir(parents=True, exist_ok=True)

text = src.read_text(encoding="utf-8", errors="replace")

# Slice on raw text rather than parsing the whole file: datasets.xml often carries
# XML comments and vendor quirks between blocks, and we want each block byte-identical
# to what ERDDAP loads, not a re-serialized approximation.
pattern = re.compile(r'<dataset\b[^>]*datasetID="([^"]+)"[^>]*>.*?</dataset>', re.S)

written = []
for m in pattern.finditer(text):
    did = m.group(1)
    if only and did not in only:
        continue
    block = m.group(0)
    try:
        ET.fromstring(block)  # refuse to emit a block ERDDAP could not parse
    except ET.ParseError as e:
        print(f"  SKIP {did}: not well-formed ({e})", file=sys.stderr)
        continue
    # bench cells are keyed by datasetID; rewrite it so the extracted copy cannot
    # collide with the live dataset if both ever load in one ERDDAP
    newid = f"{prefix}{did}"
    block = block.replace(f'datasetID="{did}"', f'datasetID="{newid}"', 1)
    dest = out_dir / f"{newid}.xml"
    dest.write_text(block, encoding="utf-8")
    active = "active=\"false\"" not in block
    written.append((newid, len(block), active))
    print(f"  wrote {dest.name}  ({len(block)} bytes, active={active})")

if not written:
    sys.exit("no <dataset> blocks matched")
print(f"\n{len(written)} block(s) -> {out_dir}")
