--!nonstrict
-- Control Center shortcut. Add this entry from Settings → Control Center.

local PANEL_ID = "aaronroquefonseca/international-clock:clocks"
local state = noctalia.state.get("clocks") or { loading = true }

local function render(value)
  state = type(value) == "table" and value or { loading = true }

  local label = "Ireland"
  if state.ok == true and type(state.irelandClock) == "table" then
    local time = tostring(state.irelandClock.time or "—")
    label = "Ireland " .. time:sub(1, 5)
  elseif state.loading == true then
    label = "Ireland …"
  else
    label = "Ireland —"
  end

  shortcut.setLabel(label)
  shortcut.setIcon("clock")
  shortcut.setActive(false)
  shortcut.setEnabled(true)
end

render(state)
noctalia.state.watch("clocks", render)

function onClick()
  noctalia.togglePanel(PANEL_ID)
end

function onRightClick()
  noctalia.togglePanel(PANEL_ID)
end
