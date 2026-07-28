# tidbyt-custom-apps

Custom Pixlet apps for the Coldaine Tronbyt server (`http://192.168.30.202:8000`).

Point Tronbyt **Settings → Content → App Repo URL** at:

`https://github.com/MooseGooseConsulting/tidbyt-custom-apps.git`

Then **Refresh** the user repo. Apps under `apps/` appear in Add App alongside the system catalog.

## Apps

| App | Package | Notes |
|---|---|---|
| Moose Ticker | `mooseticker` | Neon watchlist cards + Yahoo sparklines, no API key |

## Iterate

1. Edit `apps/<name>/<name>.star`
2. Commit and push to `main` (default branch only — Tronbyt shallow-clones it)
3. In Tronbyt UI: Settings → Content → Refresh
4. Re-open the app config (or wait for the next render interval) and check the panel

Local authoring (optional): install [pixlet](https://github.com/tidbyt/pixlet/releases), then `pixlet check` / `pixlet render` / `pixlet serve`.

## Layout

```
apps/
  mooseticker/
    mooseticker.star
    manifest.yaml
    mooseticker.webp
```
