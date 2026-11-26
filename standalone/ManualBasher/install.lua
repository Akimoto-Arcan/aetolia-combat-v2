-- Appended to the factory and embedded catalog by build.py. No external dependencies.
local old=rawget(_G,'ManualBasher')
local carry=old and old.state and old.state.pending
if old and old.cleanup then old.cleanup() end
local handles={events={},triggers={},aliases={},timers={}}
local obj
local function cleanup()
 for _,h in ipairs(handles.events) do killAnonymousEventHandler(h) end
 for _,h in ipairs(handles.triggers) do killTrigger(h) end
 for _,h in ipairs(handles.aliases) do killAlias(h) end
 for h in pairs(handles.timers) do killTimer(h) end
end
local function later()
 local h
 h=tempTimer(10.2,function() handles.timers[h]=nil; if obj and not obj.state.destroyed then obj.timeout() end end)
 handles.timers[h]=true
end
local function conflict()
 for _,k in ipairs({'combat_v2','CombatV2','svo','svof','m-mf','ak','rime','iasha','Iasha'}) do if rawget(_G,k)~=nil then return true end end
 return false
end
obj=Factory.new({
 now=function() return getEpoch() end,
 notice=function(s) cecho('\n<orange>'..s..'<reset>\n') end,
 send=function(s) send(s,false); later() end,
 gmcp=function(s) sendGMCP(s); later() end,
 conflict=conflict, cleanup=cleanup
},DB)
ManualBasher=obj
if carry then obj.state.pending={seq=0,at=getEpoch(),lost=carry.lost,kind=carry.kind,ack=carry.ack}; later() end
local function event(name,fn)
 handles.events[#handles.events+1]=registerAnonymousEventHandler(name,fn)
end
local function packet(a,b) return gmcp and gmcp[a] and gmcp[a][b] end
local function items(kind)
 local msg=gmcp and gmcp.Char and gmcp.Char.Items and gmcp.Char.Items[kind]
 if kind=='List' then obj.list(msg); obj.inv(msg) else obj.item(kind:lower(),msg); obj.invItem(kind:lower(),msg) end
end
event('gmcp.Room.Info',function() obj.room(packet('Room','Info')) end)
event('gmcp.Char.Status',function() obj.status(packet('Char','Status')) end)
event('gmcp.Char.Vitals',function() obj.vitals(packet('Char','Vitals') or {}) end)
for _,kind in ipairs({'List','Add','Update','Remove'}) do local k=kind; event('gmcp.Char.Items.'..k,function() items(k) end) end
local affs
for _,kind in ipairs({'List','Add','Remove'}) do
 local k=kind
 event('gmcp.Char.Afflictions.'..k,function()
  local msg=gmcp and gmcp.Char and gmcp.Char.Afflictions and gmcp.Char.Afflictions[k]
  if k=='List' then affs={}; for _,v in pairs(msg or {}) do affs[type(v)=='table' and v.name or v]=true end
  elseif affs then local n=type(msg)=='table' and msg.name or msg; if n then affs[n]=k=='Add' or nil end end
  obj.afflictions(affs)
 end)
 event('gmcp.Char.Defences.'..k,function() obj.defences(k:lower(),gmcp and gmcp.Char and gmcp.Char.Defences and gmcp.Char.Defences[k]) end)
end
handles.triggers[#handles.triggers+1]=tempPromptTrigger(function() obj.prompt() end)
local function rx(pattern,fn) handles.triggers[#handles.triggers+1]=tempRegexTrigger(pattern,fn) end
rx('^You have gained the irongrip defence\\.$',function() obj.iron(true) end)
rx('^You have lost the irongrip defence\\.$',function() obj.iron(false) end)
rx('^Your irongrip defence has been stripped\\.$',function() obj.iron(false) end)
rx('^.*[Ii]rongrip.*$',function()
 if obj.state.ironQuery then
  local text=tostring(matches and matches[1] or '')
  local known=text:match('Known:%s*(Yes)') or text:match('Known:%s*(No)')
  if known then obj.state.ironHeader=nil; obj.ironKnown(known=='Yes')
  else obj.state.ironHeader=true end
 end
end)
rx('^\\s*Known\\s*:\\s*(Yes|No)\\s*$',function()
 if obj.state.ironQuery and obj.state.ironHeader then obj.state.ironHeader=nil; obj.ironKnown(matches[2]=='Yes') end
end)
handles.aliases[#handles.aliases+1]=tempAlias('^mb(?:\\s+(.*))?$',function() obj.command(matches[2] or 'help') end)
event('sysDisconnectionEvent',function() affs=nil; obj.disconnect() end)
event('sysConnectionEvent',function() affs=nil; obj.disconnect() end)
event('sysUninstallPackage',function(_,name) if name=='ManualBasher' or name=='ManualBasher.xml' then obj.cleanup() end end)
-- No initialization from cached GMCP: require new events on this connection.
cecho('\n<orange>[ManualBasher] Loaded OFF. Separate clean profile required. Enable GMCP, reconnect, then mb help.<reset>\n')
