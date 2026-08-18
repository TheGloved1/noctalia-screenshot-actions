--!nonstrict
-- Screenshot Actions — Bar widget
-- Crosshair glyph; left click triggers immediate region capture.

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

    barWidget.setGlyph(capturing and "loader" or "crosshair")
    barWidget.setText("")
    if capturing then
        barWidget.setGlyphColor("error")
    else
        barWidget.clearGlyphColor()
    end
end

function update()
    render()
end

function onClick()
    -- Trigger capture via service command channel
    send("capture")
end

function onRightClick()
    -- Could open panel directly if needed
    noctalia.togglePanel("gloves/screenshot-actions:actions")
end

-- Watch for capture state changes
noctalia.state.watch(STATE_CAPTURING, function(v)
    render()
end)

-- Initial render
render()