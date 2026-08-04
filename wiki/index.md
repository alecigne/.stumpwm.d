
# StumpWM config

This is Anthony Le Cigne's personal StumpWM configuration. It is organized as a small Common Lisp ASDF system: reusable code lives in focused packages, while one final module connects that code to StumpWM commands, hooks, appearance, and key bindings.

## Start here

- [[Architecture]] — how StumpWM loads the config, ASDF component order, packages, initialization, and reload behavior

- [[Features]] — commands, key bindings, display/audio/Bluetooth/VPN controls, and experimental tools

- [[Development]] — dependencies, tests, logs, the REPL, and serving this wiki

- [[notes|Common Lisp notes]] — design notes about dynamically rebound effect functions and test seams

## Quick reference

From the repository root:

```sh
just test
just serve
```

`just test` runs the FiveAM unit tests through Roswell and ASDF. `just serve` starts SilverBullet with `wiki/` as its space; the default local URL is <http://localhost:3000>.

The source of truth remains the Lisp code. This wiki explains its structure and operating assumptions, but should be updated when commands, bindings, or dependencies change.

## Other StumpWM configs

Useful examples and sources of ideas:

- <https://codeberg.org/Izder456/StumpWM-Config>
- <https://github.com/solbloch/stumpwm-configs>
- <https://github.com/alezost/stumpwm-config>
