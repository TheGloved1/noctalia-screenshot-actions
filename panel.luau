--!nonstrict
-- Screenshot Actions — Main action menu
-- Image preview + two buttons: "Open in Swappy" and "Find Text"

local STATE_LAST_CAPTURE = "lastCapture"
local STATE_ACTIVE_TOOL = "activeTool"

local function tr(key, subst)
    if subst then return noctalia.tr(key, subst) end
    return noctalia.tr(key)
end

local function send(action, payload)
    noctalia.state.set("command", { action = action, payload = payload })
end

local function shellQuote(value)
    return "'" .. tostring(value):gsub("'", [["'"']]) .. "'"
end

local function getConfig(key, default)
    local v = noctalia.getConfig(key)
    if v == nil then return default end
    return v
end

local function render()
    local capturePath = noctalia.state.get(STATE_LAST_CAPTURE)

    local hasImage = capturePath and capturePath ~= "" and noctalia.fileExists and noctalia.fileExists(capturePath)

    local body = ui.column({ flexGrow = 1, gap = 10, padding = 16 }, {
        -- Header
        ui.row({ align = "center", gap = 10 }, {
            ui.glyph({ name = "crosshair", size = 20, color = "primary" }),
            ui.label({ text = "Screenshot Actions", flexGrow = 1, fontSize = 18, fontWeight = "bold", color = "on_surface" }),
            ui.button({
                glyph = "close",
                onClick = function() panel.close() end,
            }),
        }),

        -- Image preview
        ui.column({ align = "center", justify = "center", gap = 8 }, {
            hasImage and ui.image({
                path = capturePath,
                height = 180,
                fit = "contain",
                radius = 12,
                borderWidth = 1,
                border = "outline",
            }) or ui.column({
                align = "center",
                justify = "center",
                height = 180,
                flexGrow = 1,
            }, {
                ui.glyph({ name = "image", size = 48, color = "outline" }),
                ui.label({ text = "No capture yet", fontSize = 14, color = "on_surface_variant" }),
            }),
            hasImage and ui.label({
                text = capturePath:match("([^/]+)$") or capturePath,
                fontSize = 11,
                color = "on_surface_variant",
                maxWidth = 400,
            }) or nil,
        }),

        -- Action buttons
        ui.row({ align = "center", gap = 12 }, {
            ui.button({
                text = "Open in Swappy",
                glyph = "pencil",
                flexGrow = 1,
                controlSize = "lg",
                variant = "primary",
                onClick = function()
                    local path = noctalia.state.get(STATE_LAST_CAPTURE)
                    send("openSwappy", path)
                    panel.close()
                end,
            }),
            ui.button({
                text = "Find Text",
                glyph = "scan",
                flexGrow = 1,
                controlSize = "lg",
                variant = "default",
                onClick = function()
                    local path = noctalia.state.get(STATE_LAST_CAPTURE)
                    send("runOcr", path)
                    panel.close()
                end,
            }),
        }),

        -- Hint
        ui.label({
            text = "Screenshot already saved to clipboard and ~/Pictures/Screenshots",
            fontSize = 10,
            color = "muted",
            textAlign = "center",
        }),
    })

    panel.render(body)
end

function onOpen(_context)
    render()
end

function onClose()
end

noctalia.state.watch(STATE_LAST_CAPTURE, function(v)
    render()
end)