# Hyprland + Noctalia Dots

Setup desktop **minimalis-TUI** ala dwm: bar transparan penuh teks/ikon monospace, workspace nomor dengan aksen warna, popup cheatsheet shortcut, dan shell **Noctalia** (bar, launcher, control center, lock screen, idle, wallpaper).

> Prinsip desain: **quiet-competence** — kontras rendah, aksen hemat, semua font monospace (Nerd Font), tanpa border/rounded berlebihan.

![palette](https://img.shields.io/badge/palette-gray%20%2B%20coral%20%23FD4663-8a8a8a) ![wm](https://img.shields.io/badge/WM-Hyprland%200.56-blue) ![shell](https://img.shields.io/badge/shell-Noctalia%20v5-4a4a4a)

## Fitur

- **Bar atas gaya dwm** — transparan, tanpa kotak/border, pemisah simbol `|`, monospace JetBrainsMono Nerd Font
- **Workspace 1–9** — selalu tampil: aktif = putih, ada notif/urgent = merah coral `#FD4663`, terisi = abu, kosong = abu redup
- **Taskbar** — ikon app/window yang sedang berjalan di bar
- **Power menu dengan konfirmasi** — shutdown/reboot butuh countdown 3 detik (anti kebablasan)
- **Auto sleep anti burn-in** — layar mati setelah idle 3 menit, kunci+suspend setelah 5 menit
- **Popup cheatsheet** — `SUPER + Shift + /` menampilkan semua shortcut
- **App theming otomatis** — kitty, GTK, starship, Hyprland border disinkron dari palet Noctalia
- **Palet dari wallpaper** — skema `m3-monochrome` (abu netral) + aksen merah coral

## Screenshot-style preview

```
┌──────────────────────────────────────────────────────────────┐
│  1 2 3 4 5 6 7 8 9 | 🖥  🔍  📋 ...  |  clock   | 🔊 🔋 ▁▂▃  │
├──────────────────────────────────────────────────────────────┤
│  window 1 (aktif, border merah coral)                       │
└──────────────────────────────────────────────────────────────┘
```

## Kebutuhan (dependencies)

Arch Linux (atau Arch-based) + Wayland:

```
sudo pacman -S hyprland kitty dolphin firefox flameshot wofi \
    wpctl wireplumber brightnessctl ttf-jetbrains-mono-nerd \
    cliphist wl-clipboard starship
```

- **Noctalia v5** — shell desktop (bar, launcher, control center, lock, idle, wallpaper).
  Install dari repo/AUR Noctalia lalu pastikan `noctalia` ada di `PATH`.
- `hyprctl` & `noctalia msg` dipakai dari keybind.

## Instalasi

```bash
git clone https://github.com/maulana-99/hyprland-noctalia-dots.git
cd hyprland-noctalia-dots
./install.sh          # salin config (file lama di-backup otomatis)
# atau
./install.sh --link   # pakai symlink, perubahan repo langsung kebawa
```

Setelah itu:

```bash
hyprctl reload                # atau logout-login ulang sesi
noctalia config validate      # pastikan config Noctalia valid
noctalia msg config-reload
```

Install script akan:
1. Menyalin config ke `~/.config/hypr`, `~/.config/noctalia`, `~/.config/kitty`, `~/.config/starship.toml`
2. Me-resolve placeholder `{{WALLPAPER_DIR}}` di config Noctalia ke `~/Pictures/wallpapers`
3. Menyalin wallpaper bawaan ke `~/Pictures/wallpapers`

> **Penting soal warna:** kitty / starship / `hypr/noctalia.lua` berisi warna yang
> **di-generate otomatis oleh Noctalia** dari wallpaper aktif (app theming).
> Kalau kamu ganti wallpaper atau palet, jalankan `noctalia msg templates-apply`
> supaya semua app ikut tersinkron.

## Keybind utama

| Shortcut | Aksi |
|---|---|
| `SUPER + ?` | **Tampilkan semua shortcut (cheatsheet popup)** |
| `SUPER + Return` | Terminal (kitty) |
| `SUPER + E` | File manager (dolphin) |
| `SUPER + B` | Browser (firefox) |
| `SUPER + Space` | Launcher (Noctalia) |
| `SUPER + A` | Control center |
| `SUPER + Q` | Tutup window |
| `SUPER + F` | Fullscreen |
| `SUPER + V` | Float window |
| `SUPER + H/J/K/L` / Panah | Pindah fokus |
| `SUPER + Shift + Panah` | Swap posisi window |
| `SUPER + 1-9` | Pindah workspace |
| `SUPER + Shift + 1-9` | Kirim window ke workspace |
| `SUPER + S` | Scratchpad |
| `SUPER + Shift + L` | Kunci layar |
| `SUPER + Shift + E` | Power menu (shutdown/reboot ada konfirmasi) |
| `Print` / `Shift+Print` | Screenshot area / fullscreen |

Skema mnemonic: **huruf awal kata** (E=Explorer, B=Browser, F=Fullscreen, L=Lock, Q=Quit, S=Scratchpad). Lengkapnya ada di popup `SUPER + ?`.

## Struktur repo

```
hyprland-noctalia-dots/
├── install.sh                    # script deploy (copy/symlink)
├── config/
│   ├── hypr/
│   │   ├── hyprland.lua          # config utama Hyprland (monitor, keybind, rule)
│   │   ├── cheatsheet.sh         # popup daftar shortcut (wofi)
│   │   ├── cheatsheet.css        # styling popup
│   │   └── noctalia.lua.example  # contoh warna hasil generate Noctalia
│   ├── noctalia/
│   │   └── config.toml           # shell: bar, dock, idle, session, wallpaper
│   ├── kitty/
│   │   ├── kitty.conf
│   │   └── themes/noctalia.conf  # warna kitty (generate Noctalia)
│   └── starship/starship.toml    # palet prompt
├── wallpapers/                   # wallpaper solid + haikei bawaan
└── docs/planning-noctalia.md     # catatan perencanaan & keputusan desain
```

## Catatan

- **Noctalia GUI settings** (`~/.local/state/noctalia/settings.toml`) menang atas
  `config.toml` — kalau setting kamu "nggak ngefek", cek file itu dulu.
- Config ini dibuat & diuji di **Hyprland 0.56 (config Lua)** + Noctalia 5.0.0 beta.
  API Lua `hl.*` bisa berubah antar versi Hyprland.
- Sudut dibuat lancip (radius 0) di semua panel; kalau mau sedikit tumpul,
  ubah `corner_radius_scale` di `config/noctalia/config.toml`.

## Lisensi

MIT — pakai, ubah, dan bagikan sesukamu.
