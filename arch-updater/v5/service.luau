local STATE_KEY = "updates"
local REFRESH_KEY = "refresh_request"
local UPDATE_KEY = "update_request"
local busy = false
local updateRunning = false
local refreshToken = nil
local updateToken = nil
local setInterval

local function quote(value)
  return "'" .. string.gsub(tostring(value or ""), "'", "'\\''") .. "'"
end

local function parseArch(output, source)
  local updates = {}
  for line in string.gmatch(tostring(output or ""), "[^\r\n]+") do
    local name, oldVersion, newVersion = string.match(line, "^(%S+)%s+(%S+)%s+%-%>%s+(%S+)")
    if name then
      table.insert(updates, {
        id = name,
        name = name,
        oldVersion = oldVersion,
        newVersion = newVersion,
        source = source,
      })
    end
  end
  return updates
end

local function parseFlatpak(output)
  local updates = {}
  for line in string.gmatch(tostring(output or ""), "[^\r\n]+") do
    local app, version = string.match(line, "^([^\t]+)\t?(.*)$")
    app = app and noctalia.string.trim(app) or nil
    version = version and noctalia.string.trim(version) or ""
    if app and app ~= "" then
      table.insert(updates, {
        id = app,
        name = app,
        oldVersion = "installed",
        newVersion = version ~= "" and version or "available",
        source = "flatpak",
      })
    end
  end
  return updates
end

local function publishFailure(message)
  noctalia.state.set(STATE_KEY, {
    ok = false,
    loading = false,
    error = tostring(message or "Update check failed"),
    warnings = { tostring(message or "Update check failed") },
    updates = {},
    count = 0,
    updatedAt = os.time(),
  })
end

local function refresh()
  if busy or updateRunning then return end
  busy = true

  local previous = noctalia.state.get(STATE_KEY) or { updates = {}, count = 0 }
  previous.loading = true
  noctalia.state.set(STATE_KEY, previous)

  local updates = {}
  local warnings = {}
  local pending = 0

  local function finish()
    if pending > 0 then return end
    busy = false
    table.sort(updates, function(a, b)
      if tostring(a.source) ~= tostring(b.source) then return tostring(a.source) < tostring(b.source) end
      return string.lower(tostring(a.name)) < string.lower(tostring(b.name))
    end)
    local noctaliaUpdate = false
    for _, item in ipairs(updates) do
      local name = tostring(item.name or "")
      if name == "noctalia" or name == "noctalia-git" or name == "noctalia-qs" or name == "noctalia-shell" then
        noctaliaUpdate = true
        break
      end
    end
    noctalia.state.set(STATE_KEY, {
      ok = #warnings == 0,
      loading = false,
      error = #warnings > 0 and table.concat(warnings, "\n") or nil,
      warnings = warnings,
      updates = updates,
      count = #updates,
      noctaliaUpdate = noctaliaUpdate,
      updatedAt = os.time(),
    })
  end

  local function launch(source, command, parser, timeout, flatpak)
    if command == nil or command == "" then return end
    pending = pending + 1
    local started = noctalia.runAsync(command, function(result)
      local parsed = parser(result.stdout or "", source)
      for _, item in ipairs(parsed) do table.insert(updates, item) end

      local code = tonumber(result.exitCode) or 0
      if result.timedOut then
        table.insert(warnings, source .. " check timed out")
      elseif flatpak then
        if code ~= 0 then table.insert(warnings, source .. " check exited with code " .. tostring(code)) end
      elseif code ~= 0 and code ~= 1 and code ~= 2 and #parsed == 0 then
        local detail = noctalia.string.trim(tostring(result.stderr or ""))
        table.insert(warnings, detail ~= "" and detail or (source .. " check exited with code " .. tostring(code)))
      end
      pending = pending - 1
      finish()
    end, timeout or 120000)

    if not started then
      table.insert(warnings, "Could not start " .. source .. " update check")
      pending = pending - 1
    end
  end

  launch("system", tostring(noctalia.getConfig("system_command") or ""), parseArch, 120000, false)
  launch("aur", tostring(noctalia.getConfig("aur_command") or ""), parseArch, 120000, false)
  if noctalia.getConfig("flatpak_enabled") ~= false and noctalia.commandExists("flatpak") then
    launch("flatpak", "flatpak remote-ls --updates --columns=application,version 2>/dev/null", parseFlatpak, 120000, true)
  end
  finish()
end

local function updateStatePath()
  local directory = noctalia.getenv("XDG_RUNTIME_DIR")
  if directory == nil or directory == "" then directory = "/tmp" end
  return directory .. "/noctalia-arch-updater-state.json"
end

local function pollUpdate()
  local path = updateStatePath()
  local raw = noctalia.readFile(path)
  if raw == nil then return false end
  local status = noctalia.json.decode(raw)
  if type(status) ~= "table" then return false end
  if status.running == true then
    updateRunning = true
    setInterval()
    return true
  end
  updateRunning = false
  noctalia.removeFile(path)
  setInterval()
  local exitCode = tonumber(status.exitCode) or 1
  if exitCode ~= 0 then
    noctalia.notify("Arch Updater", "Updater exited with code " .. tostring(exitCode))
  end
  refresh()
  return false
end

local function launchUpdate()
  if updateRunning or pollUpdate() then
    noctalia.notify("Arch Updater", "Updater is already running")
    return
  end
  local command = tostring(noctalia.getConfig("update_command") or "")
  if command == "" then
    noctalia.notify("Arch Updater", "Update command is empty")
    return
  end
  local path = updateStatePath()
  noctalia.writeFile(path, noctalia.json.encode({ running = true, startedAt = os.time() }))
  local runner = noctalia.pluginDir() .. "/update_runner.py"
  local unit = "noctalia-arch-updater-" .. tostring(os.time())
  local runnerCommand = "systemd-run --user --unit=" .. quote(unit)
    .. " --collect --quiet --service-type=exec --property=ManagedOOMPreference=avoid python3 " .. quote(runner)
    .. " --state " .. quote(path) .. " --command " .. quote(command)
  updateRunning = true
  setInterval()
  local started = noctalia.runAsync(runnerCommand)
  if not started then
    updateRunning = false
    noctalia.removeFile(path)
    setInterval()
    noctalia.notify("Arch Updater", "Could not launch updater")
  end
end

noctalia.state.watch(REFRESH_KEY, function(value)
  local token = type(value) == "table" and value.token or value
  if token ~= nil and token ~= refreshToken then refreshToken = token; refresh() end
end)

noctalia.state.watch(UPDATE_KEY, function(value)
  local token = type(value) == "table" and value.token or value
  if token ~= nil and token ~= updateToken then updateToken = token; launchUpdate() end
end)

setInterval = function()
  if updateRunning then noctalia.setUpdateInterval(2000); return end
  local minutes = tonumber(noctalia.getConfig("refresh_interval_minutes")) or 120
  noctalia.setUpdateInterval(math.max(5, math.min(1440, minutes)) * 60000)
end

function update()
  if updateRunning or noctalia.fileExists(updateStatePath()) then pollUpdate() else refresh() end
end
function onConfigChanged() setInterval(); refresh() end
if not pollUpdate() then setInterval() end
