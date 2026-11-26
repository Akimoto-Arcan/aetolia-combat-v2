local root=assert(arg[1]); local nextId=0;local live={event={},trigger={},alias={},timer={}};local sent={};local gc={};local now=100
local function add(kind,fn,name) nextId=nextId+1;live[kind][nextId]={fn=fn,name=name};return nextId end
function registerAnonymousEventHandler(name,fn) return add('event',fn,name) end
function killAnonymousEventHandler(h) live.event[h]=nil end
function tempRegexTrigger(rx,fn)return add('trigger',fn,rx)end
function tempPromptTrigger(fn)return add('trigger',fn,'PROMPT')end
function killTrigger(h)live.trigger[h]=nil end
function tempAlias(rx,fn)return add('alias',fn,rx)end
function killAlias(h)live.alias[h]=nil end
function tempTimer(delay,fn)return add('timer',fn,delay)end
function killTimer(h)live.timer[h]=nil end
function getEpoch()return now end
function send(s)sent[#sent+1]=s end
function sendGMCP(s)gc[#gc+1]=s end
function cecho()end
local count=0
local function check(x,label)assert(x,label);count=count+1 end
local function size(t)local n=0;for _ in pairs(t)do n=n+1 end;return n end
local function fire(name) local fs={};for _,h in pairs(live.event)do if h.name==name then fs[#fs+1]=h.fn end end;for _,fn in ipairs(fs)do fn(name,'ManualBasher')end end
local db=dofile(root..'/mobs.lua');local names={};local presets=0
for _,a in pairs(db)do presets=presets+1;for n in pairs(a.mobs)do names[n]=true end end
check(presets==106,'106 real presets');check(size(names)==710,'710 unique exact names')
dofile(root..'/ManualBasher-bundled.lua');check(#sent==0 and #gc==0 and not ManualBasher.state.enabled,'bundle import inert OFF')
local old=ManualBasher;local events,triggers,aliases=size(live.event),size(live.trigger),size(live.alias)
old.state.pending={seq=0,at=now,lost=false,kind='irongrip',ack=false}
dofile(root..'/ManualBasher-bundled.lua');check(old.state.destroyed,'reload old destroyed');check(size(live.event)==events and size(live.trigger)==triggers and size(live.alias)==aliases,'reload no duplicate callbacks');check(ManualBasher.state.pending and not ManualBasher.state.enabled,'reload preserves pending OFF')
gmcp={Char={Status={name='Home',class='Earthcaller'}}};fire('gmcp.Char.Status');check(ManualBasher.state.status.name=='Home','status native adapter')
ManualBasher.state.ironQuery=now
for _,h in pairs(live.trigger)do if h.name=='^.*[Ii]rongrip.*$'then matches={'Irongrip (Racial)                             Known: Yes'};h.fn()end end
check(ManualBasher.state.ironKnown==true and ManualBasher.state.ironQuery==nil,'actual same-line Irongrip Known header')
ManualBasher.iron(true)
for _,h in pairs(live.trigger)do if h.name=='^Your irongrip defence has been stripped\\.$'then h.fn()end end
check(ManualBasher.state.ironActive==false,'actual native stripped-defence line')
fire('sysDisconnectionEvent');check(not ManualBasher.state.enabled and ManualBasher.state.status==nil,'native disconnect OFF')
combat_v2={};check(not ManualBasher.on(),'bundle CV2 refusal');combat_v2=nil
fire('sysUninstallPackage');check(size(live.event)==0 and size(live.trigger)==0 and size(live.alias)==0 and size(live.timer)==0,'uninstall kills all owned callbacks/timers');check(ManualBasher.state.destroyed,'uninstall disarms object')
print('PASS '..count..' bundle/catalog assertions ('.._VERSION..')')
