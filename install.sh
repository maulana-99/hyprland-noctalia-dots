#!/usr/bin/env bash
# ============================================================
#  install.sh — deploy dotfiles Hyprland + Noctalia, per komponen
#  Setup: Hyprland (Lua config) + Noctalia v5 + kitty + starship
#
#  Cara pakai:  ./install.sh [--link] [komponen ...]
#    tanpa komponen = pasang semua
#    --link         = symlink, perubahan di repo langsung kebawa
#    default        = salin (copy), file lama di-backup dulu (*.bak-<epoch>)
#    --list         = daftar komponen
#    -h, --help     = bantuan
#
#  Komponen: hypr  noctalia  plugins  kitty  starship  wallpapers
#  Contoh:   ./install.sh kitty starship
#            ./install.sh --link hypr noctalia
# ============================================================
set -euo pipefail

DOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$HOME/.config"
WPDIR="$HOME/Pictures/wallpapers"
MODE="copy"

ALL_COMPONENTS=(hypr noctalia plugins kitty starship wallpapers)

# Warna output
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✔${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
fail() { echo -e "${RED}✘${NC} $1"; exit 1; }

describe() {
  case "$1" in
    hypr)       echo "Hyprland: hyprland.lua + script (call-guard, quick-term, 9router-toggle, cheatsheet)" ;;
    noctalia)   echo "Noctalia: config.toml, router.toml, palet Graphite" ;;
    plugins)    echo "Plugin lokal Noctalia: Desk Todo (todo list di desktop)" ;;
    kitty)      echo "kitty: kitty.conf + tema" ;;
    starship)   echo "starship: prompt" ;;
    wallpapers) echo "Wallpaper bawaan ke ~/Pictures/wallpapers" ;;
  esac
}

usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; }

list_components() {
  echo "Komponen:"
  for c in "${ALL_COMPONENTS[@]}"; do printf '  %-11s %s\n' "$c" "$(describe "$c")"; done
}

# ---------- Argumen ----------
SELECTED=()
for arg in "$@"; do
  case "$arg" in
    --link)    MODE="link" ;;
    --list)    list_components; exit 0 ;;
    -h|--help) usage; echo; list_components; exit 0 ;;
    -*)        fail "Opsi tidak dikenal: $arg (coba --help)" ;;
    *)
      [[ " ${ALL_COMPONENTS[*]} " == *" $arg "* ]] || fail "Komponen tidak dikenal: $arg (coba --list)"
      SELECTED+=("$arg") ;;
  esac
