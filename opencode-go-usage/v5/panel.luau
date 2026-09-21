local state = noctalia.state.get("usage") or { loading = true }
local seq = 0

local function clamp(value)
  return math.max(0, math.min(100, value))
end

local function remaining(window)
  if type(window) ~= "table" or type(window.usedPercent) ~= "number" then return nil end
  return clamp(100 - window.usedPercent)
end

local function resetText(timestamp)
  if type(timestamp) ~= "number" then return "Reset time unavailable" end
  local delta = math.max(0, timestamp - os.time())
  if delta < 60 then return "Resets in less than a minute" end
  if delta < 3600 then return "Resets in " .. math.ceil(delta / 60) .. " min" end
  if delta < 86400 then
    return "Resets in " .. math.floor(delta / 3600) .. "h " .. math.ceil((delta % 3600) / 60) .. "m"
  end
  return "Resets in " .. math.floor(delta / 86400) .. "d " .. math.floor((delta % 86400) / 3600) .. "h"
end

local function pace(window)
  if type(window) ~= "table" or type(window.usedPercent) ~= "number" or type(window.resetsAt) ~= "number" then
    return nil
  end
  local minutes = tonumber(window.windowDurationMins)
  if not minutes or minutes <= 0 then return nil end
  local duration = minutes * 60
  local startAt = window.resetsAt - duration
  local elapsed = clamp(((os.time() - startAt) / duration) * 100)
  local delta = window.usedPercent - elapsed
  if math.abs(delta) < 2 then return "On even pace", "on_surface_variant" end
  if delta > 0 then
    return tostring(math.floor(delta + 0.5)) .. "pts over even pace", delta >= 25 and "error" or "tertiary"
  end
  return tostring(math.floor(math.abs(delta) + 0.5)) .. "pts under even pace", "secondary"
end

local function severity(value)
  if not value then return "on_surface" end
  if value <= 10 then return "error" end
  if value <= 25 then return "tertiary" end
  return "primary"
end

local function card(window, key, title)
  local value = remaining(window)
  local paceText, paceColor = pace(window)
  local footer = {
    ui.label({ text = resetText(window.resetsAt), color = "on_surface_variant", fontSize = 11, flexGrow = 1 }),
  }
  if paceText then
    table.insert(footer, ui.label({ text = paceText, color = paceColor, fontSize = 11, fontWeight = "semibold" }))
  end

  return ui.column({ key = key, fill = "surface_variant", radius = 12, padding = 12, gap = 8 }, {
    ui.row({ justify = "space_between", align = "center" }, {
      ui.label({ text = title, fontWeight = "semibold", flexGrow = 1 }),
      ui.label({
        text = value and tostring(math.floor(value + 0.5)) .. "% left" or "—",
        color = severity(value),
        fontSize = 14,
        fontWeight = "bold",
      }),
    }),
    ui.progress({
      progress = value and value / 100 or 0,
      fill = severity(value),
      track = "on_surface/0.14",
      height = 8,
      radius = 8,
    }),
    ui.row({ justify = "space_between", align = "center", gap = 8 }, footer),
  })
end

local function header()
  local subtitle = "OpenCode Go"
  if state.updatedAt then
    subtitle = subtitle .. " · updated " .. noctalia.formatTime("%H:%M", state.updatedAt)
  end

  return ui.row({ gap = 10, align = "center" }, {
    ui.row({ gap = 8, align = "center", flexGrow = 1 }, {
      ui.row({ width = 36, height = 36, radius = 10, fill = "primary/0.14", align = "center", justify = "center" }, {
        ui.glyph({ name = "code", size = 19, color = "primary" }),
      }),
      ui.column({ gap = 1, flexGrow = 1 }, {
        ui.label({ text = "OpenCode Go usage", fontSize = 18, fontWeight = "bold", maxLines = 1 }),
        ui.label({ text = subtitle, color = "on_surface_variant", fontSize = 11, maxLines = 1 }),
      }),
    }),
    ui.button({ glyph = "refresh", variant = "ghost", enabled = not state.loading, onClick = "onRefresh" }),
    ui.button({ glyph = "close", variant = "ghost", onClick = "onClose" }),
  })
end

local function render()
  local windows = type(state.windows) == "table" and state.windows or {}
  local body = {}
  local children = {
    header(),
    ui.separator({ color = "outline/0.25" }),
  }

  if state.ok == false then
    table.insert(body, ui.row({ fill = "error/0.10", radius = 10, padding = 10, gap = 8, align = "center" }, {
      ui.glyph({ name = "alert-circle", size = 15, color = "error" }),
      ui.label({ text = tostring(state.error or "Unable to read OpenCode Go usage"), color = "error", maxLines = 3 }),
    }))
  end

  if windows.rolling then table.insert(body, card(windows.rolling, "rolling", "5-hour window")) end
  if windows.weekly then table.insert(body, card(windows.weekly, "weekly", "Weekly window")) end
  if windows.monthly then table.insert(body, card(windows.monthly, "monthly", "Monthly window")) end

  if state.authSource and state.ok ~= false then
    table.insert(body, ui.label({
      text = "Credentials: " .. tostring(state.authSource),
      color = "on_surface_variant",
      fontSize = 10,
      maxLines = 2,
    }))
  end

  table.insert(children, ui.scroll({ flexGrow = 1, gap = 10 }, body))
  panel.render(ui.column({ padding = 14, gap = 10, fill = "surface", flexGrow = 1, align = "stretch" }, children))
end

noctalia.state.watch("usage", function(value)
  state = type(value) == "table" and value or { loading = true }
  render()
end)

panel.setWantsSecondTicks(true)
function update() render() end
function onOpen() render() end
function onClose() panel.close() end
function onRefresh()
  seq = seq + 1
  noctalia.state.set("refresh_request", { token = tostring(os.time()) .. ":" .. seq })
end
