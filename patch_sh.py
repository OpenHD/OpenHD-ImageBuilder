with open("scripts/sdk_builder.sh", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace('$TYPE_1', '${TYPE_1:-}')
content = content.replace('$TYPE_2', '${TYPE_2:-}')
content = content.replace('$TYPE_3', '${TYPE_3:-}')

with open("scripts/sdk_builder.sh", "w", encoding="utf-8", newline="\n") as f:
    f.write(content)
