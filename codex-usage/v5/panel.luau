local state=noctalia.state.get("usage") or {loading=true}
local view="usage"
local seq=0
local icon=noctalia.pluginDir().."/../icons/openai.svg"

local function rem(w)
  if type(w)~="table" or type(w.usedPercent)~="number" then return nil end
  return math.max(0,math.min(100,100-w.usedPercent))
end
local function name(m)
  if type(m)~="number" then return "Usage window" end
  if m%10080==0 then return (m/10080).."-week window" end
  if m%1440==0 then return (m/1440).."-day window" end
  if m%60==0 then return (m/60).."-hour window" end
  return m.."-minute window"
end
local function resetText(t)
  if type(t)~="number" then return "Reset time unavailable" end
  local d=math.max(0,t-os.time())
  if d<60 then return "Resets in less than a minute" end
  if d<3600 then return "Resets in "..math.ceil(d/60).." min" end
  if d<86400 then return "Resets in "..math.floor(d/3600).."h "..math.ceil((d%3600)/60).."m" end
  return "Resets "..noctalia.formatTime("%a %H:%M",t)
end
local function sev(v)
  if not v then return "on_surface" end
  if v<=10 then return "error" end
  if v<=25 then return "tertiary" end
  return "primary"
end
local function card(w,k)
  local v=rem(w)
  return ui.column({key=k,fill="surface_variant",radius=12,padding=12,gap=7},{
    ui.row({justify="space_between",align="center"},{ui.label({text=name(w.windowDurationMins),fontWeight="semibold",flexGrow=1}),ui.label({text=v and v.."%" or "—",color=sev(v),fontSize=18,fontWeight="bold"})}),
    ui.label({text=resetText(w.resetsAt),color="on_surface_variant",fontSize=12}),
    ui.progress({progress=v and v/100 or 0,fill=sev(v),track="outline/0.35",height=6,radius=3})})
end
local function resets()
  local s=type(state.resetCredits)=="table" and state.resetCredits or {}
  local a={}
  for _,c in ipairs(type(s.credits)=="table" and s.credits or {}) do
    if type(c)=="table" and string.lower(tostring(c.status or ""))=="available" then table.insert(a,c) end
  end
  table.sort(a,function(x,y)return (tonumber(x.expiresAt) or math.huge)<(tonumber(y.expiresAt) or math.huge) end)
  return a,tonumber(s.availableCount) or #a
end
local function expiry(t)
  if t==nil then return "Does not expire" end
  if type(t)~="number" then return "Expiration unavailable" end
  return "Expires "..noctalia.formatTime("%H:%M on %d %b %Y",t)
end
local function renderUsage()
  local l=type(state.rateLimits)=="table" and state.rateLimits or {}
  local c=type(l.credits)=="table" and l.credits or {}
  local _,n=resets()
  local ch={ui.row({gap=10,align="center"},{ui.image({path=icon,width=22,height=22}),ui.label({text="Codex usage",fontSize=19,fontWeight="bold",flexGrow=1}),ui.label({text=tostring(l.planType or ""),color="on_surface_variant",fontSize=12})}),ui.separator({color="outline/0.4"})}
  if state.ok==false then table.insert(ch,ui.label({text=tostring(state.error or "Unable to read Codex usage"),color="error",maxLines=4})) end
  if l.primary then table.insert(ch,card(l.primary,"primary")) end
  if l.secondary then table.insert(ch,card(l.secondary,"secondary")) end
  table.insert(ch,ui.row({gap=10,align="stretch"},{ui.column({flexGrow=1,fill="surface_variant",radius=12,padding=10,align="center"},{ui.label({text=c.unlimited and "∞" or tostring(c.balance or "—"),fontSize=17,fontWeight="bold"}),ui.label({text="Credits",color="on_surface_variant",fontSize=12})}),ui.button({text=n.."  Limit resets",glyph="chevron-right",variant="outline",flexGrow=1,onClick="onResets"})}))
  table.insert(ch,ui.separator({color="outline/0.4"}))
  table.insert(ch,ui.label({text=state.loading and "Refreshing…" or (state.updatedAt and "Updated at "..noctalia.formatTime("%H:%M",state.updatedAt) or "Not updated yet"),color="on_surface_variant",fontSize=12}))
  table.insert(ch,ui.row({gap=8},{ui.button({text="Refresh",glyph="refresh",variant="outline",enabled=not state.loading,flexGrow=1,onClick="onRefresh"}),ui.button({text="Close",glyph="close",variant="ghost",onClick="onClose"})}))
  panel.render(ui.column({padding=16,gap=10,fill="surface"},ch))
end
local function renderResets()
  local a,n=resets()
  local ch={ui.row({gap=8,align="center"},{ui.button({glyph="chevron-left",variant="ghost",onClick="onBack"}),ui.label({text="Limit resets",fontSize=19,fontWeight="bold",flexGrow=1}),ui.label({text=tostring(n),color="on_surface_variant"})}),ui.separator({color="outline/0.4"}),ui.label({text=n.." usage limit resets available.",fontWeight="semibold"})}
  for i,c in ipairs(a) do table.insert(ch,ui.column({key="r"..i,fill="surface_variant",radius=10,padding=8,gap=2},{ui.label({text=tostring(c.title or "Full reset"),fontWeight="semibold"}),ui.label({text=expiry(c.expiresAt),color="on_surface_variant",fontSize=12})})) end
  if n==0 then table.insert(ch,ui.label({text="No usage limit resets available.",color="on_surface_variant"})) elseif n>#a then table.insert(ch,ui.label({text="Some expiration details are unavailable.",color="on_surface_variant",fontSize=12})) end
  table.insert(ch,ui.button({text="Close",glyph="close",variant="outline",onClick="onClose"}))
  panel.render(ui.column({padding=14,gap=8,fill="surface"},ch))
end
local function render() if view=="resets" then renderResets() else renderUsage() end end
noctalia.state.watch("usage",function(v) state=type(v)=="table" and v or {loading=true};render() end)
panel.setWantsSecondTicks(true)
function update() render() end
function onOpen() view="usage";render() end
function onClose() view="usage";panel.close() end
function onResets() view="resets";render() end
function onBack() view="usage";render() end
function onRefresh() seq=seq+1;noctalia.state.set("refresh_request",{token=tostring(os.time())..":"..seq}) end
