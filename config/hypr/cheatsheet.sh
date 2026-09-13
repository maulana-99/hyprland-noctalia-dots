#!/usr/bin/env bash
# Cheatsheet shortcut Hyprland — popup daftar semua keybind (wofi)
# Dipanggil via SUPER + SHIFT + /  (SUPER + ?)
#
# Format setiap entri:  "LABEL <TAB> SHORTCUT"
#   - awali dengan "@HEADER " untuk judul seksi
#   - awali dengan "@SPACER"  untuk baris kosong
# Posisi shortcut dikontrol via markup pango (rata kanan tidak didukung wofi dmenu,
# jadi dipakai titik-titik perata manual).

CSS="$HOME/.config/hypr/cheatsheet.css"

print_entry() {
  local label="$1" key="$2"
  # label (kiri, abu terang) + titik pengisi + shortcut (kanan, merah)
  printf '<span color="#c8c8c8">%s</span> <span color="#555555">%s</span> <span color="#fd4663" weight="bold">%s</span>\n' \
    "$label" "•" "$key"
}

{
  echo ""
  print_entry "Terminal"                      "SUPER + Return"
  print_entry "Terminal Sekali Pakai (float)" "SUPER + Shift + Return"
  print_entry "File Manager (dolphin)"        "SUPER + E"
  print_entry "Browser (firefox)"             "SUPER + B"
  print_entry "Editor (nvim)"                 "SUPER + W"

  echo ""
  echo "@HEADER ⚙ Panel Noctalia"
  print_entry "Launcher"                      "SUPER + Space"
  print_entry "Control Center"                "SUPER + A"
  print_entry "Riwayat Clipboard"             "SUPER + Shift + C"
  print_entry "Pilih Wallpaper"               "SUPER + Shift + P"
  print_entry "Panel Audio / Bluetooth"       "SUPER + Shift + V"

  echo ""
  echo "@HEADER 🪟 Window"
  print_entry "Tutup Window"                  "SUPER + Q"
  print_entry "Fullscreen"                    "SUPER + F"
  print_entry "Float / Unfloat"               "SUPER + V"
  print_entry "Pin di Atas"                   "SUPER + T"
  print_entry "Pseudotile"                    "SUPER + P"
  print_entry "Ubah Arah Split"               "SUPER + Shift + Space"

  echo ""
  echo "@HEADER 🧭 Navigasi & Posisi"
  print_entry "Fokus ke Arah (vim/panah)"     "SUPER + H/J/K/L"
  print_entry "Cycle Window Berikutnya"       "SUPER + Tab"
  print_entry "Fokus Window Terakhir"         "SUPER + Shift + Tab"
  print_entry "Swap Posisi (arah)"            "SUPER + Shift + Panah"
  print_entry "Swap Posisi (vim)"             "SUPER + Ctrl + H/J/K/L"

  echo ""
  echo "@HEADER 🗔 Workspace"
  print_entry "Pindah Workspace"              "SUPER + 1-9"
  print_entry "Kirim ke Workspace"            "SUPER + Shift + 1-9"
  print_entry "Scratchpad"                    "SUPER + S"
  print_entry "Kirim ke Scratchpad"           "SUPER + Shift + S"
  print_entry "Scroll Workspace"              "SUPER + Scroll"

  echo ""
  echo "@HEADER 📸 Screenshot"
  print_entry "Screenshot Area (GUI)"         "Print"
  print_entry "Screenshot Fullscreen"         "Shift + Print"
  print_entry "Screenshot Region (Noctalia)"  "SUPER + Print"

  echo ""
  echo "@HEADER 🔐 Sistem"
  print_entry "Kunci Layar"                   "SUPER + Shift + L"
  print_entry "Kunci Layar (alternatif)"      "SUPER + Escape"
  print_entry "Power Menu (logout/shutdown)"  "SUPER + Shift + E"
  print_entry "Volume Naik/Turun"             "Tombol Media (XF86)"
  print_entry "Media Next/Prev/Play"          "Tombol Media (XF86)"
} | wofi \
  --dmenu \
  --style "$CSS" \
  --width 760 \
  --height 640 \
  --prompt "⌨ Shortcut Hyprland — SUPER + ? untuk menutup" \
  --hide-search \
  --no-custom-entry \
  --allow-markup \
  -k /dev/null
