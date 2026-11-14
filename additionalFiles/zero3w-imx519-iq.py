import json
import sys
from pathlib import Path


reference = Path('/etc/iqfiles/imx219_RADXA-CAMERA-8M_default.json')
profile = json.loads(reference.read_text())
imx708 = json.loads(Path(sys.argv[1]).read_text())
gamma = imx708['main_scene'][0]['sub_scene'][0]['scene_isp21']['agamma_calib_v10']

# The Sony analogue gain register is 1024 * (1 - 1 / gain).
# RKAIQ 5 represents it as a sequence of linear ranges.
gain_ranges = []
gain_breakpoints = (1, 1.5, 2, 3, 4, 6, 8, 12, 16)
for lo, hi in zip(gain_breakpoints, gain_breakpoints[1:]):
    first = 1024 * (1 - 1 / lo)
    last = 1024 * (1 - 1 / hi)
    slope = (last - first) / (hi - lo)
    gain_ranges.extend((lo, hi, slope, slope * lo - first, 1, round(first), round(last)))

sensor = profile['sensor_calib']
sensor['resolution'] = {'width': 4656, 'height': 3496}
sensor['Gain2Reg'].update(GainMode='EXPGAIN_MODE_LINEAR', GainRange=gain_ranges,
                         GainRange_len=len(gain_ranges))
sensor['CISGainSet']['CISAgainRange']['Max'] = 16
sensor['CISTimeSet']['Linear'].update(CISTimeRegMin=20, CISLinTimeRegMaxFac={'fCoeff': [1, 32]})

destination = Path('/usr/share/openhd/iq-profiles/imx519')
destination.mkdir(parents=True, exist_ok=True)
for fps in (30, 60, 120):
    sensor['CISMinFps'] = fps
    for scene in profile['main_scene']:
        for sub_scene in scene['sub_scene']:
            isp = sub_scene['scene_isp21']
            isp['lsc_v2']['common']['enable'] = 0
            isp['agamma_calib_v10'] = gamma
            ae = isp['ae_calib']
            ae['LinearAeCtrl']['StrategyMode'] = 'AECV2_STRATEGY_MODE_HIGHLIGHT_PRIOR'
            ae['CommCtrl']['AecFrameRateMode'].update(isFpsFix=1, FpsValue=fps)
            if fps == 120:
                ae['CommCtrl']['AecAntiFlicker']['enable'] = 0
    (destination / f'imx519-{fps}.json').write_text(json.dumps(profile, indent=2) + '\n')
