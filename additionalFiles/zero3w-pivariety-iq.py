import json
import sys
from pathlib import Path

source, destination = map(Path, sys.argv[1:])
tuning = json.loads(source.read_text())
tuning["sensor_calib"]["CISMinFps"] = 60
for scene in tuning["main_scene"]:
    for sub_scene in scene["sub_scene"]:
        isp = sub_scene["scene_isp21"]
        ae = isp["ae_calib"]
        ae["CommCtrl"]["AecFrameRateMode"].update(isFpsFix=1, FpsValue=60)
        linear = ae["LinearAeCtrl"]
        linear["InitExp"]["InitTimeValue"] = 0.008
        linear["Route"]["TimeDot"] = [0.0005, 0.003, 0.008, 0.012, 0.015, 0.015]
        linear["Route"]["GainDot"] = [1, 1, 1, 2, 4, 8]
        linear["DySetpoint"]["DySetpoint"] = [55, 53, 51, 49, 47, 45]
        gamma = isp["agamma_calib_v10"]["GammaTuningPara"]
        gamma["Gamma_curve"] = [
            round(4095 * (max(0, min(4095, value)) / 4095) ** 0.55)
            for value in gamma["Gamma_curve"]
        ]
destination.write_text(json.dumps(tuning) + "\n")
