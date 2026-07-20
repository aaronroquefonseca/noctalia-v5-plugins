local PANEL_ID = "aaronroquefonseca/codex-usage:details"
local state = noctalia.state.get("usage") or { loading = true }
local refreshSequence = 0

local function clamp(value)
  return math.max(0, math.min(100, value))
end

local function remaining(window)
  if type(window) ~= "table" or type(window.usedPercent) ~= "number" then return nil end
  return clamp(100 - window.usedPercent)
end

local function valueText(mode, primary, secondary)
  if mode == "primary" then return primary and (primary .. "%") or "—" end
  if mode == "secondary" then return secondary and (secondary .. "%") or "—" end
  if primary and secondary then return primary .. "% · " .. secondary .. "%" end
  if primary then return primary .. "%" end
  if secondary then return secondary .. "%" end
  return "—"
end

local function render()
  local limits = type(state.rateLimits) == "table" and state.rateLimits or {}
  local primary = remaining(limits.primary)
  local secondary = remaining(limits.secondary)
  local mode = tostring(noctalia.getConfig("display_mode") or "both")
  local style = tostring(noctalia.getConfig("panel_style") or "full")
  local values = valueText(mode, primary, secondary)

  local lowest = nil
  if primary then lowest = primary end
  if secondary and (not lowest or secondary < lowest) then lowest = secondary end
  local color = "on_surface"
  if state.ok == false then color = "error"
  elseif lowest and lowest <= 10 then color = "error"
  elseif lowest and lowest <= 25 then color = "tertiary" end

  local children = {
    ui.image({ key = "logo", path = "../icons/openai.svg", width = 16, height = 16, fit = "contain" }),
  }
  if style ~= "icon" then
    local text = style == "usage" and values or ("Codex " .. values)
    if state.loading and state.ok == nil then text = style == "usage" and "…" or "Codex …" end
    table.insert(children, ui.label({ key = "text", text = text, color = color, fontWeight = "semibold", maxLines = 1 }))
  end

  barWidget.render(ui.row({ key = "root", gap = 5, align = "center" }, children))
  barWidget.setTooltip({
    { key = "Codex", value = state.loading and "Refreshing…" or values },
    { key = "Status", value = state.ok == false and tostring(state.error or "Unavailable") or "Click for details" },
  })
end

noctalia.state.watch("usage", function(value)
  state = type(value) == "table" and value or { loading = true }
  render()
end)

function update()
  render()
end

function onConfigChanged()
  render()
end

function onClick()
  noctalia.togglePanel(PANEL_ID)
end

function onRightClick()
  refreshSequence = refreshSequence + 1
  noctalia.state.set("refresh_request", { token = tostring(os.time()) .. ":bar:" .. refreshSequence })
end
