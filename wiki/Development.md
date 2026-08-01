
# Development

## Repository layout

```text
init.lisp              StumpWM entry point
stumpwm-config.asd     application and test ASDF systems
src/package.lisp       package definitions and local nicknames
src/core.lisp          general utilities
src/bluetooth.lisp     Bluetooth operations
src/display.lisp       brightness, temperature, and night mode
src/sound.lisp         volume and mute operations
src/config.lisp        live StumpWM configuration and commands
tests/                 FiveAM unit tests
wiki/                  this SilverBullet space
Justfile               common development recipes
```

## Lisp dependencies

The application system requires:

- A Common Lisp implementation (the recipes use SBCL);
- ASDF/UIOP;
- Alexandria;
- CL-PPCRE;
- CLX-TrueType;
- Local-Time;
- Slynk;
- StumpWM; and
- FiveAM for tests.

StumpWM must be able to discover this directory as its config/ASDF system when it evaluates `init.lisp`.

## Runtime programs and local assumptions

Features invoke these external programs when used:

| Program or resource | Used for |
| --- | --- |
| `brightnessctl` | Display brightness |
| `redshift` | One-shot color temperature changes |
| `wpctl` | PipeWire volume and mute |
| `bluetoothctl` | Bluetooth adapter and devices |
| `alacritty`, `firefox-esr`, `rofi`, `greenclip`, `thunar` | Application commands |
| `xsecurelock` | Screen locking |
| `screenshot` | Full and selected-area screenshots |
| `nordvpn` | VPN commands |
| `alttab` | Startup task switcher, when found in `PATH` |
| `xdotool` | Experimental auto-clicker |
| `mpv` | SomaFM playback |
| `xsetroot`, `setxkbmap`, `xmodmap` | Cursor and keyboard setup |
| JetBrains Mono | Configured Xft font |
| `~/src/stumpwm-contrib/` | `battery-portable` and `ttf-fonts` modules |

Most programs are only required when their feature is invoked. Font and contrib-module setup occur during config loading. `xsetroot` is also invoked at load time; `alttab` is optional and checked before startup.

## Tests

Run:

```sh
just test
```

This executes `asdf:test-system` in a non-interactive SBCL. The FiveAM tests cover string sanitizing, Bluetooth device parsing, display normalization and caches, night-mode transitions, and `wpctl` output parsing.

External effects are replaced with dynamically bound function-valued special variables, so unit tests do not alter the real display. See [[notes|Common Lisp notes]] for the rationale. The suite does not verify that external programs are installed or work with the current machine; those are integration concerns.

## Live development

Run the StumpWM commands `slynk-start` and `slynk-stop` to control a Slynk server on port 4006. Restarting or quitting StumpWM stops a server managed by the config.

Because Common Lisp reloads code into the running image, remember that `defvar` preserves existing values while `defparameter` resets them. See [[Architecture#Reload and cached state]].

StumpWM and Lisp output is redirected to `stumpwm.log` under `stumpwm:*data-dir*`.

## Wiki

Run:

```sh
just serve
```

This executes `silverbullet ./wiki`. By default SilverBullet listens locally at <http://localhost:3000>. Keep it bound to localhost unless authentication and TLS have been configured for remote access.
