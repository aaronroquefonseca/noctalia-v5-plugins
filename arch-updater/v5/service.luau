local STATE_KEY = "updates"
local REFRESH_KEY = "refresh_request"
local UPDATE_KEY = "update_request"
local busy = false
local refreshToken = nil
local updateToken = nil

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
  if busy then return end
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

local function launchUpdate()
  local command = tostring(noctalia.getConfig("update_command") or "")
  if command == "" then
    noctalia.notify("Arch Updater", "Update command is empty")
    return
  end
  local started = noctalia.runAsync(command, function(result)
    if result.exitCode ~= 0 then
      noctalia.notify("Arch Updater", "Updater exited with code " .. tostring(result.exitCode))
    end
    refresh()
  end, 86400000)
  if not started then noctalia.notify("Arch Updater", "Could not launch updater") end
end

noctalia.state.watch(REFRESH_KEY, function(value)
  local token = type(value) == "table" and value.token or value
  if token ~= nil and token ~= refreshToken then refreshToken = token; refresh() end
end)

noctalia.state.watch(UPDATE_KEY, function(value)
  local token = type(value) == "table" and value.token or value
  if token ~= nil and token ~= updateToken then updateToken = token; launchUpdate() end
end)

local function setInterval()
  local minutes = tonumber(noctalia.getConfig("refresh_interval_minutes")) or 120
  noctalia.setUpdateInterval(math.max(5, math.min(1440, minutes)) * 60000)
end

function update() refresh() end
function onConfigChanged() setInterval(); refresh() end
setInterval()
