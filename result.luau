--!nonstrict
-- Screenshot Actions — OCR result panel

local STATE_OCR_RESULT = "ocrResult"

local function shellQuote(value)
    return "'" .. tostring(value):gsub("'", [["'"']]) .. "'"
end

local function copyText(text)
    if text and text ~= "" then
        noctalia.copyToClipboard(text, "text/plain;charset=utf-8")
    end
end

local function render()
    local ocrResult = noctalia.state.get(STATE_OCR_RESULT)
    local text = ocrResult and ocrResult.text or ""
    local capturePath = ocrResult and ocrResult.capturePath

    local body = ui.column({ flexGrow = 1, gap = 10, padding = 16 }, {
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
                    noctalia.state.set("ocrResult", nil)
                    noctalia.state.set("ocrEditText", "")
                    noctalia.state.set("activeTool", nil)
                    panel.close()
                end,
            }),
            ui.button({ glyph = "close", onClick = function() panel.close() end }),
        }),

        -- Image preview
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
            ui.button({
                text = "Copy",
                glyph = "copy",
                controlSize = "sm",
                variant = "primary",
                onClick = function()
                    copyText(text)
                end,
            }),
            ui.button({
                text = "Search",
                glyph = "search",
                controlSize = "sm",
                variant = "default",
                onClick = function()
                    local url = "https://duckduckgo.com/?q="
                    local enc = text:gsub(" ", "+"):gsub("([^%w+_.~-])", function(c)
                        return string.format("%%%02X", string.byte(c))
                    end)
                    noctalia.runAsync("xdg-open " .. shellQuote(url .. enc))
                end,
            }),
            ui.spacer({ flexGrow = 1 }),
        }),

        -- Selectable text preview
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
                key = "ocr-preview",
                value = text,
                multiline = true,
                flexGrow = 1,
                fontSize = 13,
                frameVisible = true,
            }),
        }),

        -- URL/Email detection
        (function()
            local url = text:match("https?://[^%s]+")
            if not url then
                local bare = text:match("www%.[%w%-%.]+[^%s]*")
                if bare then url = "https://" .. bare end
            end
            local email = text:match("[%w%._%%+%-]+@[%w%.%-]+%.[%a][%a]+")
            if url or email then
                return ui.row({ gap = 8, align = "center" }, {
                    url and ui.button({
                        text = "Open URL",
                        glyph = "external-link",
                        controlSize = "sm",
                        variant = "default",
                        onClick = function()
                            noctalia.runAsync("xdg-open " .. shellQuote(url))
                        end,
                    }) or nil,
                    email and ui.button({
                        text = "Email",
                        glyph = "mail",
                        controlSize = "sm",
                        variant = "default",
                        onClick = function()
                            noctalia.runAsync("xdg-open " .. shellQuote("mailto:" .. email))
                        end,
                    }) or nil,
                })
            end
            return nil
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