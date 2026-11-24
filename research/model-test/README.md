# Model tests on phones (2026-11-23 / 24)

- `log_before.txt`, `*.png` (top level): Pixel 9 run on main before the rebuild (2026-11-23).
- `after/`: Pixel 9 run on `agent/rebuild` (2026-11-24), `log.txt`; driver scripts `drive.sh`, `ask.sh`, `batch.sh`.
- `redmi/`: Mi 9T Pro (Snapdragon 855, 6 GB, minimum device) runs: `log.txt`, `final_log.txt`, RAM samples.
- `sprint/`: report (`raport.html`, published as an artifact) and 3x-speed screen recordings of both phones.
- `raport.html` (top level): first diagnosis report (2026-11-23).

Scripts drive the real app over adb (uiautomator). Always run integration tests with `--no-uninstall`.
