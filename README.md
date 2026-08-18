# Screenshot Actions

A Noctalia v5 plugin for region screenshots with a quick action menu: open the
capture in Swappy for annotation, copy it to the clipboard, or run OCR to find
text in the image — plus a paged, keyboard-navigable history browser of past
captures.

## Plugin

| Field | Value |
| --- | --- |
| ID | `gloves/screenshot-actions` |
| Entries | Panels: `actions` (action menu), `ocr-result` (OCR text view), `history` (capture browser); service: `service` |

## Requirements

Install the tools used by the features you want on `PATH`. Missing tools are
reported when that feature is started.

- **`slurp`** — region selection
- **`grim`** — screen capture
- **`wl-copy`** — copy the capture to the clipboard
- **`notify-send`** — capture notifications
- **`swappy`** — annotation editor (**Open** action)
- **`tesseract`** — OCR engine (plus your language packs, e.g. `tesseract-data-eng`)

Optional:

- **`wayfreeze`** — freezes the screen so region selection happens over a static frame
- **`paplay`** / **`pw-play`** — capture shutter sound

## Usage

Start a region capture from any keybind or script:

```sh
noctalia msg plugin gloves/screenshot-actions:service all capture
```

After a capture, the **actions panel** opens with a preview and three actions:

- **Copy** — copies the image to the clipboard.
- **Open** — opens the capture in `swappy` for markup/annotation. Saving happens
  in that editor.
- **Find Text** — runs `tesseract` OCR on the capture and opens the
  **OCR result panel** with the recognized text in an editable multiline area,
  so you can correct, trim, or extend it before copying or searching. Detected
  URLs can be opened directly and detected email addresses can open a mail
  composer. **Back** returns to the actions panel without clearing the result.

The **history panel** browses past captures as a thumbnail grid (Wallhaven-style
pages of 24). Arrow keys or `ctrl+h/j/k/l` move the selection ring — holding a
key repeats — and `Enter`/`Space` (or clicking a tile) opens that capture in the
actions panel. The panel refreshes when a new capture lands.

Open the history panel:

```sh
noctalia msg panel-toggle gloves/screenshot-actions:history
```

Open the action menu (last capture):

```sh
noctalia msg panel-toggle gloves/screenshot-actions:actions
```

Captures are saved to `~/Pictures/Screenshots` and copied to the clipboard, and
a capture sound plays when `paplay`/`pw-play` is available.

## Settings

All settings live in Settings → Plugins (gear on the plugin's row).

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `panel-placement` | `select` | `floating` | How the panels appear: `floating` or `attached`. |
| `panel-along-bar` | `select` | `centered` | Where the panel sits along the bar: `centered` or `near-trigger`. |

## IPC

The service is a singleton with no output, so the IPC target is `all`:

```sh
# Start a region capture
noctalia msg plugin gloves/screenshot-actions:service all capture
```

For example, bind it to `SUPER+SHIFT+S` in Hyprland's Lua config:

```lua
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("noctalia msg plugin gloves/screenshot-actions:service all capture"))
```

Summary of every service command:

| Command | Payload | Action |
| --- | --- | --- |
| `capture` | — | Select a region and save the screenshot |

## Notes

- The `capture` IPC opens the action menu automatically when a capture finishes
  (and is cancelled if the selection is dismissed).
- The history grid is read from `~/Pictures/Screenshots`; only non-empty PNG
  files are listed, newest first. The action menu works with any capture path
  set in the plugin's shared `lastCapture` state.
- Captures are transient: they live in your screenshot directory, not in the
  plugin's data directory.
