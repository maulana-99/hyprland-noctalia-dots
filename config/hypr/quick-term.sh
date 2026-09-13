#!/usr/bin/env bash
# ============================================================
#  quick-term.sh — terminal sekali pakai (floating, background solid)
#
#  Membuka terminal mengambang di tengah layar. Instance ini SAJA yang
#  punya background solid (#131313) — kitty lain tetap transparan.
#  Window tertutup otomatis begitu shell-nya keluar.
#
#  Toggle-nya ditangani di hyprland.lua (SUPER + Shift + Return):
#    belum ada window  → jalankan skrip ini
#    sudah ada window  → fokus + tutup
#  Skrip ini juga menjaga: kalau sudah ada window quick-term, tidak
#  membuka instance kedua (anti-dobel).
# ============================================================
set -u

# Sudah ada quick-term? jangan buka lagi.
if hyprctl clients -j 2>/dev/null | grep -q '"class": "quick-term"'; then
  exit 0
fi

exec kitty \
  --class quick-term \
  --title "Quick Terminal" \
  -o background_opacity=1.0 \
  -o background='#131313' \
  -o dynamic_background_opacity=no \
  -o confirm_os_window_close=0 \
  "$@"
