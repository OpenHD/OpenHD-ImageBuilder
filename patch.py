with open('.github/workflows/update-image.yml', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('- experimental\n          - x21-update', '- experimental\n          - embedded-sdk\n          - x21-update')

new_job = """
  # =========================================================================
  # 5. Embedded SDKs (Buildroot / Cross-compiled)
  # =========================================================================
  embedded-sdk-images:
    name: embedded-sdk-${{ matrix.target }}
    if: github.event_name != 'workflow_dispatch' || inputs.target == 'all' || inputs.target == 'embedded-sdk'
    runs-on: ubuntu-24.04
    strategy:
      fail-fast: false
      matrix:
        target:
          - orqa
          - luckfox
          - lyra
          - aura
          - rv1106
          - rv1103
    steps:
      - uses: actions/checkout@v4
      - name: Free runner disk space
        run: |
          sudo rm -rf /usr/local/lib/android /usr/share/dotnet /opt/ghc /usr/local/.ghcup
          sudo apt-get purge -y '^llvm-.*' 'php.*' '^mongodb-.*' '^mysql-.*' \\
            azure-cli google-chrome-stable firefox powershell \\
            microsoft-edge-stable mono-devel || true
          sudo apt-get autoremove -y
          sudo apt-get clean
          df -h "$GITHUB_WORKSPACE"
      - name: Prepare and build SDK
        run: |
          echo "DT=$(date -u +'%Y-%m-%d-%H-%M-%S')" >> "$GITHUB_ENV"
          touch additionalFiles/dev-build
          chmod +x scripts/sdk_builder.sh
          # The sdk_builder.sh handles dependency installation and buildroot/SDK process
          ./scripts/sdk_builder.sh "${{ matrix.target }}"
      - name: Upload Artifact
        uses: actions/upload-artifact@v4
        with:
          name: embedded-sdk-${{ matrix.target }}-${{ env.DT }}
          path: |
            buildroot/output/image/*
            buildroot/output/images/*
          if-no-files-found: warn
"""

content += new_job

with open('.github/workflows/update-image.yml', 'w', encoding='utf-8', newline='\n') as f:
    f.write(content)
print('Done writing.')
