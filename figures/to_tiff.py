"""to_tiff.py — PNG screenshots -> TIFF (LZW, RGB, 300 dpi), then re-open each TIFF with PIL and verify. Writes tiff_check.txt.
   python figures/to_tiff.py   (needs Pillow; tested with 13.0.0)"""
import pathlib, hashlib
from PIL import Image, __version__ as PILV

d = pathlib.Path(__file__).resolve().parent
lines = [f"Pillow {PILV}"]
ok = True
for png in sorted(d.glob("fig*.png")):
    tif = png.with_suffix(".tif")
    Image.open(png).convert("RGB").save(tif, compression="tiff_lzw", dpi=(300, 300))
    im = Image.open(tif)
    dpi = tuple(round(float(x)) for x in im.info.get("dpi", (0, 0)))
    comp = im.info.get("compression")
    good = im.mode == "RGB" and comp == "tiff_lzw" and dpi == (300, 300)
    ok &= good
    w, h = im.size
    lines.append(f"{tif.name}: {w}x{h} px, mode {im.mode}, compression {comp}, dpi {dpi}, "
                 f"print size {w/300*2.54:.1f} x {h/300*2.54:.1f} cm, sha256 {hashlib.sha256(tif.read_bytes()).hexdigest()[:16]} -> {'OK' if good else 'FAIL'}")
lines.append("ALL OK" if ok else "FAILURES")
(d / "tiff_check.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
print("\n".join(lines))
