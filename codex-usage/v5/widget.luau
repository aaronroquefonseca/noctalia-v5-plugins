local PANEL_ID = "aaronroquefonseca/codex-usage:details"
local state = noctalia.state.get("usage") or { loading = true }
local refreshSequence = 0
local icon = noctalia.pluginDir() .. "/icons/openai.svg"

local function clamp(value)
  return math.max(0, math.min(100, value))
end

local function remaining(window)
  if type(window) ~= "table" or type(window.usedPercent) ~= "number" then return nil end
  return clamp(100 - window.usedPercent)
end

local function shortWindow(window, fallback)
  if type(window) ~= "table" then return fallback or "limit" end
  local minutes = tonumber(window.windowDurationMins) or tonumber(window.windowMinutes) or 0
  if minutes == 300 then return "5h" end
  if minutes == 10080 then return "7d" end
  if minutes >= 1440 and minutes % 1440 == 0 then return tostring(minutes / 1440) .. "d" end
  if minutes >= 60 and minutes % 60 == 0 then return tostring(minutes / 60) .. "h" end
  if minutes > 0 then return tostring(minutes) .. "m" end
  return fallback or "limit"
end

local function resetCountdown(window)
  if type(window) ~= "table" or type(window.resetsAt) ~= "number" then return "reset unavailable" end
  local seconds = math.max(0, window.resetsAt - os.time())
  local days = math.floor(seconds / 86400)
  local hours = math.floor((seconds % 86400) / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  if days > 0 then return string.format("%dd %dh", days, hours) end
  if hours > 0 then return string.format("%dh %dm", hours, minutes) end
  return string.format("%dm", math.max(1, minutes))
end

local function segment(window, fallback)
  local value = remaining(window)
  if value == nil then return nil end
  return ui.row({ align = "center", gap = 5 }, {
    ui.progress({
      progress = value / 100,
      fill = value <= 10 and "error" or (value <= 25 and "tertiary" or "primary"),
      track = "on_surface/0.16",
      width = 28,
      height = 5,
      radius = 6,
    }),
    ui.label({
      text = shortWindow(window, fallback) .. " " .. tostring(math.floor(value + 0.5)) .. "%",
      fontSize = 11,
      fontWeight = "semibold",
      color = value <= 10 and "error" or "on_surface",
      maxLines = 1,
    }),
  })
end

local function availableResets()
  local resets = type(state.resetCredits) == "table" and state.resetCredits or {}
  return tonumber(resets.availableCount) or 0
end

local function render()
  local limits = type(state.rateLimits) == "table" and state.rateLimits or {}
  local mode = tostring(noctalia.getConfig("display_mode") or "both")
  local style = tostring(noctalia.getConfig("panel_style") or "full")
  local children = {
    ui.image({ key = "logo", path = icon, width = 15, height = 15, fit = "contain" }),
  }

  if style ~= "icon" then
    if state.loading and state.ok == nil then
      table.insert(children, ui.label({ text = "…", fontSize = 11, color = "on_surface_variant" }))
    else
      if mode == "both" or mode == "primary" then
        local item = segment(limits.primary, "5h")
        if item then table.insert(children, item) end
      end
      if mode == "both" or mode == "secondary" then
        local item = segment(limits.secondary, "7d")
        if item then table.insert(children, item) end
      end
      if #children == 1 then
        table.insert(children, ui.label({ text = "—", fontSize = 11, color = "on_surface_variant" }))
      end
    end
  end

  if state.ok == false then
    table.insert(children, ui.glyph({ name = "alert-circle", size = 12, color = "error" }))
  end

  barWidget.render(ui.row({ key = "root", gap = 7, align = "center" }, children))

  local tooltip = {}
  if type(limits.primary) == "table" and remaining(limits.primary) ~= nil then
    table.insert(tooltip, { key = "Codex 5h", value = tostring(math.floor(remaining(limits.primary) + 0.5)) .. "% left · resets in " .. resetCountdown(limits.primary) })
  end
  if type(limits.secondary) == "table" and remaining(limits.secondary) ~= nil then
    table.insert(tooltip, { key = "Codex weekly", value = tostring(math.floor(remaining(limits.secondary) + 0.5)) .. "% left · resets in " .. resetCountdown(limits.secondary) })
  end
  table.insert(tooltip, { key = "Limit resets", value = tostring(availableResets()) .. " available" })
  if state.ok == false then
    table.insert(tooltip, { key = "Status", value = tostring(state.error or "Unavailable") })
  end
  barWidget.setTooltip(tooltip)
end

noctalia.state.watch("usage", function(value)
  state = type(value) == "table" and value or { loading = true }
  render()
end)

function update() render() end
function onConfigChanged() render() end
function onClick() noctalia.togglePanel(PANEL_ID) end
function onRightClick()
  refreshSequence = refreshSequence + 1
  noctalia.state.set("refresh_request", { token = tostring(os.time()) .. ":bar:" .. refreshSequence })
end
