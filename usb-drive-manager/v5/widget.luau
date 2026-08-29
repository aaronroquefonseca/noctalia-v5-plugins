local PANEL_ID = "aaronroquefonseca/usb-drive-manager:devices"
local state = noctalia.state.get("devices") or { loading = true, count = 0, devices = {} }
local sequence = 0

local function render()
  local count = tonumber(state.count) or 0
  local hidden = noctalia.getConfig("hide_when_empty") ~= false and count == 0 and not state.loading and state.ok ~= false
  barWidget.setVisible(not hidden)

  local color = state.ok == false and "error" or (count > 0 and "primary" or "on_surface_variant")
  local children = {
    ui.glyph({ name = "usb", size = 14, color = color }),
    ui.label({ text = state.loading and "…" or tostring(count), fontSize = 11, fontWeight = "semibold", color = color, maxLines = 1 }),
  }
  if state.ok == false then table.insert(children, ui.glyph({ name = "alert-circle", size = 11, color = "error" })) end
  barWidget.render(ui.row({ gap = 5, align = "center" }, children))
  barWidget.setTooltip({
    { key = "USB drives", value = state.loading and "Refreshing…" or (tostring(count) .. " removable") },
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
