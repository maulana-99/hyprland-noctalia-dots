#!/usr/bin/env bash
# ============================================================
#  call-guard.sh — cegah auto-sleep saat lagi telpon/meeting
#
#  Deteksi "call aktif": ada audio live (WebRTC) yang TIDAK corked
#  dari aplikasi meeting/browser, ATAU mikrofon (source-output)
#  yang sedang dipakai aplikasi non-sistem.
#
#  Saat call terdeteksi  →  noctalia caffeine-enable  (idle inhibitor)
#  Saat call selesai     →  noctalia caffeine-disable
#
#  Dipasang sebagai daemon autostart. Polling ringan tiap 10 detik.
# ============================================================
set -u

POLL_SECONDS=10
MEETING_APPS="firefox|zen|librewolf|chromium|google-chrome|chrome|brave|discord|zoom|teams|slack|whatsapp|webex|element"

# Buffer anti-flicker: berapa siklus berturut-turut harus "no-call"
# sebelum caffeine benar-benar dimatikan (hindari toggle kedip saat
# lawan bicara diam sebentar).
CONFIRM_OFF_CYCLES=6

STATE_FILE="/tmp/call-guard.state"
off_cycles=0
caffeine_on=0

say() { echo "[call-guard] $*"; }

# Cek: apakah ada stream audio "call-like" yang live & tidak corked
is_call_active() {
    local lines
    lines="$(pactl list sink-inputs 2>/dev/null)"
    [[ -z "$lines" ]] && return 1

    # 1) Ada stream output dengan media live (WebRTC), tidak corked,
    #    dan aplikasinya dari daftar meeting/browser.
    #    Parsing per blok "Sink Input #N".
    local app=""
    local corked=""
    local live=""
    local role=""
    local in_block=0
    while IFS= read -r line; do
        if [[ "$line" == "Sink Input #"* ]]; then
            # evaluasi blok sebelumnya
            if (( in_block )); then
                if _match_stream "$app" "$corked" "$live" "$role"; then
                    return 0
                fi
            fi
            app=""; corked=""; live=""; role=""; in_block=1
            continue
        fi
        [[ $line =~ application.name[[:space:]]*=.*\"(.*)\" ]] && app="${BASH_REMATCH[1]}"
        [[ $line =~ Corked:[[:space:]]*(.*) ]] && corked="${BASH_REMATCH[1]}"
        [[ $line =~ stream.is-live[[:space:]]*=.*\"(.*)\" ]] && live="${BASH_REMATCH[1]}"
        [[ $line =~ media.role[[:space:]]*=.*\"(.*)\" ]] && role="${BASH_REMATCH[1]}"
    done <<< "$lines"
    # blok terakhir
    if (( in_block )) && _match_stream "$app" "$corked" "$live" "$role"; then
        return 0
    fi

    # 2) Mikrofon dipakai aplikasi meeting (source-output) → pasti call
    local mic
    mic="$(pactl list source-outputs 2>/dev/null)"
    if [[ -n "$mic" ]]; then
        local mic_app=""
        while IFS= read -r line; do
            [[ $line =~ application.name[[:space:]]*=.*\"(.*)\" ]] && mic_app="${BASH_REMATCH[1]}"
            if [[ -n "$mic_app" ]] && grep -qiE "$MEETING_APPS" <<<"$mic_app"; then
                return 0
            fi
        done <<< "$mic"
    fi
    return 1
}

# stream dianggap "call" bila: live + tidak corked + aplikasi meeting
_match_stream() {
    local app="$1" corked="$2" live="$3" role="$4"
    [[ -z "$app" ]] && return 1
    # aplikasi bukan dari daftar meeting → anggap musik/video biasa
    grep -qiE "$MEETING_APPS" <<<"$app" || return 1
    # corked true = stream di-pause (tab tidak aktif) → bukan call
    [[ "$corked" == "yes" ]] && return 1
    # role khusus musik/video yang jelas bukan panggilan
    if [[ "$role" == "music" || "$role" == "video" || "$role" == "event" ]]; then
        return 1
    fi
    # live=true adalah penanda WebRTC/streaming real-time; kalau tidak
    # ada info live, fallback: stream tanpa corked dianggap call
    if [[ -n "$live" && "$live" != "true" ]]; then
        return 1
    fi
    return 0
}

say "call-guard berjalan (poll ${POLL_SECONDS}s)."

while true; do
    if is_call_active; then
        off_cycles=0
        if (( ! caffeine_on )); then
            if noctalia msg caffeine-enable >/dev/null 2>&1; then
                say "call terdeteksi → caffeine ON (anti-sleep)."
                caffeine_on=1
                echo on > "$STATE_FILE"
            fi
        fi
    else
        if (( caffeine_on )); then
            (( off_cycles++ ))
            if (( off_cycles >= CONFIRM_OFF_CYCLES )); then
                if noctalia msg caffeine-disable >/dev/null 2>&1; then
                    say "call selesai → caffeine OFF."
                    caffeine_on=0
                    echo off > "$STATE_FILE"
                fi
                off_cycles=0
            fi
        else
            off_cycles=0
        fi
    fi
    sleep "$POLL_SECONDS"
done
