# Planning: Ricing Hyprland + Noctalia

> Dokumen perencanaan — keputusan final, siap eksekusi.

## 1. Kondisi Saat Ini

- **Distro**: Arch Linux, Wayland, GPU AMD (tanpa NVIDIA)
- **Hyprland**: config `~/.config/hypr/hyprland.lua` (API Lua) — masih template default
  - Program: kitty (terminal), dolphin (file manager), hyprlauncher (menu)
  - Keybind dasar: SUPER+Q terminal, SUPER+C tutup, SUPER+E file manager, SUPER+R launcher, SUPER+V float, dst.
  - Belum ada autostart, belum ada color scheme khusus
- **Noctalia**: `noctalia 5.0.0_beta.10-1` **sudah terpasang** (`/usr/sbin/noctalia`) tapi belum dikonfigurasi
  - Folder `~/.config/noctalia/` masih kosong
- **Apps pendukung yang ada**: wofi, dunst, grim+slurp (screenshot), wpctl (audio), brightnessctl
- **Belum ada**: Nerd Font, theme GTK/Qt, clipboard manager, lock screen, wallpaper

## 2. Apa Itu Noctalia v5

Bukan sekadar color scheme — **desktop shell lengkap** untuk Wayland:
bar (top/bottom/left/right), dock, launcher, control center, notifikasi, lock screen,
idle daemon, wallpaper, night light, weather, bahkan greeter (login screen).

- **Config**: TOML di `~/.config/noctalia/`, hot-reload
- **Tema**: 16 color roles + terminal colors; sumber bisa builtin / wallpaper (M3) / community / custom
- **Palet builtin**: Noctalia, Ayu, Catppuccin, Dracula, Eldritch, Gruvbox, Kanagawa, Nord, Rosé Pine, Tokyo-Night
- **App Theming**: bisa render warna ke config app lain (kitty, GTK, editor, dll.) via templates — otomatis sinkron tiap ganti palet
- **CLI**: `noctalia config validate`, `noctalia config export`, `noctalia theme --list-templates`

## 3. Keputusan Final

**Arah umum**
- [x] Pendekatan: **Noctalia penuh + app lain di-theme sinkron** (Hyprland fokus jadi WM)
- [x] Tujuan: **produktif untuk kerja & kuliah**, style **minimalis**
- [x] Palet: **builtin Noctalia**
- [x] Mode: **dark saja** dulu (bisa tambah auto belakangan)

**Layout & shell**
- [x] Bar: **atas (top)**, tipis, hanya widget penting (workspaces, clock, volume, tray)
- [x] Dock: **tidak dipakai** (Noctalia default bar; dock dimatikan)

**App & tools**
- [x] Terminal: kitty (+ warna & font Noctalia)
- [x] Font: **JetBrainsMono Nerd Font**
- [x] PDF: **buka via Firefox** dulu (zathura/sioyek ditunda — tidak diinstall sekarang)
- [x] CLI tools: **fzf, ripgrep, bat, zoxide, tmux, lazygit, starship**
- [x] Screenshot: **grim + slurp** (sudah ada) — keybind PRINT / SHIFT+PRINT
- [x] Clipboard: **cliphist + wl-clipboard** (tambah)
- [x] Apps di-theme Noctalia: **kitty, dolphin, nvim, VS Code** (firefox TIDAK)

**Keybind & workspace**
- [x] Modifier: **SUPER (Windows key)**
- [x] Keybind Noctalia: `SUPER+SPACE` = launcher, `SUPER+A` = control center (bar toggle cadangan)
- [x] Workspace scheme: 1=web, 2=editor/kode, 3=terminal/docs, 4=komunikasi, sisanya bebas

**Autostart**
- [x] Jalan: **noctalia**, **cliphist** (daemon), dll.
- [x] Nonaktifkan: **dunst** & **hyprlauncher** (Noctalia punya notifikasi & launcher sendiri)

**Wallpaper**
- [x] Folder: `~/Pictures/wallpapers` (belum ada isinya — perlu download/rekomendasi sumber)

## 4. Pembagian Peran

| Bagian | Pemilik | Catatan |
|---|---|---|
| Bar / statusbar | Noctalia | top, tipis, minimal |
| Launcher / menu | Noctalia | SUPER+SPACE |
| Control center | Noctalia | SUPER+A |
| Notifikasi | Noctalia | dunst dinonaktifkan |
| Lock screen & idle | Noctalia | |
| Wallpaper | Noctalia | `~/Pictures/wallpapers` |
| App theming | Noctalia templates | kitty, dolphin, nvim, VS Code |
| Tiling, gap, border, animasi | Hyprland | `hyprland.lua` |
| Workspace & keybind | Hyprland | SUPER+SPACE/A untuk Noctalia |
| Window rules | Hyprland | |
| Screenshot | grim+slurp | keybind di Hyprland |
| Clipboard | cliphist+wl-clipboard | daemon autostart |

## 5. Deskripsi Desktop Target (minimalis)

- Bar tipis di atas: workspaces kiri, clock tengah/kanan, volume + tray di kanan
- Warna dark palet Noctalia, gap sedang, border tipis, animasi halus
- Launcher & control center Noctalia (tema otomatis sinkron)
- Tanpa dock, tanpa wallpaper ramai — bersih dan fokus
- Workspace rapi: web / kode / terminal / komunikasi

## 6. Langkah Implementasi

1. **Install paket**: `ttf-jetbrains-mono-nerd`, `zathura`, `zathura-pdf-mupdf`, `sioyek`, `cliphist`, `wl-clipboard`, `fzf`, `ripgrep`, `bat`, `zoxide`, `tmux`, `lazygit`, `starship`
2. **Setup config Noctalia** (`~/.config/noctalia/config.toml`):
   - `[theme]` → mode dark, source builtin, palet Noctalia
   - `[bar.default]` → posisi top, tipis, widget minimal
   - Font global JetBrainsMono Nerd Font
3. **Autostart**: tambah `noctalia` + `cliphist` di `hyprland.lua` (`hl.on("hyprland.start", ...)`), nonaktifkan dunst/hyprlauncher
4. **Keybind**: lepas SUPER+R (hyprlauncher) → ganti SUPER+SPACE (launcher Noctalia) + SUPER+A (control center); tambah PRINT/SHIFT+PRINT (screenshot)
5. **Wallpaper**: buat `~/Pictures/wallpapers`, download koleksi, set di Noctalia
6. **App theming**: aktifkan template/theme untuk kitty, dolphin (GTK), nvim, VS Code
7. **Terminal & shell**: set font kitty, theme kitty dari palet Noctalia; setup starship + CLI tools (fzf, zoxide, dll.)
8. **Workspace rules** di Hyprland: atur window rules untuk app (mis. browser ke ws 1, editor ke ws 2)
9. **Validasi**: `noctalia config validate`, reload config, tes keybind & fitur
10. **Poles opsional**: lock screen, idle, night light

## 7. Catatan

- Config Noctalia hot-reload: edit `~/.config/noctalia/*.toml` langsung kelihatan
- GUI Settings Noctalia menulis ke `~/.local/state/noctalia/settings.toml` (menang atas config manual) — kalau bingung kenapa setting tak berefek, cek file itu
- Beta version (beta.10) — mungkin ada perubahan API/format
- `noctalia theme --list-templates` untuk cek template bawaan yang tersedia (perlu izin jalan)
