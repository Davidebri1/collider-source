#!/usr/bin/env python3
"""Print the text read from each screenshot (one JSON object per file).
Usage: ocr.py a.png [b.png ...]   (needs rapidocr-onnxruntime)"""
import json, sys
from rapidocr_onnxruntime import RapidOCR
eng = RapidOCR()
# A second, more permissive pass picks up lone large digits (statistics
# counts) that the default detector drops.
loose = RapidOCR(text_score=0.2, box_thresh=0.3)
for f in sys.argv[1:]:
    lines, boxes = [], []
    for e in (eng, loose):
        res, _ = e(f)
        for box, text, _score in (res or []):
            xs = [p[0] for p in box]; ys = [p[1] for p in box]
            pos = [text, round(sum(xs) / 4), round(sum(ys) / 4)]
            # Lines stay unique for readers that join them. Boxes keep every
            # painted instance so a chip can be clicked when the same word
            # also appears in the view row.
            if text not in lines:
                lines.append(text)
            if pos not in boxes:
                boxes.append(pos)
    print(json.dumps({"file": f, "lines": lines, "boxes": boxes}))
