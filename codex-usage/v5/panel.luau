local state = noctalia.state.get("usage") or { loading = true }
local view = "usage"
local seq = 0
local icon = noctalia.pluginDir() .. "/icons/openai.svg"

local function clamp(value)
  return math.max(0, math.min(100, value))
end

local function rem(w)
  if type(w) ~= "table" or type(w.usedPercent) ~= "number" then return nil end
  return clamp(100 - w.usedPercent)
end

local function name(m)
  if type(m) ~= "number" then return "Usage window" end
  if m == 300 then return "5-hour session" end
  if m == 10080 then return "Weekly window" end
  if m % 10080 == 0 then return (m / 10080) .. "-week window" end
  if m % 1440 == 0 then return (m / 1440) .. "-day window" end
  if m % 60 == 0 then return (m / 60) .. "-hour window" end
  return m .. "-minute window"
end

local function resetText(t)
  if type(t) ~= "number" then return "Reset time unavailable" end
  local d = math.max(0, t - os.time())
  if d < 60 then return "Resets in less than a minute" end
  if d < 3600 then return "Resets in " .. math.ceil(d / 60) .. " min" end
  if d < 86400 then return "Resets in " .. math.floor(d / 3600) .. "h " .. math.ceil((d % 3600) / 60) .. "m" end
  return "Resets in " .. math.floor(d / 86400) .. "d " .. math.floor((d % 86400) / 3600) .. "h"
end

local function pace(w)
  if type(w) ~= "table" or type(w.usedPercent) ~= "number" or type(w.resetsAt) ~= "number" then return nil end
  local minutes = tonumber(w.windowDurationMins) or tonumber(w.windowMinutes)
  if not minutes or minutes <= 0 then return nil end
  local duration = minutes * 60
  local startAt = w.resetsAt - duration
  local elapsed = clamp(((os.time() - startAt) / duration) * 100)
  local delta = w.usedPercent - elapsed
  if math.abs(delta) < 2 then return "On even pace", "on_surface_variant" end
  if delta > 0 then
    return tostring(math.floor(delta + 0.5)) .. "pts over even pace", delta >= 25 and "error" or "tertiary"
  end
  return tostring(math.floor(math.abs(delta) + 0.5)) .. "pts under even pace", "secondary"
end

local function sev(v)
  if not v then return "on_surface" end
  if v <= 10 then return "error" end
  if v <= 25 then return "tertiary" end
  return "primary"
end

local function card(w, k)
  local v = rem(w)
  local paceText, paceColor = pace(w)
  local footer = {
    ui.label({ text = resetText(w.resetsAt), color = "on_surface_variant", fontSize = 11, flexGrow = 1 }),
  }
  if paceText then
    table.insert(footer, ui.label({ text = paceText, color = paceColor, fontSize = 11, fontWeight = "semibold" }))
  end
  return ui.column({ key = k, fill = "surface_variant", radius = 12, padding = 12, gap = 8 }, {
    ui.row({ justify = "space_between", align = "center" }, {
      ui.label({ text = name(tonumber(w.windowDurationMins) or tonumber(w.windowMinutes)), fontWeight = "semibold", flexGrow = 1 }),
      ui.label({ text = v and tostring(math.floor(v + 0.5)) .. "% left" or "—", color = sev(v), fontSize = 14, fontWeight = "bold" }),
    }),
    ui.progress({ progress = v and v / 100 or 0, fill = sev(v), track = "on_surface/0.14", height = 8, radius = 8 }),
    ui.row({ justify = "space_between", align = "center", gap = 8 }, footer),
  })
end

local function resets()
  local s = type(state.resetCredits) == "table" and state.resetCredits or {}
  local a = {}
  for _, c in ipairs(type(s.credits) == "table" and s.credits or {}) do
    if type(c) == "table" and string.lower(tostring(c.status or "")) == "available" then
      table.insert(a, c)
    end
  end
  table.sort(a, function(x, y)
    return (tonumber(x.expiresAt) or math.huge) < (tonumber(y.expiresAt) or math.huge)
  end)
  return a, tonumber(s.availableCount) or #a
end

local function expiry(t)
  if t == nil then return "Does not expire" end
  if type(t) ~= "number" then return "Expiration unavailable" end
  return "Expires " .. noctalia.formatTime("%H:%M on %d %b %Y", t)
end

