# Default widget sources

Vendored MIT-licensed sources from the upstream Pock organization. License files remain in each directory. Local changes remove automatic install phases, clear the upstream signing team, and align deployment targets. The root Podfile resolves shared dependencies for all widgets.

| Source | Repository | Imported commit |
|---|---|---|
| esc-widget | https://github.com/pock/esc-widget | `811ccdf3df56cc67fc94644727ebe2f74c3346c6` |
| now-playing-widget | https://github.com/pock/now-playing-widget | `156276f31daead703d033704157b70be65f44ea8` |
| weather-widget | https://github.com/pock/weather-widget | `0b31d04667963d971957d542a4554c83ac9e95c0` |

`control-center-widget` was removed: its features are built into Pock as the `Controls` item (`Pock/UI/TouchBar/BuiltInWidgets`), and installed `ControlCenter.pock` copies are deleted on launch.

`status-widget` was removed: it is built into Pock as the `Status` item (`StatusTouchBarItem`), reading the same preference keys, and installed `Status.pock` copies are deleted on launch.

`dock-widget` was removed: it is built into Pock as the `Dock` item (`DockTouchBarItem`), keeping the widget's display preference keys, and installed `Dock.pock` copies are deleted on launch.
