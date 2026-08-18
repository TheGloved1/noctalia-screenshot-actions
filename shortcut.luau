--!nonstrict
-- Screenshot Actions — Control-center shortcut tile
-- Mirrors the bar widget: click to trigger capture.

local STATE_CAPTURING = "capturing"

local function tr(key, subst)
    if subst then return noctalia.tr(key, subst) end
    return noctalia.tr(key)
end

local function send(action, payload)
    noctalia.state.set("command", { action = action, payload = payload })
end

local function render()
    local capturing = noctalia.state.get(STATE_CAPTURING) == true

    shortcut.setLabel(tr("shortcut.label"))
    shortcut.setIcon("crosshair")
    shortcut.setActive(capturing)
    shortcut.setEnabled(not capturing)
end

function onClick()
    send("capture")
end

noctalia.state.watch(STATE_CAPTURING, function(v)
    render()
end)

render()