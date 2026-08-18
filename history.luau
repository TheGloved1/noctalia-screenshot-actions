--!nonstrict
-- Screenshot Actions — History panel
-- Browse past screenshots as a thumbnail grid (wallpaper-switcher layout).
-- Selecting a tile loads it into the actions panel.

local PANEL_WIDTH = 720
local PANEL_PADDING = 28
local COLUMNS = 3
local COLUMN_GAP = 12
local PAGE_SIZE = 12
local TILE_RADIUS = 12
local SCREENSHOT_DIR = noctalia.expandPath("~/Pictures/Screenshots")

local shots = {} -- { { path =, name =, mtime = }, ... }
local page = 1
local cursor = 0 -- keyboard cursor, 1-based index into shots; 0 = none
local render

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
  page = 1
end

local function clampCursor()
  if #shots == 0 then
    cursor = 0
  elseif cursor < 1 then
    cursor = 1
  elseif cursor > #shots then
    cursor = #shots
  end
end

-- ── Actions ────────────────────────────────────────────────────────────────

local function openShot(shot)
  noctalia.state.set("lastCapture", shot.path)
  panel.close()
  noctalia.togglePanel("gloves/screenshot-actions:actions")
end

-- ── Rendering ──────────────────────────────────────────────────────────────

local function totalPages()
  return math.max(1, math.ceil(#shots / PAGE_SIZE))
end

local function columnWidth()
  return math.floor(((PANEL_WIDTH - PANEL_PADDING) - COLUMN_GAP * (COLUMNS - 1)) / COLUMNS)
end

local function tileSize()
  local width = columnWidth()
  return width, math.floor(width * 9 / 16)
end

local function shotTile(shot, index)
  local frameWidth, frameHeight = tileSize()
  local isCursor = index == cursor
  local isLast = shot.path == noctalia.state.get("lastCapture")

  local border, borderWidth, accent
  if isCursor then
    border, borderWidth, accent = "primary", 3, "primary"
  elseif isLast then
    border, borderWidth, accent = "secondary", 2, "secondary"
  else
    border, borderWidth, accent = "outline", 1, "on_surface_variant"
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
      color = accent,
      maxLines = 1,
      maxWidth = frameWidth,
      textAlign = "center",
    }),
  })
end

local function shotGrid()
  if #shots == 0 then
    return ui.column({ gap = 8, align = "center", paddingV = 48 }, {
      ui.glyph({ name = "photo-off", size = 40, color = "outline" }),
      ui.label({ text = "No screenshots yet", fontSize = 14, color = "on_surface_variant" }),
    })
  end

  local first = (page - 1) * PAGE_SIZE + 1
  local last = math.min(first + PAGE_SIZE - 1, #shots)
  local rows = {}
  local row = {}
  for i = first, last do
    table.insert(row, shotTile(shots[i], i))
    if #row == COLUMNS or i == last then
      table.insert(rows, ui.row({ gap = COLUMN_GAP, align = "stretch" }, row))
      row = {}
    end
  end
  return ui.column({ gap = 12, align = "stretch" }, rows)
end

render = function()
  panel.render(ui.column({ flexGrow = 1, gap = 12, align = "stretch" }, {
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.label({ text = "Screenshot History", fontSize = 16, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
      ui.button({ glyph = "close", onClick = "onClose" }),
    }),

    ui.scroll({ flexGrow = 1, gap = 12 }, {
      shotGrid(),
    }),

    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.button({ glyph = "chevron-left", variant = "ghost", onClick = "onPrevPage", enabled = page > 1 }),
      ui.label({ text = tostring(page) .. " / " .. tostring(totalPages()), color = "on_surface_variant" }),
      ui.button({ glyph = "chevron-right", variant = "ghost", onClick = "onNextPage", enabled = page < totalPages() }),
    }),
  }))
end

-- ── Callbacks ──────────────────────────────────────────────────────────────

function onOpen(_context)
  loadShots()
  local last = noctalia.state.get("lastCapture")
  cursor = 0
  for i, shot in ipairs(shots) do
    if shot.path == last then
      cursor = i
      break
    end
  end
  clampCursor()
  page = math.max(1, math.floor((cursor - 1) / PAGE_SIZE) + 1)
  render()
end

function onClose()
  panel.close()
end

function onKey(chord, pressed)
  if not pressed or #shots == 0 then
    return
  end
  if chord == "Right" then
    cursor = math.min(cursor + 1, #shots)
  elseif chord == "Left" then
    cursor = math.max(cursor - 1, 1)
  elseif chord == "Down" then
    cursor = math.min(cursor + COLUMNS, #shots)
  elseif chord == "Up" then
    cursor = math.max(cursor - COLUMNS, 1)
  elseif chord == "Return" or chord == "Enter" or chord == "Space" then
    if cursor > 0 then
      openShot(shots[cursor])
    end
    return
  else
    return
  end
  page = math.floor((cursor - 1) / PAGE_SIZE) + 1
  render()
end

function onPrevPage()
  if page > 1 then
    page -= 1
    render()
  end
end

function onNextPage()
  if page < totalPages() then
    page += 1
    render()
  end
end

-- Refresh the grid when a new capture lands while the panel is open.
noctalia.state.watch("lastCapture", function(_)
  loadShots()
  clampCursor()
  page = math.max(1, math.floor((cursor - 1) / PAGE_SIZE) + 1)
  render()
end)