local state = noctalia.state.get("updates") or { loading = true, updates = {}, count = 0 }
local sequence = 0

local function sourceColor(source)
  if source == "aur" then return "primary" end
  if source == "flatpak" then return "tertiary" end
  return "secondary"
end

local function sourceName(source)
  if source == "aur" then return "AUR" end
  if source == "flatpak" then return "FLATPAK" end
  return "ARCH"
end

local function request(key, origin)
  sequence = sequence + 1
  noctalia.state.set(key, { token = tostring(os.time()) .. ":" .. origin .. ":" .. sequence })
end

local function updateCard(item, index)
  local color = sourceColor(item.source)
  return ui.column({ key = "update-" .. index, gap = 6, padding = 10, fill = "surface_variant", radius = 10 }, {
    ui.row({ align = "center", justify = "space_between", gap = 8 }, {
      ui.label({ text = tostring(item.name or "?"), fontWeight = "semibold", flexGrow = 1, maxLines = 1 }),
      ui.label({ text = sourceName(item.source), color = color, fontSize = 10, fontWeight = "bold" }),
    }),
    ui.row({ align = "center", gap = 6 }, {
      ui.label({ text = tostring(item.oldVersion or "?"), color = "on_surface_variant", fontSize = 11, maxLines = 1 }),
      ui.glyph({ name = "arrow-right", color = "on_surface_variant", size = 12 }),
      ui.label({ text = tostring(item.newVersion or "?"), color = color, fontSize = 11, fontWeight = "semibold", maxLines = 1 }),
    }),
  })
end

local function render()
  local updates = type(state.updates) == "table" and state.updates or {}
  local count = tonumber(state.count) or #updates
  local rows = {}
  local warnings = type(state.warnings) == "table" and state.warnings or {}
  local subtitle = state.loading and "Checking package sources…" or (count == 0 and "System is up to date" or (tostring(count) .. (count == 1 and " update available" or " updates available")))
  if state.updatedAt and not state.loading then subtitle = subtitle .. " · " .. noctalia.formatTime("%H:%M", state.updatedAt) end

  local children = {
    ui.row({ gap = 10, align = "center" }, {
      ui.row({ width = 36, height = 36, radius = 10, fill = (state.noctaliaUpdate and "tertiary" or "primary") .. "/0.14", align = "center", justify = "center" }, {
        ui.glyph({ name = "navigation-filled", color = state.noctaliaUpdate and "tertiary" or "primary", size = 20 }),
      }),
      ui.column({ gap = 1, flexGrow = 1 }, {
        ui.label({ text = "Available updates", fontSize = 18, fontWeight = "bold", maxLines = 1 }),
        ui.label({ text = subtitle, color = "on_surface_variant", fontSize = 11, maxLines = 1 }),
      }),
      ui.button({ glyph = "refresh", variant = "ghost", enabled = not state.loading, onClick = "onRefresh" }),
      ui.button({ glyph = "close", variant = "ghost", onClick = "onClose" }),
    }),
    ui.separator({ color = "outline/0.25" }),
  }

  if #warnings > 0 or state.ok == false then
    table.insert(rows, ui.row({ fill = "error/0.10", radius = 10, padding = 9, gap = 8, align = "center" }, {
      ui.glyph({ name = "alert-circle", size = 14, color = "error" }),
      ui.label({ text = #warnings > 0 and table.concat(warnings, "\n") or tostring(state.error or "Update check failed"), color = "error", fontSize = 11, maxLines = 4 }),
    }))
  end

  for index, item in ipairs(updates) do table.insert(rows, updateCard(item, index)) end

  if #updates == 0 and #warnings == 0 then
    table.insert(rows, ui.column({ align = "center", justify = "center", gap = 9, flexGrow = 1 }, {
      ui.glyph({ name = state.loading and "refresh" or "circle-check", size = 34, color = state.loading and "on_surface_variant" or "secondary" }),
      ui.label({ text = state.loading and "Checking for updates…" or "Everything is up to date", color = "on_surface_variant" }),
    }))
  end

  table.insert(children, ui.scroll({ flexGrow = 1, gap = 8 }, rows))
  if count > 0 then
    table.insert(children, ui.button({ text = count == 1 and "Install update" or ("Install " .. tostring(count) .. " updates"), glyph = "navigation-filled", enabled = not state.loading, onClick = "onUpdate" }))
  end
  panel.render(ui.column({ padding = 14, gap = 10, fill = "surface", flexGrow = 1, align = "stretch" }, children))
end

noctalia.state.watch("updates", function(value)
  state = type(value) == "table" and value or { loading = true, updates = {}, count = 0 }
  render()
end)

function update() render() end
function onOpen() render() end
function onClose() panel.close() end
function onRefresh() request("refresh_request", "panel") end
function onUpdate() request("update_request", "panel"); panel.close() end
