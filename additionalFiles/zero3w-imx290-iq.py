import json
import sys
from pathlib import Path


iqfiles = Path("/etc/iqfiles")
reference = iqfiles / "imx219_RADXA-CAMERA-8M_default.json"
profile = json.loads(reference.read_text())
source = json.loads(Path(sys.argv[1]).read_text())
imx290 = source["main_scene"][0]["sub_scene"][0]["scene_isp30"]
profile["sensor_calib"] = source["sensor_calib"]
for scene in profile["main_scene"]:
    for sub_scene in scene["sub_scene"]:
        isp = sub_scene["scene_isp21"]
        for key in ("ae_calib", "ablc_calib", "ccm_calib"):
            if key in imx290:
                isp[key] = imx290[key]
        isp["lsc_v2"]["common"]["enable"] = 0
        isp["ae_calib"]["CommCtrl"]["AecFrameRateMode"].update(isFpsFix=1, FpsValue=30)

destination = iqfiles / "imx290_imx290_default.json"
destination.write_text(json.dumps(profile) + "\n")
