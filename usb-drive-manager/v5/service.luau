local STATE_KEY = "devices"
local REFRESH_KEY = "refresh_request"
local ACTION_KEY = "action_request"
local busy = false
local lastRefreshToken = nil
local lastActionToken = nil

local function quote(value)
  return "'" .. string.gsub(tostring(value or ""), "'", "'\\''") .. "'"
end

local function helper()
  return noctalia.pluginDir() .. "/../usb_manager.py"
end

local function publishFailure(message)
  noctalia.state.set(STATE_KEY, {
    ok = false,
    loading = false,
    error = tostring(message or "Could not list USB drives"),
    devices = {},
    count = 0,
    updatedAt = os.time(),
  })
end

local function refresh()
  if busy then return end
  busy = true
  local previous = noctalia.state.get(STATE_KEY) or { devices = {}, count = 0 }
  previous.loading = true
  noctalia.state.set(STATE_KEY, previous)
  local command = "python3 " .. quote(helper()) .. " list"
  local started = noctalia.runAsync(command, function(result)
    busy = false
    if result.timedOut then publishFailure("USB drive query timed out"); return end
    local decoded = noctalia.json.decode(result.stdout or "")
    if type(decoded) ~= "table" or decoded.ok ~= true then
      publishFailure(type(decoded) == "table" and decoded.error or result.stderr)
      return
    end
    decoded.loading = false
    decoded.updatedAt = os.time()
    noctalia.state.set(STATE_KEY, decoded)
  end, 10000)
  if not started then busy = false; publishFailure("Could not start USB drive query") end
end

local function action(request)
  if type(request) ~= "table" then return end
  local actionName = tostring(request.action or "")
  local path = tostring(request.path or "")
  if actionName == "" or path == "" then return end
  local command = "python3 " .. quote(helper()) .. " action --action " .. quote(actionName) .. " --path " .. quote(path)
  local started = noctalia.runAsync(command, function(result)
    local decoded = noctalia.json.decode(result.stdout or "")
    local ok = type(decoded) == "table" and decoded.ok == true
    if noctalia.getConfig("show_notifications") ~= false then
      if ok then
        noctalia.notify("USB Drive Manager", tostring(decoded.message or "Action completed"))
      else
        local message = type(decoded) == "table" and decoded.error or result.stderr
        noctalia.notify("USB Drive Manager", tostring(message or "Drive action failed"))
      end
    end
    refresh()
  end, 120000)
  if not started and noctalia.getConfig("show_notifications") ~= false then
    noctalia.notify("USB Drive Manager", "Could not start drive action")
  end
end

noctalia.state.watch(REFRESH_KEY, function(value)
  local token = type(value) == "table" and value.token or value
  if token ~= nil and token ~= lastRefreshToken then lastRefreshToken = token; refresh() end
end)

noctalia.state.watch(ACTION_KEY, function(value)
  local token = type(value) == "table" and value.token or nil
  if token ~= nil and token ~= lastActionToken then lastActionToken = token; action(value) end
end)

local function setInterval()
  local seconds = tonumber(noctalia.getConfig("refresh_seconds")) or 5
  noctalia.setUpdateInterval(math.max(2, math.min(60, seconds)) * 1000)
end

function update() refresh() end
function onConfigChanged() setInterval(); refresh() end
setInterval()
