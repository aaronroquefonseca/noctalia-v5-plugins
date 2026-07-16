local activeRequest = 0
local resultsById = {}

local function trim(value)
  return noctalia.string.trim(tostring(value or ""))
end

local function shellQuote(value)
  return "'" .. string.gsub(tostring(value or ""), "'", "'\\''") .. "'"
end

local function rootsJson()
  local roots = noctalia.getConfig("search_roots")
  if type(roots) ~= "table" or #roots == 0 then roots = { "~" } end
  return noctalia.json.encode(roots)
end

local function errorRow(title, subtitle)
  return { id = "", title = title, subtitle = subtitle, glyph = "alert-circle" }
end

local function openerCommand(template, path)
  local quotedPath = shellQuote(path)
  if template:find("{path}", 1, true) then
    return (template:gsub("{path}", function() return quotedPath end))
  end
  return template .. " " .. quotedPath
end

function onQuery(query)
  local text = trim(query)
  activeRequest = activeRequest + 1
  local request = activeRequest
  resultsById = {}

  if text == "" then
    launcher.setResults(query, {
      { id = "", title = "Type a file or folder name", subtitle = "Search configured folders", glyph = "file-search" },
    })
    return
  end

  launcher.setResults(query, {
    { id = "", title = "Searching…", subtitle = text, glyph = "loader" },
  })

  local helper = noctalia.pluginDir() .. "/file_search.py"
  local command = "python3 " .. shellQuote(helper)
    .. " --query " .. shellQuote(text)
    .. " --roots-json " .. shellQuote(rootsJson())
    .. " --limit " .. tostring(tonumber(noctalia.getConfig("max_results")) or 80)
    .. " --fd-command " .. shellQuote(tostring(noctalia.getConfig("fd_command") or "fd"))
  if noctalia.getConfig("show_hidden") == true then command = command .. " --hidden" end

  local started = noctalia.runAsync(command, function(result)
    if request ~= activeRequest then return end
    if result.timedOut then
      launcher.setResults(query, { errorRow("File search timed out", "Try a narrower search root") })
      return
    end
    local decoded = noctalia.json.decode(result.stdout or "")
    if type(decoded) ~= "table" or decoded.ok ~= true then
      local message = type(decoded) == "table" and decoded.error or result.stderr
      launcher.setResults(query, { errorRow("File search failed", tostring(message or "Invalid helper response")) })
      return
    end
    local rows = {}
    for index, item in ipairs(type(decoded.results) == "table" and decoded.results or {}) do
      local id = "result:" .. tostring(index)
      resultsById[id] = {
        path = tostring(item.path or ""),
        directory = item.directory == true,
      }
      table.insert(rows, {
        id = id,
        title = tostring(item.name or item.path or "?"),
        subtitle = tostring(item.parent or ""),
        glyph = item.directory == true and "folder" or "file",
      })
    end
    if #rows == 0 then
      rows[1] = { id = "", title = "No matches", subtitle = "No file or folder contains “" .. text .. "”", glyph = "file-off" }
    end
    launcher.setResults(query, rows)
  end, 15000)

  if not started then
    launcher.setResults(query, { errorRow("File search failed", "Could not start helper") })
  end
end

function onActivate(id)
  local result = resultsById[id]
  if type(result) ~= "table" or result.path == "" then return end
  local key = result.directory and "directory_opener" or "file_opener"
  local fallback = result.directory and "nautilus {path}" or "xdg-open {path}"
  local template = tostring(noctalia.getConfig(key) or fallback)
  local command = "nohup " .. openerCommand(template, result.path) .. " >/dev/null 2>&1 &"
  local started = noctalia.runAsync(command, function(result)
    if result.exitCode ~= 0 then noctalia.notify("File Search", "Could not open result") end
  end, 5000)
  if not started then noctalia.notify("File Search", "Could not start xdg-open") end
end
