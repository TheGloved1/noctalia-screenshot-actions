--!nonstrict
-- Screenshot Actions — OCR result panel (inline)
-- Editable text area + copy button + translate/search/share actions

local STATE_OCR_RESULT = "ocrResult"
local STATE_OCR_EDIT_TEXT = "ocrEditText"
local STATE_TRANSLATE_RESULT = "translateResult"
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

local function copyText(text)
    if text and text ~= "" then
        noctalia.copyToClipboard(text, "text/plain;charset=utf-8")
    end
end

local function actionButton(glyph, text, onClick, variant)
    return ui.button({
        glyph = glyph,
        text = text,
        controlSize = "sm",
        variant = variant or "default",
        onClick = onClick,
    })
end

local function copyOcrText(text)
    copyText(text)
    noctalia.notifyInfo("Text copied to clipboard")
end

local function render()
    local ocrResult = noctalia.state.get(STATE_OCR_RESULT)
    local editText = noctalia.state.get(STATE_OCR_EDIT_TEXT) or ""
    local translateResult = noctalia.state.get(STATE_TRANSLATE_RESULT)
    local capturePath = ocrResult and ocrResult.capturePath

    local imgW = tonumber(ocrResult and ocrResult.gw) or 0
    local imgH = tonumber(ocrResult and ocrResult.gh) or 0
    local imgHeight = 110
    if imgW > 0 and imgH > 0 then
        imgHeight = math.max(90, math.min(200, math.floor(480 * (imgH / imgW))))
    end

    local body = ui.column({ flexGrow = 1, gap = 10, padding = 16 }, {
        -- Header
        ui.row({ align = "center", gap = 10 }, {
            ui.column({ width = 36, height = 36, radius = 10, fill = "primary/0.15", align = "center", justify = "center" }, {
                ui.glyph({ name = "scan", size = 18, color = "primary" }),
            }),
            ui.label({ text = "Find Text (OCR)", flexGrow = 1, fontSize = 18, fontWeight = "bold", color = "on_surface" }),
            ui.button({
                text = "Clear",
                variant = "ghost",
                controlSize = "sm",
                onClick = function()
                    send("clearResult")
                    panel.close()
                end,
            }),
            ui.button({ glyph = "close", onClick = function() panel.close() end }),
        }),

        -- Image preview (smaller)
        capturePath and capturePath ~= "" and ui.image({
            path = capturePath,
            height = 100,
            fit = "contain",
            radius = 10,
            borderWidth = 1,
            border = "outline",
        }) or nil,

        -- Toolbar
        ui.row({ gap = 6, align = "center" }, {
            actionButton("copy", "Copy All", function() copyOcrText(editText) end, "primary"),
            actionButton("translate", "Translate", function()
                local input = ui.input({
                    key = "translate-input",
                    placeholder = "en",
                    controlSize = "sm",
                    width = 72,
                    onSubmit = function(value) send("translateOcr", { lang = value, text = editText }) end,
                })
                -- Note: inline translate input would need more complex UI, for now use a simple approach
                send("translateOcr", { lang = "en", text = editText })
            end),
            actionButton("search", "Search", function() send("searchOcr", { text = editText }) end),
            actionButton("share", "Share", function() send("shareOcr", editText) end),
            ui.spacer({ flexGrow = 1 }),
        }),

        -- Translation result (if any)
        translateResult and translateResult ~= "" and ui.column({ gap = 6 }, {
            ui.separator({ spacing = 4 }),
            ui.label({ text = "Translation", fontSize = 12, fontWeight = "bold", color = "primary" }),
            ui.label({ text = translateResult, fontSize = 13, color = "on_surface" }),
        }) or nil,

        -- Editable text area
        ui.label({ text = "Recognized Text", fontSize = 12, fontWeight = "bold", color = "on_surface_variant" }),
        ui.column({
            radius = 12,
            borderWidth = 1,
            border = "outline",
            paddingH = 12,
            paddingV = 10,
            flexGrow = 1,
        }, {
            ui.input({
                key = "ocr-edit",
                value = editText,
                multiline = true,
                flexGrow = 1,
                fontSize = 13,
                onChange = function(value)
                    -- Update state as user types
                    noctalia.state.set("ocrEditText", value or "")
                end,
            }),
        }),

        -- URL/Email detection
        (function()
            local text = editText
            local url = text:match("https?://[^%s]+")
            if not url then
                local bare = text:match("www%.[%w%-%.]+[^%s]*")
                if bare then url = "https://" .. bare end
            end
            local email = text:match("[%w%._%%+%-]+@[%w%.%-]+%.[%a][%a]+")
            if url or email then
                return ui.row({ gap = 8, align = "center" }, {
                    url and actionButton("external-link", "Open URL", function()
                        noctalia.runAsync("xdg-open " .. shellQuote(url))
                    end) or nil,
                    email and actionButton("mail", "Compose Email", function()
                        noctalia.runAsync("xdg-open " .. shellQuote("mailto:" .. email))
                    end) or nil,
                })
            end
        end)(),
    })

    panel.render(body)
end

function onOpen(_context)
    render()
end

function onClose()
end

noctalia.state.watch("ocrResult", function(v)
    render()
end)

noctalia.state.watch("ocrEditText", function(v)
    render()
end)

noctalia.state.watch("translateResult", function(v)
    render()
end)