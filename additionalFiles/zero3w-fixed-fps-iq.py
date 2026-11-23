#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("source", type=Path)
parser.add_argument("destination", type=Path)
parser.add_argument("fps", type=int)
parser.add_argument("--imx415-binned", action="store_true")
args = parser.parse_args()

profile = json.loads(args.source.read_text())
for scene in profile["main_scene"]:
    for sub_scene in scene["sub_scene"]:
        isp = sub_scene["scene_isp21"]
        isp["ae_calib"]["CommCtrl"]["AecFrameRateMode"].update(
            isFpsFix=1, FpsValue=args.fps
        )
        if args.imx415_binned:
            # The reference shading table is calibrated for full-resolution readout.
            isp["lsc_v2"]["common"]["enable"] = 0

args.destination.write_text(json.dumps(profile, indent=2) + "\n")
