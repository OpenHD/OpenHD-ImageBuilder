import urllib.request
import json
import time

url = "https://api.github.com/repos/OpenHD/OpenHD-ImageBuilder/actions/runs?per_page=15"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla"})
try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        runs = [r for r in data["workflow_runs"] if r["name"] == "Build Embedded Base Images"][:6]
        
        for r in runs:
            print(f"{r['id']} ({r['status']}): {r['conclusion']}")
except Exception as e:
    print(e)
