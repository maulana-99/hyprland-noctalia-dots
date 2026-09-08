#!/usr/bin/env bash
# ============================================================
#  install.sh — deploy dotfiles Hyprland + Noctalia
#  Setup: Hyprland (Lua config) + Noctalia v5 + kitty + starship
#  Cara pakai:  ./install.sh [--link]
#    default      = salin (copy) config, file lama di-backup dulu
#    --link       = pakai symlink biar perubahan di repo langsung kebawa
# ============================================================
set -euo pipefail

DOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="copy"
[[ "${1:-}" == "--link" ]] && MODE="link"

# Warna output
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✔${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
fail() { echo -e "${RED}✘${NC} $1"; exit 1; }

# ---------- Cek prasyarat ----------
command -v hyprctl      >/dev/null 2>&1 || fail "Hyprland belum terpasang (perlu compositor Hyprland)."
command -v noctalia     >/dev/null 2>&1 || warn "Noctalia belum ketemu di PATH — pastikan sudah install Noctalia v5."
command -v kitty        >/dev/null 2>&1 || warn "kitty belum terpasang."
command -v flameshot    >/dev/null 2>&1 || warn "flameshot belum terpasang (dipakai screenshot)."
command -v wofi         >/dev/null 2>&1 || warn "wofi belum terpasang (dipakai popup cheatsheet)."

# ---------- Folder tujuan ----------
CFG="$HOME/.config"
WPDIR="$HOME/Pictures/wallpapers"

deploy() {
  local src="$1" dst="$2"
  if [[ "$MODE" == "link" ]]; then
    if [[ -e "$dst" && ! -L "$dst" ]]; then
      mv "$dst" "$dst.bak-$(date +%s)"
      warn "Config lama di-backup: $dst"
    fi
    ln -sfn "$src" "$dst"
    ok "Symlink: $dst → $src"
  else
    if [[ -e "$dst" ]]; then
      # kalau symlink dari instalasi sebelumnya, buang dulu
      [[ -L "$dst" ]] && rm "$dst" || { cp -r "$dst" "$dst.bak-$(date +%s)"; warn "Backup lama: $dst"; }
    fi
    mkdir -p "$(dirname "$dst")"
    cp -r "$src" "$dst"
    ok "Copy: $dst"
  fi
}

echo "── Mode: $MODE ──"
echo "Deploy config dari: $DOTDIR"

# ---------- 1. Hyprland ----------
deploy "$DOTDIR/config/hypr/hyprland.lua"         "$CFG/hypr/hyprland.lua"
deploy "$DOTDIR/config/hypr/cheatsheet.sh"        "$CFG/hypr/cheatsheet.sh"
deploy "$DOTDIR/config/hypr/cheatsheet.css"       "$CFG/hypr/cheatsheet.css"
chmod +x "$CFG/hypr/cheatsheet.sh" 2>/dev/null || true

# ---------- 2. Noctalia ----------
# config.toml berisi placeholder {{WALLPAPER_DIR}} — isi dengan path pengguna
tmp_noctalia="$(mktemp)"
sed "s|{{WALLPAPER_DIR}}|$WPDIR|g" "$DOTDIR/config/noctalia/config.toml" > "$tmp_noctalia"
if [[ "$MODE" == "link" ]]; then
  # symlink nggak bisa sed-replace, jadi tulis file statis yang sudah di-resolve
  warn "Mode --link: noctalia/config.toml ditulis statis (resolve placeholder)."
  deploy "$tmp_noctalia" "$CFG/noctalia/config.toml"
else
  deploy "$tmp_noctalia" "$CFG/noctalia/config.toml"
fi
rm -f "$tmp_noctalia"

# ---------- 3. kitty ----------
deploy "$DOTDIR/config/kitty/kitty.conf"           "$CFG/kitty/kitty.conf"
deploy "$DOTDIR/config/kitty/themes/noctalia.conf" "$CFG/kitty/themes/noctalia.conf"

# ---------- 4. starship ----------
deploy "$DOTDIR/config/starship/starship.toml"     "$CFG/starship.toml"

# ---------- 5. Wallpaper ----------
mkdir -p "$WPDIR"
for img in "$DOTDIR"/wallpapers/*.png "$DOTDIR"/wallpapers/*.jpg; do
  [[ -e "$img" ]] || continue
  cp -n "$img" "$WPDIR/"
done
ok "Wallpaper disalin ke $WPDIR"

echo ""
ok "Selesai! Langkah berikutnya:"
echo "  1. Reload Hyprland :  hyprctl reload   (atau restart sesi)"
echo "  2. Validasi Noctalia:  noctalia config validate"
echo "  3. Noctalia:           noctalia msg config-reload"
echo ""
echo "  Catatan: warna di kitty/starship/noctalia.lua di-generate ulang otomatis"
echo "  oleh Noctalia (app theming) begitu kamu ganti palet/wallpaper."
