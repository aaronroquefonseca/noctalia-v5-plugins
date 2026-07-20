local PANEL_ID = "aaronroquefonseca/arch-updater:details"
local state = noctalia.state.get("updates") or { loading = true, count = 0, updates = {} }
local sequence = 0

local function render()
  local count = tonumber(state.count) or 0
  local hideWhenEmpty = noctalia.getConfig("hide_when_empty") ~= false
  local hidden = hideWhenEmpty and count == 0 and not state.loading and state.ok ~= false
  barWidget.setVisible(not hidden)
  barWidget.setGlyph("navigation-filled")
  barWidget.setText(state.loading and "…" or tostring(count))
  barWidget.setTooltip({
    { key = "Updates", value = state.loading and "Refreshing…" or tostring(count) },
    { key = "Status", value = state.ok == false and tostring(state.error or "Unavailable") or "Click for details" },
  })
end

noctalia.state.watch("updates", function(value)
  state = type(value) == "table" and value or { loading = true, count = 0, updates = {} }
  render()
end)

function update() render() end
function onConfigChanged() render() end
function onClick() noctalia.togglePanel(PANEL_ID) end
function onMiddleClick()
  sequence = sequence + 1
  noctalia.state.set("refresh_request", { token = tostring(os.time()) .. ":widget:" .. sequence })
end
function onRightClick() onMiddleClick() end
