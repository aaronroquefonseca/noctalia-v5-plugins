local state = noctalia.state.get("devices") or { loading = true, count = 0, devices = {} }
local slots = {}
local sequence = 0

local function quote(value)
  return "'" .. string.gsub(tostring(value or ""), "'", "'\\''") .. "'"
end

local function commandWithPath(template, path)
  local quoted = quote(path)
  if template:find("{path}", 1, true) then
    return (template:gsub("{path}", function() return quoted end))
  end
  return template .. " " .. quoted
end

local function request(actionName, device)
  if type(device) ~= "table" then return end
  sequence += 1
  noctalia.state.set("action_request", {
    token = tostring(os.time()) .. ":" .. sequence,
    action = actionName,
    path = device.path,
  })
end

local function act(slot, actionName)
  local device = slots[slot]
  if actionName == "open" then
    if type(device) ~= "table" or not device.mounted or device.mountpoint == "" then return end
    local template = tostring(noctalia.getConfig("file_manager") or "nautilus {path}")
    noctalia.runAsync("nohup " .. commandWithPath(template, device.mountpoint) .. " >/dev/null 2>&1 &", function() end, 5000)
    panel.close()
    return
  end
  request(actionName, device)
end

local function deviceCard(device, index)
  slots[index] = device
  local title = tostring(device.label or "")
  if title == "" then title = tostring(device.model or "") end
  if title == "" then title = tostring(device.name or device.path or "USB drive") end
  local details = tostring(device.size or "") .. " · " .. string.upper(tostring(device.fstype or "unknown"))
  local status = device.mounted and tostring(device.mountpoint or "Mounted") or "Not mounted"
  local buttons = {}
  if device.mounted then
    table.insert(buttons, ui.button({ text = "Open", glyph = "folder-open", flexGrow = 1, onClick = "onOpen" .. index }))
    table.insert(buttons, ui.button({ glyph = "plug-connected-x", variant = "outline", onClick = "onUnmount" .. index }))
  else
    table.insert(buttons, ui.button({ text = "Mount", glyph = "plug-connected", flexGrow = 1, onClick = "onMount" .. index }))
  end
  table.insert(buttons, ui.button({ glyph = "player-eject", variant = "outline", onClick = "onEject" .. index }))
  return ui.column({ key = tostring(device.path), fill = "surface_variant", radius = 10, padding = 10, gap = 6 }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "usb", color = device.mounted and "primary" or "on_surface_variant", size = 20 }),
      ui.column({ flexGrow = 1, gap = 2 }, {
        ui.label({ text = title, fontWeight = "semibold", maxLines = 1 }),
        ui.label({ text = details, color = "on_surface_variant", fontSize = 11, maxLines = 1 }),
      }),
    }),
    ui.label({ text = status, color = "on_surface_variant", fontSize = 11, maxLines = 1 }),
    ui.row({ gap = 7 }, buttons),
  })
end

local function render()
  slots = {}
  local devices = type(state.devices) == "table" and state.devices or {}
  local cards = {}
  for index = 1, math.min(#devices, 12) do table.insert(cards, deviceCard(devices[index], index)) end
  if #cards == 0 then
    cards[1] = ui.column({ align = "center", justify = "center", gap = 8, flexGrow = 1 }, {
      ui.glyph({ name = "usb", size = 38, color = "on_surface_variant" }),
      ui.label({ text = state.loading and "Checking for USB drives…" or "No removable USB drives", color = "on_surface_variant" }),
    })
  end
  local children = {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "usb", color = "primary", size = 22 }),
      ui.label({ text = "USB drives", fontSize = 19, fontWeight = "bold", flexGrow = 1 }),
      ui.label({ text = tostring(tonumber(state.count) or #devices), color = "on_surface_variant" }),
      ui.button({ glyph = "refresh", variant = "ghost", enabled = not state.loading, onClick = "onRefresh" }),
      ui.button({ glyph = "close", variant = "ghost", onClick = "onClose" }),
    }),
    ui.separator({ color = "outline/0.4" }),
  }
  if state.ok == false then table.insert(children, ui.label({ text = tostring(state.error or "Device query failed"), color = "error", maxLines = 3 })) end
  table.insert(children, ui.scroll({ flexGrow = 1, gap = 8 }, cards))
  panel.render(ui.column({ padding = 14, gap = 9, fill = "surface" }, children))
end

noctalia.state.watch("devices", function(value)
  state = type(value) == "table" and value or { loading = true, count = 0, devices = {} }
  render()
end)

function update() render() end
function onOpen() render() end
function onClose() panel.close() end
function onRefresh() sequence += 1; noctalia.state.set("refresh_request", { token = tostring(os.time()) .. ":panel:" .. sequence }) end

local function mount(i) act(i, "mount") end
local function unmount(i) act(i, "unmount") end
local function eject(i) act(i, "eject") end
local function open(i) act(i, "open") end

function onMount1() mount(1) end
function onMount2() mount(2) end
function onMount3() mount(3) end
function onMount4() mount(4) end
function onMount5() mount(5) end
function onMount6() mount(6) end
function onMount7() mount(7) end
function onMount8() mount(8) end
function onMount9() mount(9) end
function onMount10() mount(10) end
function onMount11() mount(11) end
function onMount12() mount(12) end
function onUnmount1() unmount(1) end
function onUnmount2() unmount(2) end
function onUnmount3() unmount(3) end
function onUnmount4() unmount(4) end
function onUnmount5() unmount(5) end
function onUnmount6() unmount(6) end
function onUnmount7() unmount(7) end
function onUnmount8() unmount(8) end
function onUnmount9() unmount(9) end
function onUnmount10() unmount(10) end
function onUnmount11() unmount(11) end
function onUnmount12() unmount(12) end
function onEject1() eject(1) end
function onEject2() eject(2) end
function onEject3() eject(3) end
function onEject4() eject(4) end
function onEject5() eject(5) end
function onEject6() eject(6) end
function onEject7() eject(7) end
function onEject8() eject(8) end
function onEject9() eject(9) end
function onEject10() eject(10) end
function onEject11() eject(11) end
function onEject12() eject(12) end
function onOpen1() open(1) end
function onOpen2() open(2) end
function onOpen3() open(3) end
function onOpen4() open(4) end
function onOpen5() open(5) end
function onOpen6() open(6) end
function onOpen7() open(7) end
function onOpen8() open(8) end
function onOpen9() open(9) end
function onOpen10() open(10) end
function onOpen11() open(11) end
function onOpen12() open(12) end
