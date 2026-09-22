with open(".github/workflows/build-embedded-base.yml", "r", encoding="utf-8") as f:
    content = f.read()

old_git_conf = 'git config --global url."https://x-access-token:${OPENHD_SUBMODULE_TOKEN}@github.com/OpenHD/".insteadOf "https://github.com/OpenHD/"'
new_git_conf = 'git config --global url."https://x-access-token:${OPENHD_SUBMODULE_TOKEN}@github.com/OpenHD/".insteadOf "https://github.com/OpenHD/"\n            git config --global url."https://x-access-token:${OPENHD_SUBMODULE_TOKEN}@github.com/OpenHD-Technologies/".insteadOf "https://github.com/OpenHD-Technologies/"'

content = content.replace(old_git_conf, new_git_conf)

with open(".github/workflows/build-embedded-base.yml", "w", encoding="utf-8", newline="\n") as f:
    f.write(content)
print("Patched build-embedded-base.yml")
