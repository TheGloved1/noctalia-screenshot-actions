--!nonstrict
-- Screenshot Actions — Control-center shortcut tile
-- Mirrors the bar widget: click to trigger capture.

function onClick()
    noctalia.state.set("command", { action = "capture", payload = nil })
end

function render() end

render()