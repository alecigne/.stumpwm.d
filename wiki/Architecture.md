
# Architecture

## Load path

StumpWM treats `init.lisp` as the entry point. It performs two operations:

```lisp
(require "asdf")
(asdf:load-system "stumpwm-config")
```

ASDF finds `stumpwm-config.asd` in the config directory and loads its serial components in this order:

1. `src/package.lisp`
2. `src/core.lisp`
3. `src/bluetooth.lisp`
4. `src/display.lisp`
5. `src/sound.lisp`
6. `src/vpn.lisp`
7. `src/config.lisp`

The order matters: packages exist before their implementations, and the StumpWM-facing config is loaded only after all supporting modules.

## Packages and responsibilities

| Package | Local nickname | Responsibility |
| --- | --- | --- |
| `net.lecigne.stumpwm.core` | `core` | Small general utilities, currently string sanitizing |
| `net.lecigne.stumpwm.bluetooth` | `bluetooth` | `bluetoothctl` state, device discovery, and connection toggling |
| `net.lecigne.stumpwm.display` | `display` | Brightness, color-temperature caches and writers, and night mode |
| `net.lecigne.stumpwm.sound` | `sound` | PipeWire volume and mute operations through `wpctl` |
| `net.lecigne.stumpwm.vpn` | `vpn` | Cached NordVPN and WireGuard status detection |
| `net.lecigne.stumpwm` | — | StumpWM commands, UI messages, hooks, modules, applications, and bindings |

Only `src/config.lisp` needs a live StumpWM session. The supporting modules use Common Lisp and external commands, which lets the test system load them without loading session-dependent configuration.

## ASDF systems

`stumpwm-config` depends on Alexandria, CL-PPCRE, CLX-TrueType, Local-Time, Slynk, and StumpWM. Its ASDF `test-op` delegates to `stumpwm-config/tests`.

The test system additionally depends on FiveAM. It deliberately omits `src/config.lisp`, then loads `tests/package.lisp` and `tests/tests.lisp` and calls `net.lecigne.stumpwm.tests:run-tests`.

## Initialization effects

Loading `src/config.lisp` does more than define functions. It also:

- Configures StumpWM messages, the mode line, window naming, pointer colors, increment hints, and the startup message;
- Sets the cursor with `xsetroot`;
- Redirects Lisp/StumpWM output to `stumpwm.log` beneath `stumpwm:*data-dir*`;
- Loads the `battery-portable` and `ttf-fonts` contrib modules;
- Caches fonts and selects JetBrains Mono 12;
- Creates groups 2–4 when this is the initial startup with only one group;
- Starts `alttab` during initial startup when it is available;
- Installs keyboard, start, restart, and quit hooks; and enables the mode line.

The contrib module directory is currently hard-coded as `~/src/stumpwm-contrib/`.

## Hooks and lifecycle

- The start and restart hooks run `load-xmodmap`. If `~/.Xmodmap` exists, it first selects the French `latin9` layout and then loads that file.
- The key-press hook displays incomplete key sequences for prefix maps.
- The quit and restart hooks stop the managed Slynk server if it is running.
- `slynk-start` listens on port 4006; it is opt-in, not started during config load.

## Reload and cached state

The config is designed for an interactive, long-lived Lisp image. Variables defined with `defvar` retain their existing bindings when a file is reloaded; variables defined with `defparameter` are reset to their initializer.

This distinction is intentional in the display module:

- Brightness, color temperature, and night-mode state use `defvar`, so cached state survives an ordinary reload;
- Writer functions use `defparameter`, so reloading restores the production external-command implementation after a test or REPL experiment.

The VPN module similarly retains its last detected status across reloads. Its detector functions and monotonic clock use `defparameter`, so reloading restores the production implementations, while the cached status and timestamp use `defvar`. `current-status` refreshes entries after 60 seconds; callers can also force a refresh or invalidate the cache after an operation that may change connectivity.

Color temperature starts at 6500 K in a fresh Lisp process without invoking `redshift`. Brightness starts unknown and uses 100% as the baseline for its first relative adjustment. These values are config-owned caches, not readings queried from the hardware.
