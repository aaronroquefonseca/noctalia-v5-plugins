local queries = {}

local ENGINES = {
  startpage = {
    name = "Startpage",
    template = "https://www.startpage.com/sp/search?query={query}",
  },
  google = {
    name = "Google",
    template = "https://www.google.com/search?q={query}",
  },
  duckduckgo = {
    name = "DuckDuckGo",
    template = "https://duckduckgo.com/?q={query}",
  },
}

local function trim(value)
  return noctalia.string.trim(tostring(value or ""))
end

local function shellQuote(value)
  return "'" .. string.gsub(tostring(value or ""), "'", "'\\''") .. "'"
end

local function urlEncode(value)
  return (tostring(value or ""):gsub("([^%w%-_%.~])", function(character)
    return string.format("%%%02X", string.byte(character))
  end))
end

local function engine()
  local selected = tostring(noctalia.getConfig("search_engine") or "startpage")
  if selected == "custom" then
    return {
      name = "Custom",
      template = tostring(noctalia.getConfig("custom_search_url") or ""),
    }
  end
  return ENGINES[selected] or ENGINES.startpage
end

local function searchUrl(query)
  local selected = engine()
  local encoded = urlEncode(query)
  local template = selected.template
  if template:find("{query}", 1, true) then
    return (template:gsub("{query}", function()
      return encoded
    end))
  end
  return template .. encoded
end

function onQuery(query)
  local text = trim(query)
  local selected = engine()
  if text == "" then
    launcher.setResults(query, {
      {
        id = "",
        title = "Type a web search",
        subtitle = "Search with " .. selected.name .. " in your default browser",
        glyph = "world-search",
      },
    })
    return
  end

  local id = "search:" .. text
  queries[id] = text
  launcher.setResults(query, {
    {
      id = id,
      title = "Search for “" .. text .. "”",
      subtitle = selected.name .. " · default browser",
      glyph = "world-search",
    },
  })
end

function onActivate(id)
  local query = queries[id]
  if type(query) ~= "string" or query == "" then return end
  local url = searchUrl(query)
  if url == "" then
    noctalia.notify("Web Search", "Custom search URL is empty")
    return
  end
  local command = "nohup xdg-open " .. shellQuote(url) .. " >/dev/null 2>&1 &"
  local started = noctalia.runAsync(command, function(result)
    if result.exitCode ~= 0 then
      noctalia.notify("Web Search", "Could not open the default browser")
    end
  end, 5000)
  if not started then
    noctalia.notify("Web Search", "Could not start xdg-open")
  end
end
