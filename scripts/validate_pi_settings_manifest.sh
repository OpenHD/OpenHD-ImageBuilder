#!/usr/bin/env bash
set -euo pipefail
image="${1:?Pi image is required}"
test -s "$image"
manifest_dir=$(mktemp -d)
manifest="$manifest_dir/settings-manifest.json"
trap 'rm -f "$manifest"; rmdir "$manifest_dir"' EXIT
offset=$(python3 -c 'import sys,struct; m=open(sys.argv[1],"rb").read(512); assert m[510:]==b"\x55\xaa"; print(struct.unpack_from("<I",m,454)[0]*512)' "$image")
mcopy -D o -i "$image@@$offset" ::/openhd/settings-manifest.json "$manifest" </dev/null
python3 - "$manifest" <<'PY'
import json,sys
with open(sys.argv[1]) as f: manifest=json.load(f)
assert manifest['_settingsContract']['version']==1
assert len(manifest['_settingsContract']['catalogHash'])==64
assert isinstance(manifest['platforms'],list) and manifest['platforms']
assert isinstance(manifest['initialFields'],list)
print('Pi boot settings manifest validated; platforms:',len(manifest['platforms']))
PY
