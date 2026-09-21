local STATE_KEY = "usage"
local REFRESH_KEY = "refresh_request"

local busy = false
local lastRequest = nil

local function quote(value)
  local text = tostring(value or "")
  return "'" .. string.gsub(text, "'", "'\\''") .. "'"
end

local function intervalMs()
  local seconds = tonumber(noctalia.getConfig("refresh_interval_seconds")) or 300
  return math.max(60, math.min(3600, seconds)) * 1000
end

local function publish(value)
  noctalia.state.set(STATE_KEY, value)
end

local function failure(message)
  local previous = noctalia.state.get(STATE_KEY) or {}
  previous.ok = false
  previous.loading = false
  previous.error = tostring(message or "Unable to read OpenCode Go usage")
  previous.updatedAt = os.time()
  publish(previous)
end

local function refresh()
  if busy then return end
  busy = true

  local previous = noctalia.state.get(STATE_KEY) or {}
  previous.loading = true
  publish(previous)

  local helper = noctalia.pluginDir() .. "/opencode_go_usage.py"
  local command = "python3 " .. quote(helper)

  local started = noctalia.runAsync(command, function(result)
    busy = false
    if result.timedOut then
      failure("OpenCode Go usage request timed out")
      return
    end

    local decoded, decodeError = noctalia.json.decode(result.stdout or "")
    if type(decoded) ~= "table" then
      local detail = result.stderr or decodeError or "Invalid helper response"
      failure(detail)
      return
    end

    decoded.loading = false
    decoded.updatedAt = os.time()
    if result.exitCode ~= 0 and decoded.ok ~= false then
      decoded.ok = false
      decoded.error = result.stderr or "OpenCode Go helper failed"
    end
    publish(decoded)
  end, 25000)

  if not started then
    busy = false
    failure("Could not start the OpenCode Go usage helper")
  end
end

noctalia.state.watch(REFRESH_KEY, function(value)
  local token = type(value) == "table" and value.token or value
  if token ~= nil and token ~= lastRequest then
    lastRequest = token
    refresh()
  end
end)

noctalia.setUpdateInterval(intervalMs())

function update()
  refresh()
end

function onConfigChanged()
  noctalia.setUpdateInterval(intervalMs())
  refresh()
end
