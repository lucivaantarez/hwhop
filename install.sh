#!/data/data/com.termux/files/usr/bin/bash
# hwhop installer — registers the self-updating `hop` command
set -u
REPO_RAW="https://raw.githubusercontent.com/lucivaantarez/hwhop/main"

echo "  installing hwhop …"

# deps
command -v curl >/dev/null 2>&1 || pkg install -y curl
command -v am   >/dev/null 2>&1 || pkg install -y termux-tools >/dev/null 2>&1 || true

# storage -> Download folder
if [ ! -d "$HOME/storage" ]; then
  echo "  requesting storage permission (tap Allow) …"
  termux-setup-storage || true
  sleep 2
fi
DLDIR="$HOME/storage/downloads"
[ -d "$DLDIR" ] || DLDIR="$HOME"
mkdir -p "$HOME/.hop"
printf '%s' "$DLDIR" > "$HOME/.hop/dldir"

# write the self-updating launcher to $PREFIX/bin/hop
echo "#!$PREFIX/bin/bash" > "$PREFIX/bin/hop"
cat >> "$PREFIX/bin/hop" <<'LAUNCHER'
# hop — curls latest from github, updates if changed, runs immediately
REPO_RAW="https://raw.githubusercontent.com/lucivaantarez/hwhop/main"
DLDIR="$(cat "$HOME/.hop/dldir" 2>/dev/null)"
[ -d "$DLDIR" ] || DLDIR="$HOME/storage/downloads"
[ -d "$DLDIR" ] || DLDIR="$HOME"
SCRIPT="$DLDIR/hop.sh"
TMP="$(mktemp)"
NET=fail; UPDATED=0; OLDV=none; NEWV="?"
if curl -fsSL "$REPO_RAW/hop.sh" -o "$TMP" 2>/dev/null && [ -s "$TMP" ]; then
  NET=ok
  NEWV="$(grep -m1 '^VERSION=' "$TMP" | cut -d'"' -f2)"
  [ -f "$SCRIPT" ] && OLDV="$(grep -m1 '^VERSION=' "$SCRIPT" | cut -d'"' -f2)"
  if [ ! -f "$SCRIPT" ] || ! cmp -s "$TMP" "$SCRIPT"; then cp "$TMP" "$SCRIPT"; UPDATED=1; fi
fi
rm -f "$TMP"
if [ ! -f "$SCRIPT" ]; then echo "hop: no local copy and github unreachable"; exit 1; fi
chmod +x "$SCRIPT" 2>/dev/null
exec env HOP_NET="$NET" HOP_UPDATED="$UPDATED" HOP_OLD_VER="$OLDV" HOP_NEW_VER="$NEWV" bash "$SCRIPT"
LAUNCHER
chmod +x "$PREFIX/bin/hop"

# pull the script now so the first run is instant
curl -fsSL "$REPO_RAW/hop.sh" -o "$DLDIR/hop.sh" 2>/dev/null && chmod +x "$DLDIR/hop.sh" 2>/dev/null

echo
echo "  done ✓   script saved to: $DLDIR/hop.sh"
echo "  just type:   hop"
echo
