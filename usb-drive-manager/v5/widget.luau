local PANEL_ID = "aaronroquefonseca/usb-drive-manager:devices"
local state = noctalia.state.get("devices") or { loading = true, count = 0, devices = {} }
local sequence = 0

local function render()
  local count = tonumber(state.count) or 0
  local hidden = noctalia.getConfig("hide_when_empty") ~= false and count == 0 and not state.loading and state.ok ~= false
  barWidget.setVisible(not hidden)
  barWidget.setGlyph("usb")
  barWidget.setText(state.loading and "…" or tostring(count))
  barWidget.setTooltip({
    { key = "USB drives", value = state.loading and "Refreshing…" or tostring(count) },
    { key = "Status", value = state.ok == false and tostring(state.error or "Unavailable") or "Click to manage" },
  })
end

noctalia.state.watch("devices", function(value)
  state = type(value) == "table" and value or { loading = true, count = 0, devices = {} }
  render()
end)

function update() render() end
function onConfigChanged() render() end
function onClick() noctalia.togglePanel(PANEL_ID) end
function onRightClick()
  sequence += 1
  noctalia.state.set("refresh_request", { token = tostring(os.time()) .. ":widget:" .. sequence })
end
