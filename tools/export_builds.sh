#!/usr/bin/env bash
# Export Windows, macOS, and Linux playtest builds into builds/.
# Requires Godot 4.7.1 editor + matching export templates.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
TEMPLATES_DIR="${HOME}/Library/Application Support/Godot/export_templates/4.7.1.stable"
TEMPLATES_TPZ_URL="https://github.com/godotengine/godot/releases/download/4.7.1-stable/Godot_v4.7.1-stable_export_templates.tpz"

die() { echo "error: $*" >&2; exit 1; }

[[ -x "$GODOT" ]] || die "Godot not found at $GODOT (set GODOT=...)"

install_templates() {
	if [[ -f "$TEMPLATES_DIR/version.txt" ]]; then
		echo "Export templates already installed: $TEMPLATES_DIR"
		return
	fi
	echo "Downloading Godot 4.7.1 export templates (~1.2 GB)..."
	local tmp
	tmp="$(mktemp -d)"
	curl -L --progress-bar -o "$tmp/templates.tpz" "$TEMPLATES_TPZ_URL"
	mkdir -p "$TEMPLATES_DIR"
	# .tpz is a zip whose top folder is "templates/"
	unzip -q "$tmp/templates.tpz" -d "$tmp"
	cp -R "$tmp/templates/"* "$TEMPLATES_DIR/"
	rm -rf "$tmp"
	echo "Installed templates to $TEMPLATES_DIR"
}

export_one() {
	local preset="$1"
	local out="$2"
	mkdir -p "$(dirname "$ROOT/$out")"
	echo "→ Exporting $preset → $out"
	"$GODOT" --headless --path "$ROOT" --export-release "$preset" "$out"
}

main() {
	cd "$ROOT"
	install_templates

	rm -rf builds/windows builds/linux builds/macos
	mkdir -p builds/windows builds/macos builds/linux

	export_one "Windows Desktop" "builds/windows/MagicLogisticsInit.exe"
	export_one "macOS" "builds/macos/MagicLogisticsInit.zip"
	export_one "Linux" "builds/linux/MagicLogisticsInit.x86_64"

	(
		cd "$ROOT/builds"
		rm -f FantasyConvoy-windows.zip FantasyConvoy-linux.zip FantasyConvoy-macos.zip
		zip -qr FantasyConvoy-windows.zip windows
		zip -qr FantasyConvoy-linux.zip linux
		cp macos/MagicLogisticsInit.zip FantasyConvoy-macos.zip
	)

	echo
	echo "Done. Send these:"
	ls -lh "$ROOT/builds"/FantasyConvoy-*.zip
	echo
	echo "Notes for friends:"
	echo "  Windows: unzip, run MagicLogisticsInit.exe"
	echo "  Linux:   unzip, chmod +x MagicLogisticsInit.x86_64, run it"
	echo "  macOS:   unzip; if Gatekeeper blocks, right-click the app → Open once"
}

main "$@"
