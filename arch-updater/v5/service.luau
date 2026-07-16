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

local function helperCommand()
  local helper = noctalia.pluginDir() .. "/../update_check.py"
  local systemCommand = tostring(noctalia.getConfig("system_command") or "")
  local aurCommand = tostring(noctalia.getConfig("aur_command") or "")
  local flatpak = noctalia.getConfig("flatpak_enabled") ~= false
  return "python3 " .. quote(helper)
    .. " --system-command " .. quote(systemCommand)
    .. " --aur-command " .. quote(aurCommand)
    .. (flatpak and " --flatpak" or "")
end

local function publishFailure(message)
  noctalia.state.set(STATE_KEY, {
    ok = false,
    loading = false,
    error = tostring(message or "Update check failed"),
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

  local started = noctalia.runAsync(helperCommand(), function(result)
    busy = false
    if result.timedOut then publishFailure("Update check timed out"); return end
    local decoded, decodeError = noctalia.json.decode(result.stdout or "")
    if type(decoded) ~= "table" then
      publishFailure(result.stderr or decodeError or "Invalid update-check response")
      return
    end
    decoded.loading = false
    decoded.updatedAt = os.time()
    noctalia.state.set(STATE_KEY, decoded)
  end, 120000)
  if not started then busy = false; publishFailure("Could not start update check") end
end

local function updateStatePath()
  local directory = noctalia.getenv("XDG_RUNTIME_DIR")
  if directory == nil or directory == "" then directory = "/tmp" end
  return directory .. "/noctalia-arch-updater-state.json"
end

local function pollUpdate()
  local path = updateStatePath()
  if path == nil then return false end
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
  if path == nil then noctalia.notify("Arch Updater", "Could not access plugin data"); return end
  noctalia.writeFile(path, noctalia.json.encode({ running = true, startedAt = os.time() }))
  local runner = noctalia.pluginDir() .. "/../update_runner.py"
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
  if updateRunning or noctalia.fileExists(updateStatePath() or "") then pollUpdate() else refresh() end
end
function onConfigChanged() setInterval(); refresh() end
if not pollUpdate() then setInterval() end
