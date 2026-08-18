--!nonstrict
local CPS = "/home/gloves/.local/share/noctalia/plugins/screenshot-actions/scripts/capture.sh"

function onIpc(ev, pl)
  if ev == "capture" then runCapture() end
end

function runCapture()
  local home = os.getenv("HOME") or "/home/gloves"
  local dir = home .. "/Pictures/Screenshots"
  local env = "SCREENSHOT_DIR=" .. dir .. " HOME=" .. home
  local cmd = env .. " " .. CPS
  local ok = noctalia.runAsync(cmd, function(r)
    if not r or r.exitCode ~= 0 then return end
    local p = (r.stdout or ""):match("^%s*(.-)%s*$")
    if p and p ~= "" and p ~= "cancelled" then
      noctalia.state.set("lastCapture", p)
      noctalia.togglePanel("gloves/screenshot-actions:actions")
    end
  end)
  if not ok then noctalia.notifyError("Screenshot", "launch failed") end
end

function doOcr(path)
  if not path or path == "" then
    noctalia.notifyError("No capture for OCR")
    return
  end
  if not noctalia.commandExists("tesseract") then
    noctalia.notifyError("tesseract not installed")
    return
  end
  local h = io.popen("tesseract " .. path .. " stdout -l eng 2>/dev/null", "r")
  if not h then
    noctalia.notifyError("tesseract failed")
    return
  end
  local t = h:read("*a") or ""
  h:close()
  t = t:gsub("^%s+", ""):gsub("%s+$", "")
  if t == "" then
    noctalia.notifyError("No text detected")
    return
  end
  noctalia.state.set("ocrResult", { text = t, capturePath = path })
  noctalia.state.set("ocrEditText", t)
  noctalia.state.set("translateResult", "")
  noctalia.state.set("activeTool", "ocr")
  noctalia.togglePanel("gloves/screenshot-actions:ocr-result")
end

function openSwappy(path)
  if not path or path == "" then return end
  if noctalia.commandExists("swappy") then
    noctalia.runAsync("swappy -f - < " .. path)
  else
    noctalia.notifyError("swappy not installed")
  end
end

function onStart() end
function onConfigChanged() end
