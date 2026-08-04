
# Features

## Main key bindings

The StumpWM prefix is `Super-c`. The tables below use `s-` for Super and uppercase letters for Shift where StumpWM does the same.

| Key | Action |
| --- | --- |
| `s-x` | Open the StumpWM command prompt (`colon`) |
| `s-j` / `s-k` | Select next / previous window |
| `s-J` / `s-K` | Move the current window right / left in the numbering |
| `s-RET` | Open Rofi |
| `s-S-RET` | Open the Greenclip clipboard menu through Rofi |
| `s-SPC` | Start Alacritty |
| `s-TAB` | Pull the next hidden window |
| `Print` / `Sys_Req` | Take a full / area screenshot |
| `s-1` … `s-0` | Pull windows 1 … 0 (French-layout key names in source) |
| `XF86MonBrightnessDown/Up` | Change brightness by 5 percentage points |
| `XF86AudioRaiseVolume/LowerVolume` | Change volume by 5 percentage points |
| `XF86AudioMute` | Toggle mute |

The `Super-a` application submap contains `e` for Emacs, `f` for Firefox, `g` for GIMP, and `t` for Thunar. In the prefix/root map, `l` locks the screen, `m` toggles the mode line, and `x` toggles the experimental auto-clicker.

## Application commands

- `alacritty`, `rofi`, `rofi-greenclip`, and `thunar` launch their respective applications.
- `firefox` runs or raises `firefox-esr`, launching it with the X11 class `Firefox` so its class-based StumpWM name is also `Firefox`.
- `lock-screen` starts XSecureLock with an asterisk password prompt.
- `screenshot` and `screenshot-area` write through the external `screenshot` helper into `~/tmp/screenshots/`.

## Display

Brightness is clamped to 0–100 and written with `brightnessctl`. The module caches successful writes; a failed write leaves the old cache intact.

Color temperature is rounded and clamped to 4500–6500 K, then applied with `redshift -PO`. It defaults to 6500 K and changes in 500 K steps. Available commands include:

- `brightness-status`, `brightness-set`, `brightness-reset`, `brightness-decrease`, and `brightness-increase`;
- `color-temperature-status`, `color-temperature-set`, `color-temperature-reset`, `color-temperature-warmer`, and `color-temperature-cooler`; and
- `night-mode` and `night-mode-status`.

Night mode toggles between 4500 K at 90% brightness and the normal profile of 6500 K at 100% brightness.

## Sound

The sound module controls the PipeWire default sink using `wpctl`. Volume is capped at 100%. The commands `audio-volume-up`, `audio-volume-down`, and `audio-toggle-mute` report the resulting state in a StumpWM message.

## Bluetooth

The Bluetooth package wraps `bluetoothctl` to inspect adapter power, list known devices, inspect connection state, and connect or disconnect a selected device. `bluetooth-toggle-device` presents known devices in a StumpWM selection menu.

## Networking

`nord-connect` connects NordVPN to a prompted target, defaulting to France; `nord-disconnect` disconnects it, with `nordvpn-disconnect` available as an explicit alias. The independent VPN module checks NordVPN first, then administratively active WireGuard interfaces, and normalizes the result as active, inactive, or unknown. Results are cached for 60 seconds, while explicit NordVPN connection changes invalidate the cache. Detection failures remain distinct from an inactive VPN.

## Window groups and mode line

On initial startup the config creates background groups 2, 3, and 4 when only the default group exists. The mode line sits at the bottom and shows the group, windows, VPN status, portable battery status, ISO date/week/day, and time; it refreshes once per minute. VPN status is rendered as `vpn: nord`, a WireGuard interface such as `vpn: wg0`, `vpn: off`, or `vpn: ?` when detection fails.

`move-window-left` and `move-window-right` renumber the current window when a valid adjacent position exists.

## Experimental tools

- The auto-clicker starts a managed shell loop using `xdotool` and stops it with signal 15.
- `somafm-toggle-drone-zone` manages one `mpv` process playing SomaFM Drone Zone. Dead processes are reaped before state checks.
- `slynk-start` and `slynk-stop` manage a Slynk server on port 4006 for live development.
