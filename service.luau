--!nonstrict
function onIpc(ev, pl)
  if ev ~= "capture" then return end
  local SRC = debug.getinfo(1, "S").source:gsub("^@", "")
  local DIR = SRC:match("^(.*[/\\])") or "./"
  local CPS = DIR .. "scripts/capture.sh"
  local ok = noctalia.runAsync(CPS, function(r)
    if not r or r.exitCode ~= 0 then return end
    local p = (r.stdout or ""):match("^%s*(.-)%s*$")
    if p and p ~= "" and p ~= "cancelled" then
      noctalia.state.set("lastCapture", p)
      noctalia.togglePanel("gloves/screenshot-actions:actions")
    end
  end)
  if not ok then noctalia.notifyError("Screenshot", "launch failed") end
end