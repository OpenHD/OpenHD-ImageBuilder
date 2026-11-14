import json
import sys
from math import log10
from pathlib import Path


reference = Path("/etc/iqfiles/imx219_RADXA-CAMERA-8M_default.json")
profile = json.loads(reference.read_text())
source = json.loads(Path(sys.argv[1]).read_text())
imx290 = source["main_scene"][0]["sub_scene"][0]["scene_isp30"]
sensor = profile["sensor_calib"] = source["sensor_calib"]
# The driver uses 0.3 dB analogue gain steps, with code zero at unity.
gain_range = []
gains = (1, 1.5, 2, 3, 4, 6, 8, 12)
for lo, hi in zip(gains, gains[1:]):
    first = 20 * log10(lo) / 0.3
    last = 20 * log10(hi) / 0.3
    slope = (last - first) / (hi - lo)
    gain_range.extend((lo, hi, slope, slope * lo - first, 1, round(first), round(last)))
sensor["Gain2Reg"].update(GainRange=gain_range, GainRange_len=len(gain_range))
sensor["CISGainSet"]["CISAgainRange"]["Max"] = 12
sensor["CISGainSet"]["CISDgainRange"]["Max"] = 1
for scene in profile["main_scene"]:
    for sub_scene in scene["sub_scene"]:
        isp = sub_scene["scene_isp21"]
        for key in ("ae_calib", "ablc_calib", "ccm_calib"):
            if key in imx290:
                isp[key] = imx290[key]
        isp["lsc_v2"]["common"]["enable"] = 0
        gamma = isp["agamma_calib_v10"]["GammaTuningPara"]
        gamma["Gamma_curve"] = [
            round(4095 * (max(0, min(4095, value)) / 4095) ** 0.55)
            for value in gamma["Gamma_curve"]
        ]
destination = Path("/usr/share/openhd/iq-profiles/imx290")
destination.mkdir(parents=True, exist_ok=True)
for fps in (30, 60, 120):
    sensor["CISMinFps"] = fps
    for scene in profile["main_scene"]:
        for sub_scene in scene["sub_scene"]:
            ae = sub_scene["scene_isp21"]["ae_calib"]["CommCtrl"]
            ae["AecFrameRateMode"].update(isFpsFix=1, FpsValue=fps)
            if fps == 120:
                ae["AecAntiFlicker"]["enable"] = 0
    (destination / f"imx290-{fps}.json").write_text(json.dumps(profile) + "\n")
