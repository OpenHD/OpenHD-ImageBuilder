with open("scripts/sdk_builder.sh", "r", encoding="utf-8") as f:
    content = f.read()

main_logic = """
###############################################################################
# 4) Main logic: parse argument, or list and prompt if none
###############################################################################
if [[ -z "$1" ]]; then
  # No platform given. List available ones and let user choose:
  list_platforms

  read -rp "Enter a platform name to build (or press Ctrl+C to exit): " chosen_platform
  if [[ -z "$chosen_platform" ]]; then
    echo "No platform selected; exiting."
    exit 1
  fi
  # Now load config & build
  load_config "$chosen_platform"
  perform_build "$chosen_platform"

else
  # A specific platform was given as an argument
  platform="$1"
  load_config "$platform"
  perform_build "$platform"
fi
"""

if "# 4) Main logic" not in content:
    with open("scripts/sdk_builder.sh", "a", encoding="utf-8", newline="\n") as f:
        f.write(main_logic)
    print("Appended main logic")
