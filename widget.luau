--!nonstrict
-- Screenshot Actions — Bar widget
-- Crosshair glyph; left click triggers immediate region capture.

local function render()
    barWidget.setGlyph("crosshair")
    barWidget.setText("")
    barWidget.clearGlyphColor()
end

function update()
    render()
end

function onClick()
    noctalia.state.set("command", { action = "capture", payload = nil })
end

function onRightClick()
    noctalia.togglePanel("gloves/screenshot-actions:actions")
end

render()