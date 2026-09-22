import re

with open('.github/workflows/update-image.yml', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace(r'\n          - luckfox-update', '\n          - luckfox-update')
text = text.replace(r'\n  LUCKFOX_COMPONENT_BASE_URL: https://dl.cloudsmith.io/public/openhd/dev-release/raw/files\n  LUCKFOX_SOURCE_RUN_ID: "0"', '')

text = re.sub(
    r'(X21_SOURCE_RUN_ID: "34479273960")',
    r'\1\n  LUCKFOX_COMPONENT_BASE_URL: https://dl.cloudsmith.io/public/openhd/dev-release/raw/files\n  LUCKFOX_SOURCE_RUN_ID: "0"',
    text
)

with open('luckfox_job.txt', 'r', encoding='utf-8') as f:
    job = f.read()

text = re.sub(
    r'(  openhd-hardware-x20:\n\s*name: openhd-hardware-x20)',
    job.replace('\\', '\\\\') + r'\n\1',
    text
)

with open('.github/workflows/update-image.yml', 'w', encoding='utf-8', newline='\n') as f:
    f.write(text)