local function header(title, subtitle, withBack)
  local left = {}
  if withBack then
    table.insert(left, ui.button({ glyph = "chevron-left", variant = "ghost", onClick = "onBack" }))
  else
    table.insert(left, ui.row({ width = 36, height = 36, radius = 10, fill = "primary/0.14", align = "center", justify = "center" }, {
      ui.image({ path = icon, width = 19, height = 19, fit = "contain" }),
    }))
  end
  table.insert(left, ui.column({ gap = 1, flexGrow = 1 }, {
    ui.label({ text = title, fontSize = 18, fontWeight = "bold", maxLines = 1 }),
    ui.label({ text = subtitle, color = "on_surface_variant", fontSize = 11, maxLines = 1 }),
  }))
  return ui.row({ gap = 10, align = "center" }, {
    ui.row({ gap = 8, align = "center", flexGrow = 1 }, left),
    ui.button({ glyph = "refresh", variant = "ghost", enabled = not state.loading, onClick = "onRefresh" }),
    ui.button({ glyph = "close", variant = "ghost", onClick = "onClose" }),
  })
end

local function renderUsage()
  local l = type(state.rateLimits) == "table" and state.rateLimits or {}
  local c = type(l.credits) == "table" and l.credits or {}
  local _, n = resets()
  local body = {}
  local subtitle = tostring(l.planType or "Codex")
  if state.updatedAt then subtitle = subtitle .. " · updated " .. noctalia.formatTime("%H:%M", state.updatedAt) end
  local ch = { header("Codex usage", subtitle, false), ui.separator({ color = "outline/0.25" }) }

  if state.ok == false then
    table.insert(body, ui.row({ fill = "error/0.10", radius = 10, padding = 10, gap = 8, align = "center" }, {
      ui.glyph({ name = "alert-circle", size = 15, color = "error" }),
      ui.label({ text = tostring(state.error or "Unable to read Codex usage"), color = "error", maxLines = 3 }),
    }))
  end
  if l.primary then table.insert(body, card(l.primary, "primary")) end
  if l.secondary then table.insert(body, card(l.secondary, "secondary")) end

  table.insert(body, ui.row({ gap = 10, align = "stretch" }, {
    ui.column({ flexGrow = 1, fill = "surface_variant", radius = 12, padding = 10, align = "center", justify = "center" }, {
      ui.label({ text = c.unlimited and "∞" or tostring(c.balance or "—"), fontSize = 17, fontWeight = "bold" }),
      ui.label({ text = "Credits", color = "on_surface_variant", fontSize = 11 }),
    }),
    ui.button({ text = tostring(n) .. "  Limit resets", glyph = "chevron-right", variant = "outline", flexGrow = 1, onClick = "onResets" }),
  }))

  table.insert(ch, ui.scroll({ flexGrow = 1, gap = 10 }, body))
  panel.render(ui.column({ padding = 14, gap = 10, fill = "surface", flexGrow = 1, align = "stretch" }, ch))
end

local function renderResets()
  local a, n = resets()
  local rows = {}
  local ch = {
    header("Limit resets", tostring(n) .. " available", true),
    ui.separator({ color = "outline/0.25" }),
  }

  for i, c in ipairs(a) do
    table.insert(rows, ui.column({ key = "r" .. i, fill = "surface_variant", radius = 10, padding = 10, gap = 3 }, {
      ui.label({ text = tostring(c.title or "Full reset"), fontWeight = "semibold" }),
      ui.label({ text = expiry(c.expiresAt), color = "on_surface_variant", fontSize = 11 }),
    }))
  end
  if n == 0 then
    table.insert(rows, ui.column({ align = "center", justify = "center", flexGrow = 1, gap = 8 }, {
      ui.glyph({ name = "refresh", size = 32, color = "on_surface_variant" }),
      ui.label({ text = "No usage limit resets available", color = "on_surface_variant" }),
    }))
  elseif n > #a then
    table.insert(rows, ui.label({ text = "Some expiration details are unavailable.", color = "on_surface_variant", fontSize = 11 }))
  end

  table.insert(ch, ui.scroll({ flexGrow = 1, gap = 8 }, rows))
  panel.render(ui.column({ padding = 14, gap = 10, fill = "surface", flexGrow = 1, align = "stretch" }, ch))
end

local function render()
  if view == "resets" then renderResets() else renderUsage() end
end

noctalia.state.watch("usage", function(v)
  state = type(v) == "table" and v or { loading = true }
  render()
end)

panel.setWantsSecondTicks(true)
function update() render() end
function onOpen() view = "usage"; render() end
function onClose() view = "usage"; panel.close() end
function onResets() view = "resets"; render() end
function onBack() view = "usage"; render() end
function onRefresh()
  seq = seq + 1
  noctalia.state.set("refresh_request", { token = tostring(os.time()) .. ":" .. seq })
end
