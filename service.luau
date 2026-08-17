--!nonstrict
-- Screenshot Actions — Headless capture service
-- Coordinates region capture, manages state, opens panels

local CAPTURE_SCRIPT = debug.getinfo(1, "S").source:match("@?(.*/)") .. "scripts/capture.sh"

-- State keys
local STATE_LAST_CAPTURE = "lastCapture"
local STATE_OCR_RESULT = "ocrResult"
local STATE_OCR_EDIT_TEXT = "ocrEditText"
local STATE_TRANSLATE_RESULT = "translateResult"
local STATE_ACTIVE_TOOL = "activeTool"

local function getConfig(key, default)
    local v = noctalia.getConfig(key)
    if v == nil then return default end
    return v
end

local function shellQuote(value)
    return "'" .. tostring(value):gsub("'", [["'"']]) .. "'"
end

local function copyText(text)
    if text and text ~= "" then
        noctalia.copyToClipboard(text, "text/plain;charset=utf-8")
    end
end

local function runCapture()
    local screenshotDir = getConfig("screenshot-path", "~/Pictures/Screenshots")
    local filenameFormat = getConfig("filename-format", "%Y-%b_%H-%M-%S")
    local ocrLang = getConfig("ocr-language", "eng")

    -- Expand tilde
    screenshotDir = screenshotDir:gsub("^~", os.getenv("HOME") or "")

    local env = {
        SCREENSHOT_DIR = screenshotDir,
        FILENAME_FORMAT = filenameFormat,
        OCR_LANGUAGE = ocrLang,
        XDG_RUNTIME_DIR = os.getenv("XDG_RUNTIME_DIR"),
        WAYLAND_DISPLAY = os.getenv("WAYLAND_DISPLAY"),
        PATH = os.getenv("PATH"),
        HOME = os.getenv("HOME"),
    }

    -- Run capture script asynchronously
    local cmd = CAPTURE_SCRIPT
    local handle = io.popen(cmd, "r")
    if not handle then
        noctalia.notifyError("Failed to run capture script")
        return
    end

    local output = handle:read("*a")
    local success = handle:close()

    if not success then
        -- Capture failed or cancelled
        return
    end

    local path = output:match("^%s*(.-)%s*$")
    if path and path ~= "" and path ~= "cancelled" then
        -- Save capture path to state
        noctalia.state.set(STATE_LAST_CAPTURE, path)
        noctalia.state.set(STATE_ACTIVE_TOOL, "screenshot")

        -- Open actions panel
        panel.open("user/screenshot-actions:actions")
    end
end

local function openInSwappy(path)
    if not path or path == "" then
        noctalia.notifyError("No capture to open")
        return
    end
    if noctalia.commandExists("swappy") then
        noctalia.runAsync("swappy -f - < " .. shellQuote(path))
    else
        noctalia.notifyError("swappy not installed")
    end
end

local function runOcr(path)
    if not path or path == "" then
        noctalia.notifyError("No capture to OCR")
        return
    end
    if not noctalia.commandExists("tesseract") then
        noctalia.notifyError("tesseract not installed")
        return
    end

    local ocrLang = getConfig("ocr-language", "eng")
    local cmd = "tesseract " .. shellQuote(path) .. " stdout -l " .. shellQuote(ocrLang) .. " 2>/dev/null"
    local handle = io.popen(cmd, "r")
    if not handle then
        noctalia.notifyError("Failed to run tesseract")
        return
    end

    local text = handle:read("*a") or ""
    handle:close()

    text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\n%s*\n", "\n")
    if text == "" then
        noctalia.notifyError("No text detected")
        return
    end

    -- Store OCR result for result panel
    noctalia.state.set(STATE_OCR_RESULT, { text = text, capturePath = path })
    noctalia.state.set(STATE_OCR_EDIT_TEXT, text)
    noctalia.state.set(STATE_TRANSLATE_RESULT, "")
    noctalia.state.set(STATE_ACTIVE_TOOL, "ocr")

    -- Open OCR result panel
    panel.open("user/screenshot-actions:ocr-result")
end

local function clearResult()
    noctalia.state.set(STATE_OCR_RESULT, nil)
    noctalia.state.set(STATE_OCR_EDIT_TEXT, "")
    noctalia.state.set(STATE_TRANSLATE_RESULT, "")
end

-- Command handler (called from panels via state.set("command", ...))
function onCommand(cmd)
    if not cmd or not cmd.action then return end
    local action = cmd.action
    local payload = cmd.payload

    if action == "capture" then
        runCapture()
    elseif action == "openSwappy" then
        local path = payload or noctalia.state.get(STATE_LAST_CAPTURE)
        openInSwappy(path)
    elseif action == "runOcr" then
        local path = payload or noctalia.state.get(STATE_LAST_CAPTURE)
        runOcr(path)
    elseif action == "copyOcrText" then
        local text = payload or noctalia.state.get(STATE_OCR_EDIT_TEXT)
        copyText(text)
    elseif action == "translateOcr" then
        local lang = payload and payload.lang or "en"
        local text = payload and payload.text or noctalia.state.get(STATE_OCR_EDIT_TEXT)
        if text and text ~= "" then
            local cmd = "trans -b " .. shellQuote(lang) .. " " .. shellQuote(text) .. " 2>/dev/null"
            local handle = io.popen(cmd, "r")
            if handle then
                local result = handle:read("*a") or ""
                handle:close()
                if result ~= "" then
                    noctalia.state.set(STATE_TRANSLATE_RESULT, result)
                end
            end
        end
    elseif action == "searchOcr" then
        local text = payload and payload.text or noctalia.state.get(STATE_OCR_EDIT_TEXT)
        if text and text ~= "" then
            local searchUrl = getConfig("search-engine-url", "https://duckduckgo.com/?q=")
            if searchUrl == "" then searchUrl = "https://duckduckgo.com/?q=" end
            local encoded = text:gsub(" ", "+"):gsub("([^%w+_.~-])", function(c) return string.format("%%%02X", string.byte(c)) end)
            noctalia.runAsync("xdg-open " .. shellQuote(searchUrl .. encoded))
        end
    elseif action == "shareOcr" then
        local path = payload or noctalia.state.get(STATE_LAST_CAPTURE)
        if path and path ~= "" then
            -- Could add share upload here (uguu.se, etc.)
            noctalia.notifyError("Share not implemented yet")
        end
    elseif action == "clearResult" then
        clearResult()
        panel.close()
    end
end

-- Watch for commands from panels
noctalia.state.watch("command", function(v)
    if v and type(v) == "table" then
        onCommand(v)
    end
end)

-- Auto-capture on service start if requested (for keybind convenience)
function onStart()
    -- Service starts on-demand via plugin command
end