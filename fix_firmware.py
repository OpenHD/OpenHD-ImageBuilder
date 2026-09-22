import re

with open('.github/workflows/update-image.yml', 'r', encoding='utf-8') as f:
    text = f.read()

# Replace luckfox firmware fetch
text = re.sub(
    r'for name in firmware.zip firmware.zip.sha256; do\n\s*curl --fail --location --retry 5 --retry-delay 3 \\\n\s*\"\$\{LUCKFOX_COMPONENT_BASE_URL\}/\$\{name\}\" -o \"luckfox-firmware-cache/\$\{name\}\"\n\s*done',
    'curl --fail --location --retry 5 --retry-delay 3 \\\n              "/openhd-luckfox-firmware.zip" -o "luckfox-firmware-cache/firmware.zip"\n            curl --fail --location --retry 5 --retry-delay 3 \\\n              "/openhd-luckfox-firmware.zip.sha256" -o "luckfox-firmware-cache/firmware.zip.sha256"',
    text
)

with open('.github/workflows/update-image.yml', 'w', encoding='utf-8', newline='\n') as f:
    f.write(text)
