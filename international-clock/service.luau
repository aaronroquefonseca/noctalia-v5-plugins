--!nonstrict
-- Reads both clocks from the system timezone database. Europe/Dublin applies
-- Ireland's GMT/IST daylight-saving rules automatically.

local DATE_COMMAND = [[
printf '%s\n' "$(date '+%H:%M:%S|%z|%Z')" "$(TZ=Europe/Dublin date '+%H:%M:%S|%z|%Z')"
]]

local requestPending = false

local function parseClock(line)
  local time, offset, zone = line:match("^([^|]+)|([^|]+)|(.+)$")
  if time == nil or offset == nil or zone == nil then
    return nil
  end
  return { time = time, offset = offset, zone = zone }
end

local function publishFailure(message)
  noctalia.state.set("clocks", {
    ok = false,
    error = message,
    updatedAt = os.time(),
  })
end

local function refresh()
  if requestPending then
    return
  end

  requestPending = true
  local accepted = noctalia.runAsync(DATE_COMMAND, function(result)
    requestPending = false

    if result.timedOut == true or result.exitCode ~= 0 then
      publishFailure("Could not read system time")
      return
    end

    local rows = {}
    for line in tostring(result.stdout or ""):gmatch("[^\r\n]+") do
      table.insert(rows, line)
    end

    local localClock = rows[1] and parseClock(rows[1]) or nil
    local irelandClock = rows[2] and parseClock(rows[2]) or nil
    if localClock == nil or irelandClock == nil then
      publishFailure("Could not parse system time")
      return
    end

    noctalia.state.set("clocks", {
      ok = true,
      localClock = localClock,
      irelandClock = irelandClock,
      updatedAt = os.time(),
    })
  end, 2000)

  if not accepted then
    requestPending = false
    publishFailure("Could not start clock update")
  end
end

noctalia.setUpdateInterval(1000)
refresh()

function update()
  refresh()
end
