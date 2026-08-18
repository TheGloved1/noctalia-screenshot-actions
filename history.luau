--!nonstrict
-- Screenshot Actions — History panel
-- Browse past screenshots as a thumbnail grid (wallpaper-switcher layout).
-- Selecting a tile loads it into the actions panel. The grid renders only the
-- visible window of shots; arrow keys move the cursor and slide the window one
-- row at a time so the selection is never hidden.

local PANEL_WIDTH = 720
local PANEL_PADDING = 28
local COLUMNS = 4
local ROWS_VISIBLE = 3
local VISIBLE = COLUMNS * ROWS_VISIBLE
local COLUMN_GAP = 12
local ROW_GAP = 12
local TILE_RADIUS = 12
local SCROLLBAR_WIDTH = 6
local SCREENSHOT_DIR = noctalia.expandPath("~/Pictures/Screenshots")

local shots = {} -- { { path =, name =, mtime = }, ... }
local cursor = 1
local windowStart = 1

local function extensionOf(name)
  local ext = name:match("%.([%a%d]+)$")
  return ext and ext:lower() or ""
end

-- ── Loading ──────────────────────────────────────────────────────────────

local function loadShots()
  shots = {}
  local entries = noctalia.listDir(SCREENSHOT_DIR)
  if type(entries) ~= "table" then
    return
  end
  for _, name in ipairs(entries) do
    if extensionOf(name) == "png" then
      local path = SCREENSHOT_DIR .. "/" .. name
      local info = noctalia.fileInfo(path)
      if info and info.size and info.size > 0 then
        table.insert(shots, { path = path, name = name, mtime = info.mtime or 0 })
      end
    end
  end
  table.sort(shots, function(a, b)
    if a.mtime ~= b.mtime then return a.mtime > b.mtime end
    return a.name > b.name
  end)
end

-- ── Actions ────────────────────────────────────────────────────────────────

local function openShot(shot)
  noctalia.state.set("lastCapture", shot.path)
  panel.close()
  noctalia.togglePanel("gloves/screenshot-actions:actions")
end

-- ── Window/cursor bookkeeping ──────────────────────────────────────────────

local function clampCursor()
  if #shots == 0 then
    cursor = 0
    windowStart = 1
    return
  end
  if cursor < 1 then cursor = 1 end
  if cursor > #shots then cursor = #shots end
end

-- Keep the cursor inside the visible window; when it leaves, slide the window
-- so it re-enters at the opposite edge (scrolls the grid exactly one row).
local function alignWindow()
  if #shots == 0 then
    windowStart = 1
    return
  end
  windowStart = math.max(1, math.min(windowStart, #shots))
  if cursor < windowStart then
    windowStart = cursor
  elseif cursor > windowStart + VISIBLE - 1 then
    windowStart = cursor - (VISIBLE - COLUMNS)
  end
  windowStart = math.max(1, math.min(windowStart, #shots))
end

local function moveCursor(next)
  cursor = next
  clampCursor()
  alignWindow()
end

-- ── Rendering ──────────────────────────────────────────────────────────────

local function columnWidth()
  local reserved = 0
  if #shots > VISIBLE then
    reserved = SCROLLBAR_WIDTH + 12
  end
  return math.floor(((PANEL_WIDTH - PANEL_PADDING - reserved) - COLUMN_GAP * (COLUMNS - 1)) / COLUMNS)
end

local function tileSize()
  local width = columnWidth()
  return width, 100
end

local function shotTile(shot, index)
  local frameWidth, frameHeight = tileSize()
  local isCursor = index == cursor
  local isLast = shot.path == noctalia.state.get("lastCapture")

  local border = "outline"
  local borderWidth = 1
  if isCursor then
    border = "primary"
    borderWidth = 3
  elseif isLast then
    border = "secondary"
    borderWidth = 2
  end

  return ui.column({ key = shot.path, gap = 4, flexGrow = 1, align = "center" }, {
    ui.image({
      width = frameWidth,
      height = frameHeight,
      path = shot.path,
      fit = "cover",
      radius = TILE_RADIUS,
      border = border,
      borderWidth = borderWidth,
      onClick = function()
        cursor = index
        openShot(shot)
      end,
    }),
    ui.label({
      text = shot.name,
      fontSize = 11,
      color = isCursor and "primary" or (isLast and "secondary" or "on_surface_variant"),
      maxLines = 1,
      maxWidth = frameWidth,
      textAlign = "center",
    }),
  })
end

local function shotGrid()
  if #shots == 0 then
    return ui.column({ flexGrow = 1, gap = 8, align = "center", paddingV = 48 }, {
      ui.glyph({ name = "photo-off", size = 40, color = "outline" }),
      ui.label({ text = "No screenshots yet", fontSize = 14, color = "on_surface_variant" }),
    })
  end

  local rows = {}
  local row = {}
  local last = math.min(windowStart + VISIBLE - 1, #shots)
  for i = windowStart, last do
    table.insert(row, shotTile(shots[i], i))
    if #row == COLUMNS or i == last then
      table.insert(rows, ui.row({ gap = COLUMN_GAP, align = "stretch" }, row))
      row = {}
    end
  end
  return ui.column({ flexGrow = 1, gap = ROW_GAP, align = "stretch" }, rows)
end

local function scrollbar()
  if #shots <= VISIBLE then
    return nil
  end
  local frac = (windowStart - 1) / math.max(1, #shots - VISIBLE)
  local thumb = math.max(VISIBLE / #shots, 0.06)
  frac = math.max(0, math.min(frac, 1 - thumb))
  return ui.column({ width = 6, radius = 3, fill = "surface_variant", align = "stretch" }, {
    ui.spacer({ flexGrow = frac }),
    ui.box({ width = 6, radius = 3, fill = "on_surface_variant", flexGrow = thumb }),
    ui.spacer({ flexGrow = math.max(0, 1 - frac - thumb) }),
  })
end

local function render()
  panel.render(ui.column({ flexGrow = 1, gap = 12, align = "stretch" }, {
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.label({ text = "Screenshot History", fontSize = 16, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
      ui.button({ glyph = "close", onClick = "onClose" }),
    }),

    ui.row({ flexGrow = 1, gap = 12, align = "stretch" }, {
      shotGrid(),
      scrollbar(),
    }),
  }))
end

-- ── Key handling ────────────────────────────────────────────────────────────

function onKey(chord, pressed)
  if not pressed or #shots == 0 then
    return
  end

  if chord == "Right" or chord == "ctrl+l" then
    moveCursor(cursor + 1)
  elseif chord == "Left" or chord == "ctrl+h" then
    moveCursor(cursor - 1)
  elseif chord == "Down" or chord == "ctrl+j" then
    moveCursor(cursor + COLUMNS)
  elseif chord == "Up" or chord == "ctrl+k" then
    moveCursor(cursor - COLUMNS)
  elseif chord == "Return" or chord == "Enter" or chord == "Space" then
    openShot(shots[cursor])
    return
  else
    return
  end
  render()
end

-- ── Callbacks ──────────────────────────────────────────────────────────────

function onOpen(_context)
  loadShots()
  cursor = 1
  clampCursor()
  alignWindow()
  render()
end

function onClose()
  panel.close()
end

-- Refresh the grid when a new capture lands while the panel is open.
noctalia.state.watch("lastCapture", function(_)
  loadShots()
  clampCursor()
  alignWindow()
  render()
end)