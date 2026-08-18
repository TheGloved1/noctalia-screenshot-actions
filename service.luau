--!nonstrict
function onIpc(ev, pl)
  if ev ~= "capture" then return end
  local path = "/home/gloves/.local/share/noctalia/plugins/screenshot-actions/scripts/capture.sh"
  local ok = noctalia.runAsync(path, function(r)
    if not r or r.exitCode ~= 0 then return end
    local p = (r.stdout or ""):match("^%s*(.-)%s*$")
    if p and p ~= "" and p ~= "cancelled" then
      noctalia.state.set("lastCapture", p)
      noctalia.togglePanel("gloves/screenshot-actions:actions")
    end
  end)
  if not ok then noctalia.notifyError("Screenshot", "launch failed") end
end