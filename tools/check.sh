#!/usr/bin/env bash
# Type-checks and lints all Luau code.
# Needs rojo, luau-lsp and selene on PATH (see rokit.toml), plus the Roblox type
# definitions: tools/check.sh downloads them to build/ on first run.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
DEFS=build/globalTypes.d.luau
if [ ! -f "$DEFS" ]; then
	curl -sSL -o "$DEFS" https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.None.d.luau
fi
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions=@roblox="$DEFS" \
	--ignore="**/Lib/ProfileStore.luau" --no-strict-dm-types src "$@"
echo "luau-lsp: OK"