done
[[ ${#SELECTED[@]} -gt 0 ]] || SELECTED=("${ALL_COMPONENTS[@]}")

want() { [[ " ${SELECTED[*]} " == *" $1 "* ]]; }

# ---------- Prasyarat (hanya untuk komponen yang dipilih) ----------
need() { command -v "$1" >/dev/null 2>&1 || warn "$1 belum terpasang ($2)."; }

if want hypr; then
  command -v hyprctl >/dev/null 2>&1 || fail "Hyprland belum terpasang (perlu compositor Hyprland)."
  need flameshot "dipakai screenshot"
  need wofi      "dipakai popup cheatsheet"
  need nautilus  "file manager SUPER+E"
  need pactl     "dipakai call-guard"
fi
if want noctalia || want plugins; then
  need noctalia  "pastikan sudah install Noctalia v5"
fi
want kitty    && need kitty    "terminal"
want starship && need starship "prompt"

# ---------- Helper deploy ----------
deploy() {
  local src="$1" dst="$2"
  if [[ "$MODE" == "link" ]]; then
    if [[ -e "$dst" && ! -L "$dst" ]]; then
      mv "$dst" "$dst.bak-$(date +%s)"
      warn "Config lama di-backup: $dst"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
    ok "Symlink: $dst → $src"
  else
    if [[ -e "$dst" ]]; then
      # kalau symlink dari instalasi sebelumnya, buang dulu
      if [[ -L "$dst" ]]; then rm "$dst"; else cp -r "$dst" "$dst.bak-$(date +%s)"; warn "Backup lama: $dst"; fi
    fi
    mkdir -p "$(dirname "$dst")"
    cp -r "$src" "$dst"
    ok "Copy: $dst"
  fi
}

# ---------- Komponen ----------
install_hypr() {
  deploy "$DOTDIR/config/hypr/hyprland.lua"      "$CFG/hypr/hyprland.lua"
  deploy "$DOTDIR/config/hypr/cheatsheet.sh"     "$CFG/hypr/cheatsheet.sh"
  deploy "$DOTDIR/config/hypr/cheatsheet.css"    "$CFG/hypr/cheatsheet.css"
  # Script yang dipanggil hyprland.lua / widget Noctalia (autostart + keybind + tombol bar)
  deploy "$DOTDIR/config/hypr/call-guard.sh"     "$CFG/hypr/call-guard.sh"
  deploy "$DOTDIR/config/hypr/quick-term.sh"     "$CFG/hypr/quick-term.sh"
  deploy "$DOTDIR/config/hypr/9router-toggle.sh" "$CFG/hypr/9router-toggle.sh"
  chmod +x "$CFG/hypr/"*.sh 2>/dev/null || true
}

install_noctalia() {
  # config.toml berisi placeholder {{WALLPAPER_DIR}} — isi dengan path pengguna.
  # Selalu ditulis statis (symlink tidak bisa sed-replace), baik mode copy maupun link.
  local tmp
  tmp="$(mktemp)"
  sed "s|{{WALLPAPER_DIR}}|$WPDIR|g" "$DOTDIR/config/noctalia/config.toml" > "$tmp"
  [[ "$MODE" == "link" ]] && warn "Mode --link: noctalia/config.toml ditulis statis (resolve placeholder)."
  MODE_SAVE="$MODE"; MODE="copy"
  deploy "$tmp" "$CFG/noctalia/config.toml"
  MODE="$MODE_SAVE"
  rm -f "$tmp"

  # Palet custom (abu bertingkat + aksen merah)
  mkdir -p "$CFG/noctalia/palettes"
  for p in "$DOTDIR"/config/noctalia/palettes/*.json; do
    [[ -e "$p" ]] || continue
    cp "$p" "$CFG/noctalia/palettes/"
    ok "Palet: $(basename "$p")"
  done

  # Widget tambahan (tombol 9Router) — Noctalia baca semua *.toml di folder ini
  [[ -f "$DOTDIR/config/noctalia/router.toml" ]] && \
    deploy "$DOTDIR/config/noctalia/router.toml" "$CFG/noctalia/router.toml"
  return 0
}

install_plugins() {
  # Plugin lokal Noctalia (Desk Todo). Sumber "local" menunjuk ke ~/.config/noctalia-plugins.
  deploy "$DOTDIR/config/noctalia-plugins/catalog.toml" "$CFG/noctalia-plugins/catalog.toml"
  deploy "$DOTDIR/config/noctalia-plugins/desk-todo"    "$CFG/noctalia-plugins/desk-todo"
}

install_kitty() {
  deploy "$DOTDIR/config/kitty/kitty.conf"           "$CFG/kitty/kitty.conf"
  deploy "$DOTDIR/config/kitty/themes/noctalia.conf" "$CFG/kitty/themes/noctalia.conf"
}

install_starship() {
  deploy "$DOTDIR/config/starship/starship.toml" "$CFG/starship.toml"
}

install_wallpapers() {
  mkdir -p "$WPDIR"
  for img in "$DOTDIR"/wallpapers/*.png "$DOTDIR"/wallpapers/*.jpg; do
    [[ -e "$img" ]] || continue
    cp -n "$img" "$WPDIR/"
  done
  ok "Wallpaper disalin ke $WPDIR"
}

echo "── Mode: $MODE | Komponen: ${SELECTED[*]} ──"
echo "Deploy config dari: $DOTDIR"

for c in "${ALL_COMPONENTS[@]}"; do
  want "$c" || continue
  echo ""
  echo "▸ $c — $(describe "$c")"
  "install_$c"
done

# ---------- Langkah berikutnya (sesuai komponen) ----------
echo ""
ok "Selesai! Langkah berikutnya:"
n=1
if want hypr; then
  echo "  $n. Reload Hyprland :  hyprctl reload   (atau restart sesi)"; n=$((n+1))
fi
if want noctalia; then
  echo "  $n. Validasi Noctalia:  noctalia config validate"; n=$((n+1))
  echo "  $n. Noctalia:           noctalia msg config-reload"; n=$((n+1))
fi
if want plugins; then
  echo "  $n. Plugin todo:        noctalia msg plugins enable iru/desk-todo"; n=$((n+1))
  echo "     (posisi widget di config.toml [desktop_widgets] diset utk monitor eDP-1;"
  echo "      ubah output/cx/cy kalau monitormu beda)"
fi
if want hypr || want noctalia || want kitty || want starship; then
  echo ""
  echo "  Catatan: warna di kitty/starship/noctalia.lua di-generate ulang otomatis"
  echo "  oleh Noctalia (app theming) begitu kamu ganti palet/wallpaper."
fi
