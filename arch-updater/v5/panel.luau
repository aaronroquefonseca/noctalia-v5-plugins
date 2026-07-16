local state = noctalia.state.get("updates") or { loading = true, updates = {}, count = 0 }
local sequence = 0

local function sourceColor(source)
  if source == "aur" then return "primary" end
  if source == "flatpak" then return "tertiary" end
  return "secondary"
end

local function request(key, origin)
  sequence = sequence + 1
  noctalia.state.set(key, { token = tostring(os.time()) .. ":" .. origin .. ":" .. sequence })
end

local function render()
  local updates = type(state.updates) == "table" and state.updates or {}
  local updateRows = {}
  local children = {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "navigation-filled", color = state.noctaliaUpdate and "tertiary" or "primary", size = 22 }),
      ui.label({ text = "Available updates", fontSize = 19, fontWeight = "bold", flexGrow = 1 }),
      ui.label({ text = tostring(tonumber(state.count) or #updates), color = "on_surface_variant", fontWeight = "bold" }),
    }),
    ui.separator({ color = "outline/0.4" }),
  }

  if state.ok == false then
    table.insert(updateRows, ui.label({ text = tostring(state.error or "Update check failed"), color = "error", maxLines = 4 }))
  elseif #updates == 0 then
    table.insert(updateRows, ui.label({ text = state.loading and "Checking for updates…" or "System is up to date.", color = "on_surface_variant" }))
  else
    for index = 1, #updates do
      local item = updates[index]
      table.insert(updateRows, ui.row({ key = "update-" .. index, gap = 7, align = "center", padding = 7, fill = "surface_variant", radius = 7 }, {
        ui.label({ text = tostring(item.name or "?"), color = sourceColor(item.source), fontWeight = "semibold", flexGrow = 1, maxLines = 1 }),
        ui.label({ text = tostring(item.oldVersion or "?"), color = "on_surface_variant", fontSize = 11, maxLines = 1 }),
        ui.glyph({ name = "arrow-right", color = "on_surface_variant", size = 13 }),
        ui.label({ text = tostring(item.newVersion or "?"), color = sourceColor(item.source), fontSize = 11, maxLines = 1 }),
      }))
    end
  end

  table.insert(children, ui.scroll({ flexGrow = 1, gap = 2 }, updateRows))
  table.insert(children, ui.separator({ color = "outline/0.4" }))
  table.insert(children, ui.label({
    text = state.loading and "Refreshing…" or (state.updatedAt and "Updated at " .. noctalia.formatTime("%H:%M", state.updatedAt) or "Not updated yet"),
    color = "on_surface_variant", fontSize = 12,
  }))
  table.insert(children, ui.row({ gap = 8 }, {
    ui.button({ text = "Refresh", glyph = "refresh", variant = "outline", enabled = not state.loading, flexGrow = 1, onClick = "onRefresh" }),
    ui.button({ text = "Update", glyph = "navigation-filled", enabled = not state.loading, flexGrow = 1, onClick = "onUpdate" }),
    ui.button({ glyph = "close", variant = "ghost", onClick = "onClose" }),
  }))
  panel.render(ui.column({ padding = 16, gap = 7, fill = "surface", flexGrow = 1, align = "stretch" }, children))
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
