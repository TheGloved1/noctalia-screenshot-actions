--!nonstrict
-- Screenshot Actions — History panel
-- Wallhaven-style browser: pages of 24 screenshots in a scrollable thumbnail
-- grid (native scrollbar, wheel-scrollable) with a chevron pager. Arrow keys
-- move the selection ring; selecting a tile opens the actions panel.

local PANEL_WIDTH = 920
local PANEL_PADDING = 28
local COLUMNS = 4
local PAGE_SIZE = COLUMNS * 4
local COLUMN_GAP = 12
local ROW_GAP = 12
local TILE_RADIUS = 12
local SCREENSHOT_DIR = noctalia.expandPath("~/Pictures/Screenshots")

local shots = {} -- { { path =, name =, mtime = }, ... }
local cursor = 1

local REPEAT_DELAY = 350 -- ms before a held key starts repeating
local REPEAT_INTERVAL = 50 -- ms between repeats
local heldChord = nil
local repeatElapsed = 0

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

-- ── Pagination helpers ──────────────────────────────────────────────────────

local function pageFor(index)
  return math.floor((index - 1) / PAGE_SIZE) + 1
end

local function pageStart(page)
  return (page - 1) * PAGE_SIZE + 1
end

local function pageEnd(page)
  return math.min(page * PAGE_SIZE, #shots)
end

local function totalPages()
  if #shots == 0 then
    return 1
  end
  return math.max(1, math.ceil(#shots / PAGE_SIZE))
end

-- ── Rendering ──────────────────────────────────────────────────────────────

local function columnWidth()
  return math.floor((PANEL_WIDTH - PANEL_PADDING - COLUMN_GAP * (COLUMNS - 1)) / COLUMNS)
end

local function tileSize()
  local width = columnWidth()
  return width, math.floor(width * 9 / 16)
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

  local first = pageStart(pageFor(cursor))
  local last = pageEnd(pageFor(cursor))
  local rows = {}
  local row = {}
  for i = first, last do
    table.insert(row, shotTile(shots[i], i))
    if #row == COLUMNS or i == last then
      table.insert(rows, ui.row({ gap = COLUMN_GAP, align = "stretch" }, row))
      row = {}
    end
  end
  return ui.column({ gap = ROW_GAP, align = "stretch" }, rows)
end

local function pager()
  local page = pageFor(cursor)
  local total = totalPages()
  return ui.row({ align = "center", justify = "center" }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.button({
        key = "prev_page",
        glyph = "chevron-left",
        variant = "ghost",
        onClick = "onPrevPage",
        enabled = page > 1,
      }),
      ui.label({ text = `Page {page} / {total}`, color = "on_surface_variant" }),
      ui.button({
        key = "next_page",
        glyph = "chevron-right",
        variant = "ghost",
        onClick = "onNextPage",
        enabled = page < total,
      }),
    }),
  })
end

local function render()
  local page = pageFor(cursor)
  panel.render(ui.column({ flexGrow = 1, gap = 12, align = "stretch" }, {
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.label({ text = "Screenshot History", fontSize = 16, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
      ui.button({ glyph = "close", onClick = "onClose" }),
    }),

    -- Native scroll container: host-drawn scrollbar and wheel scrolling, same
    -- as the Wallhaven panel. Keyed by page so flipping pages resets to top.
    ui.scroll({ key = `page-{page}`, flexGrow = 1, gap = 12 }, {
      shotGrid(),
    }),

    pager(),
  }))
end

-- ── Key handling ────────────────────────────────────────────────────────────

-- Apply a directional chord. Returns whether the cursor actually moved.
local function moveFor(chord)
  if #shots == 0 then
    return false
  end
  local nextCursor = nil
  if chord == "Right" or chord == "ctrl+l" then
    nextCursor = math.min(cursor + 1, #shots)
  elseif chord == "Left" or chord == "ctrl+h" then
    nextCursor = math.max(cursor - 1, 1)
  elseif chord == "Down" or chord == "ctrl+j" then
    nextCursor = math.min(cursor + COLUMNS, #shots)
  elseif chord == "Up" or chord == "ctrl+k" then
    nextCursor = math.max(cursor - COLUMNS, 1)
  end
  if nextCursor == nil or nextCursor == cursor then
    return false
  end
  cursor = nextCursor
  return true
end

local function isDirectional(chord)
  return chord == "Right" or chord == "Left" or chord == "Down" or chord == "Up"
    or chord == "ctrl+l" or chord == "ctrl+h" or chord == "ctrl+j" or chord == "ctrl+k"
end

function onKey(chord, pressed)
  if not pressed then
    if isDirectional(chord) and chord == heldChord then
      heldChord = nil
      repeatElapsed = 0
    end
    return
  end

  if chord == "Return" or chord == "Enter" or chord == "Space" then
    if #shots > 0 then
      openShot(shots[cursor])
    end
    return
  end

  if moveFor(chord) then
    render()
  end
  if isDirectional(chord) then
    heldChord = chord
    repeatElapsed = 0
  end
end

function onFrameTick(deltaMs)
  if heldChord == nil then
    return
  end
  repeatElapsed += deltaMs
  local moved = false
  while repeatElapsed >= REPEAT_DELAY do
    if moveFor(heldChord) then
      moved = true
    end
    repeatElapsed -= REPEAT_INTERVAL
    if repeatElapsed < REPEAT_DELAY then
      break
    end
  end
  if moved then
    render()
  end
end

-- ── Callbacks ──────────────────────────────────────────────────────────────

function onOpen(_context)
  loadShots()
  cursor = 1
  heldChord = nil
  repeatElapsed = 0
  panel.setNeedsFrameTick(true)
  render()
end

function onClose()
  panel.close()
end

function onPrevPage()
  local page = pageFor(cursor) - 1
  if page < 1 then
    return
  end
  cursor = math.min(pageStart(page), #shots)
  render()
end

function onNextPage()
  local page = pageFor(cursor) + 1
  if page > totalPages() then
    return
  end
  cursor = pageStart(page)
  render()
end

-- Refresh the grid when a new capture lands while the panel is open.
noctalia.state.watch("lastCapture", function(_)
  loadShots()
  if cursor > #shots then cursor = #shots end
  render()
end)