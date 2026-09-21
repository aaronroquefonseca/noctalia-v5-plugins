local PANEL_ID = "aaronroquefonseca/opencode-go-usage:details"
local state = noctalia.state.get("usage") or { loading = true }
local refreshSequence = 0
local icon = noctalia.pluginDir() .. "/icons/opencode.svg"

local function clamp(value)
  return math.max(0, math.min(100, value))
end

local function remaining(window)
  if type(window) ~= "table" or type(window.usedPercent) ~= "number" then return nil end
  return clamp(100 - window.usedPercent)
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

local function segment(window, label)
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
      text = label .. " " .. tostring(math.floor(value + 0.5)) .. "%",
      fontSize = 11,
      fontWeight = "semibold",
      color = value <= 10 and "error" or "on_surface",
      maxLines = 1,
    }),
  })
end

local function wants(mode, key)
  if mode == "all" then return true end
  if mode == "rolling_weekly" then return key == "rolling" or key == "weekly" end
  return mode == key
end

local function render()
  local windows = type(state.windows) == "table" and state.windows or {}
  local mode = tostring(noctalia.getConfig("display_mode") or "rolling_weekly")
  local style = tostring(noctalia.getConfig("panel_style") or "full")
  local children = {}

  -- Match Codex Usage semantics:
  -- full = icon + usage, usage = usage only, icon = icon only.
  if style ~= "usage" then
    table.insert(children, ui.image({
      key = "logo",
      path = icon,
      width = 15,
      height = 15,
      fit = "contain",
    }))
  end

  if style ~= "icon" then
    if state.loading and state.ok == nil then
      table.insert(children, ui.label({ text = "…", fontSize = 11, color = "on_surface_variant" }))
    else
      local before = #children
      for _, item in ipairs({
        { key = "rolling", label = "5h" },
        { key = "weekly", label = "7d" },
        { key = "monthly", label = "30d" },
      }) do
        if wants(mode, item.key) then
          local part = segment(windows[item.key], item.label)
          if part then table.insert(children, part) end
        end
      end
      if #children == before then
        table.insert(children, ui.label({ text = "—", fontSize = 11, color = "on_surface_variant" }))
      end
    end
  end

  if state.ok == false then
    table.insert(children, ui.glyph({ name = "alert-circle", size = 12, color = "error" }))
  end

  barWidget.render(ui.row({ key = "root", gap = 7, align = "center" }, children))

  local tooltip = {}
  for _, item in ipairs({
    { key = "rolling", label = "Go 5h" },
    { key = "weekly", label = "Go weekly" },
    { key = "monthly", label = "Go monthly" },
  }) do
    local window = windows[item.key]
    local value = remaining(window)
    if value ~= nil then
      table.insert(tooltip, {
        key = item.label,
        value = tostring(math.floor(value + 0.5)) .. "% left · resets in " .. resetCountdown(window),
      })
    end
  end
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
