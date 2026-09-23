#!/usr/bin/env bash
# ============================================================
#  9router-toggle.sh — tombol on/off 9router di bar Noctalia
#
#  Deteksi status lewat port (default 20128).
#  STOP  : port listening → matikan
#  START : belum → jalankan di background (tanpa buka browser)
#
#  Setiap toggle juga menulis ulang ~/.config/noctalia/router.toml
#  sehingga tombol di bar "menyala" (merah) saat aktif, abu saat mati.
#  Noctalia hot-reload otomatis begitu file berubah.
#
#  Mode:  --sync   hanya sinkronkan warna tombol (tanpa toggle)
# ============================================================
set -u

PORT="${NINE_ROUTER_PORT:-20128}"
CFG_DIR="${NOCTALIA_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}/noctalia"
WIDGET_FILE="$CFG_DIR/router.toml"

resolve_9router() {
  if command -v 9router >/dev/null 2>&1; then
    command -v 9router
    return
  fi
  find "$HOME/.nvm" -type f -name 9router 2>/dev/null | head -n1
}
BIN="$(resolve_9router)"

notify() { noctalia msg notification-show "9Router" "$1" >/dev/null 2>&1 || true; }

is_running() { ss -ltn 2>/dev/null | grep -q ":${PORT} "; }
listener_pids() {
  ss -ltnp 2>/dev/null | grep ":${PORT} " | grep -oE 'pid=[0-9]+' | cut -d= -f2 | sort -u
}

# Tulis config tombol sesuai status (menyala = merah, mati = abu)
write_widget() {
  local on="$1" color tooltip
  if [[ "$on" == "1" ]]; then
    color="#fd4663"; tooltip="9Router: NYALA — klik untuk matikan"
  else
    color="#5c5c5c"; tooltip="9Router: mati — klik untuk nyalakan"
  fi
  mkdir -p "$CFG_DIR"
  cat > "$WIDGET_FILE" <<EOF
# Otomatis ditulis oleh 9router-toggle.sh — jangan edit manual.
[widget.router9]
type = "custom_button"
glyph = "router"
label = ""
tooltip = "$tooltip"
color = "$color"
icon_color = "$color"

[widget.router9.actions]
left = "exec bash ~/.config/hypr/9router-toggle.sh"
EOF
}

# Tunggu sampai port listening (maks ~10s)
wait_up() { for _ in $(seq 1 20); do is_running && return 0; sleep 0.5; done; return 1; }
# Tunggu sampai port benar-benar tutup (maks ~5s)
wait_down() { for _ in $(seq 1 10); do is_running || return 0; sleep 0.5; done; return 1; }

# --- mode --sync: cuma perbarui tampilan tombol ---
if [[ "${1:-}" == "--sync" ]]; then
  if is_running; then write_widget 1; else write_widget 0; fi
  exit 0
fi

if [[ -z "$BIN" ]]; then
  notify "❌ binary 9router tidak ditemukan"
  exit 1
fi

if is_running; then
  pids="$(listener_pids)"
  if [[ -n "$pids" ]]; then
    kill $pids 2>/dev/null || true
  else
    fuser -k "${PORT}/tcp" >/dev/null 2>&1 || true
  fi
  if wait_down; then
    notify "⏻ 9router dimatikan"
  else
    notify "⚠ gagal mematikan 9router"
  fi
else
  nohup "$BIN" --no-browser --skip-update >/tmp/9router.log 2>&1 &
  if wait_up; then
    notify "✅ 9router dijalankan (port ${PORT})"
  else
    notify "⚠ gagal menjalankan 9router (cek /tmp/9router.log)"
  fi
fi

# Perbarui tampilan tombol (menyala = merah, mati = abu)
if is_running; then write_widget 1; else write_widget 0; fi

