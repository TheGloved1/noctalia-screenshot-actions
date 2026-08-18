--!nonstrict
-- Screenshot Actions — Main action menu

local STATE_LAST_CAPTURE = "lastCapture"

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
        ui.row({ align = "center", gap = 10 }, {
            ui.glyph({ name = "crosshair", size = 20, color = "primary" }),
            ui.label({ text = "Screenshot Actions", flexGrow = 1, fontSize = 18, fontWeight = "bold", color = "on_surface" }),
            ui.button({
                glyph = "close",
                onClick = function() panel.close() end,
            }),
        }),

        ui.column({ align = "center", justify = "center", gap = 8 }, {
            hasImage and ui.image({
                path = capturePath,
                height = 160,
                fit = "contain",
                radius = 12,
                borderWidth = 1,
                border = "outline",
                width = 320,
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

        ui.row({ align = "center", gap = 12 }, {
            ui.button({
                text = "Open in Swappy",
                glyph = "pencil",
                flexGrow = 1,
                controlSize = "lg",
                variant = "primary",
                onClick = function()
                    local path = noctalia.state.get(STATE_LAST_CAPTURE)
                    if not path or path == "" then return end
                    if noctalia.commandExists("swappy") then
                        noctalia.runAsync("swappy -f - < " .. shellQuote(path))
                    else
                        noctalia.notifyError("swappy not installed")
                    end
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
                    if not path or path == "" then return end
                    if not noctalia.commandExists("tesseract") then
                        noctalia.notifyError("tesseract not installed")
                        return
                    end
                    local lang = getConfig("ocr-language", "eng")
                    local cmd = "tesseract " .. shellQuote(path) .. " stdout -l " .. shellQuote(lang) .. " 2>/dev/null"
                    noctalia.runAsync(cmd, function(result)
                        if not result or result.exitCode ~= 0 then
                            noctalia.notifyError("tesseract failed")
                            return
                        end
                        local text = result.stdout or ""
                        text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\n%s*\n", "\n")
                        if text == "" then
                            noctalia.notifyError("No text detected")
                            return
                        end
                        noctalia.state.set("ocrResult", { text = text, capturePath = path })
                        noctalia.state.set("ocrEditText", text)
                        noctalia.state.set("translateResult", "")
                        noctalia.state.set("activeTool", "ocr")
                        noctalia.togglePanel("gloves/screenshot-actions:ocr-result")
                    end)
                end,
            }),
        }),

        ui.label({
            text = "Screenshot saved to clipboard and ~/Pictures/Screenshots",
            fontSize = 10,
            color = "on_surface_variant",
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