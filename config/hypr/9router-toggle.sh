#!/usr/bin/env bash
# ============================================================
#  9router-toggle.sh — tombol on/off 9router di bar Noctalia
#
#  Deteksi status lewat port (default 20128) — bukan nama proses,
#  supaya akurat dan tidak salah menangkap proses lain.
#
#  STOP  : kalau port sedang listening → matikan proses-nya
#  START : kalau belum → jalankan di background (tanpa buka browser)
# ============================================================
set -u

PORT="${NINE_ROUTER_PORT:-20128}"

resolve_9router() {
  if command -v 9router >/dev/null 2>&1; then
    command -v 9router
    return
  fi
  find "$HOME/.nvm" -type f -name 9router 2>/dev/null | head -n1
}
BIN="$(resolve_9router)"

notify() {
  noctalia msg notification-show "9Router" "$1" >/dev/null 2>&1 || true
}

# Port sedang dipakai (server jalan)?
is_running() { ss -ltn 2>/dev/null | grep -q ":${PORT} "; }

# PID yang mendengarkan di port tersebut
listener_pids() {
  ss -ltnp 2>/dev/null | grep ":${PORT} " | grep -oE 'pid=[0-9]+' | cut -d= -f2 | sort -u
}

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
  sleep 1
  if is_running; then
    notify "⚠ gagal mematikan 9router"
  else
    notify "⏻ 9router dimatikan"
  fi
else
  nohup "$BIN" --no-browser --skip-update >/tmp/9router.log 2>&1 &
  sleep 2
  if is_running; then
    notify "✅ 9router dijalankan (port ${PORT})"
  else
    notify "⚠ gagal menjalankan 9router (cek /tmp/9router.log)"
  fi
fi
