# Default widget sources

Vendored MIT-licensed sources from the upstream Pock organization. License files remain in each directory. Local changes remove automatic install phases, clear the upstream signing team, and align deployment targets. The root Podfile resolves shared dependencies for all widgets.

| Source | Repository | Imported commit |
|---|---|---|
| dock-widget | https://github.com/pock/dock-widget | `fd5250e6291e886abdeaf018406dd2d4b6d2160a` |
| esc-widget | https://github.com/pock/esc-widget | `811ccdf3df56cc67fc94644727ebe2f74c3346c6` |
| now-playing-widget | https://github.com/pock/now-playing-widget | `156276f31daead703d033704157b70be65f44ea8` |
| status-widget | https://github.com/pock/status-widget | `dbe7ef747171efdd5ec53c75f76b962ceb559ad5` |
| weather-widget | https://github.com/pock/weather-widget | `0b31d04667963d971957d542a4554c83ac9e95c0` |

`control-center-widget` was removed: its features are built into Pock as the `Controls` item (`Pock/UI/TouchBar/BuiltInWidgets`), and installed `ControlCenter.pock` copies are deleted on launch.
