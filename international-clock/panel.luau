--!nonstrict
-- Detailed two-timezone view opened from the Control Center shortcut.

local state = noctalia.state.get("clocks") or { loading = true }

local function offsetLabel(offset)
  local sign, hours, minutes = tostring(offset or ""):match("^([+-])(%d%d)(%d%d)$")
  if sign == nil then
    return "UTC offset unavailable"
  end
  return "UTC" .. sign .. hours .. ":" .. minutes
end

local function clockCard(key, title, subtitle, clock, color)
  local item = type(clock) == "table" and clock or {}
  local zone = tostring(item.zone or "Timezone unavailable")
  return ui.column({ key = key, fill = "surface_variant", radius = 12, padding = 12, gap = 5 }, {
    ui.row({ align = "center", gap = 10 }, {
      ui.column({ flexGrow = 1, gap = 2 }, {
        ui.label({ text = title, fontSize = 15, fontWeight = "semibold" }),
        ui.label({ text = subtitle, color = "on_surface_variant", fontSize = 12 }),
      }),
      ui.label({
        text = tostring(item.time or "—"),
        color = color,
        fontSize = 27,
        fontWeight = "bold",
      }),
    }),
    ui.label({
      text = zone .. " · " .. offsetLabel(item.offset),
      color = "on_surface_variant",
      fontSize = 12,
    }),
  })
end

local function render()
  local localClock = state.localClock
  local irelandClock = state.irelandClock
  local children = {
    ui.row({ align = "center", gap = 8 }, {
      ui.glyph({ name = "clock", color = "primary", size = 23 }),
      ui.label({ text = "International Clock", fontSize = 19, fontWeight = "bold", flexGrow = 1 }),
      ui.button({ glyph = "close", variant = "ghost", onClick = "onClose" }),
    }),
    ui.separator({ color = "outline/0.4" }),
  }

  if state.ok == false then
    table.insert(children, ui.label({
      text = tostring(state.error or "Clock update failed"),
      color = "error",
      maxLines = 2,
    }))
  end

  table.insert(children, clockCard(
    "local",
    "Spain · local time",
    "Uses this computer's configured local timezone",
    localClock,
    "primary"
  ))
  table.insert(children, clockCard(
    "ireland",
    "Ireland · Dublin",
    "IANA timezone: Europe/Dublin",
    irelandClock,
    "tertiary"
  ))

  local updated = "Waiting for first update…"
  if state.updatedAt ~= nil then
    updated = "Updates every second · last sync " .. noctalia.formatTime("%H:%M:%S", state.updatedAt)
  end
  table.insert(children, ui.label({ text = updated, color = "on_surface_variant", fontSize = 12 }))

  panel.render(ui.column({ padding = 16, gap = 9, fill = "surface", align = "stretch" }, children))
end

noctalia.state.watch("clocks", function(value)
  state = type(value) == "table" and value or { loading = true }
  render()
end)

panel.setWantsSecondTicks(true)

function update()
  render()
end

function onOpen(_context)
  render()
end

function onClose()
  panel.close()
end
