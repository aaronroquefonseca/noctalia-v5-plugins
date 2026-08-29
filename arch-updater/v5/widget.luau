local PANEL_ID = "aaronroquefonseca/arch-updater:details"
local state = noctalia.state.get("updates") or { loading = true, count = 0, updates = {} }
local sequence = 0

local function render()
  local count = tonumber(state.count) or 0
  local hideWhenEmpty = noctalia.getConfig("hide_when_empty") ~= false
  local hidden = hideWhenEmpty and count == 0 and not state.loading and state.ok ~= false
  barWidget.setVisible(not hidden)

  local color = "on_surface"
  if state.ok == false then color = "error"
  elseif count > 0 then color = state.noctaliaUpdate and "tertiary" or "primary" end

  local children = {
    ui.glyph({ name = "navigation-filled", size = 14, color = color }),
    ui.label({ text = state.loading and "…" or tostring(count), fontSize = 11, fontWeight = "semibold", color = color, maxLines = 1 }),
  }
  if state.ok == false then
    table.insert(children, ui.glyph({ name = "alert-circle", size = 11, color = "error" }))
  end
  barWidget.render(ui.row({ gap = 5, align = "center" }, children))
  barWidget.setTooltip({
    { key = "Updates", value = state.loading and "Refreshing…" or (tostring(count) .. " available") },
    { key = "Status", value = state.ok == false and tostring(state.error or "Unavailable") or (state.noctaliaUpdate and "Noctalia update available" or "Click for details") },
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
