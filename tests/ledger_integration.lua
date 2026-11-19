-- Actual supplies + ledger + quarantined helper, entirely offline.
local root=assert(arg[1]);local S=dofile(root..'supplies.lua');local L=dofile(root..'ledger.lua');local C=dofile(root..'containers.lua')
local t,n=100,0;local commands={};local timers={};local serial=0
local function check(v,msg)n=n+1;assert(v,msg)end
function tempTimer(_,fn)serial=serial+1;timers[serial]=fn;return serial end
function killTimer(id)timers[id]=nil end
function registerAnonymousEventHandler()serial=serial+1;return serial end
function killAnonymousEventHandler()end
function tempRegexTrigger()serial=serial+1;return serial end
function tempPromptTrigger()serial=serial+1;return serial end
function killTrigger()end
local R={waiting=true,recovery_snapshot={identity=1}};local E={armed=true,committed=true,pending={phase='unknown'}}
local c={mode='BASH',runner=R,elemental_recovery=E,ledger=L,containers=C,supplies_clock=function()return t end,supplies_connected=function()return true end,supplies_position={x=205,y=9}}
c.containers_data={version=1,sources={},learned={},quarantine='retained test quarantine',barrier={fault='unknown action',id='pipe9',kind='pipe',type='yarrow',phase='waiting',at=t}}
S.attach(c);c.supplies=S;S.bind_containers(c,function(cmd)commands[#commands+1]=cmd end)
local d=c.supplies_data
for _,v in pairs(d.sources)do v.pending=false;v.frame=nil;v.complete=true;v.stale=false;v.status='complete';v.last_complete=t end
local fluids={'infusion','prudence','purgative','soothing','health','mana','speed','vigor','levitation','harmony','arcane','immunity','mass','caloric','epidermal','mending','restoration'}
local herbs={'acuity','amaurosis','anabiotic','antipsychotic','coagulation','decongestant','depressant','eucrasia','euphoriant','kawhepill','opiate','ototoxin','panacea','paste','pluck','somnium','steroid','stimulant','thanatonin','waterbreathing','reishi','willow','yarrow'}
for _,k in ipairs(fluids)do S.stock(c,k,500,'native test baseline')end
for _,k in ipairs(herbs)do S.stock(c,'ic:'..k,500,'native test baseline')end
S.stock(c,'health',1050,'native test baseline')
local lists={vial={'health','mana','speed','vigor','levitation','harmony','arcane','immunity','infusion','prudence','purgative'},pipe={'reishi','willow','yarrow'},bandage={'caloric','epidermal','mass','mending','restoration','soothing'}}
local headers={vial='Vial Elixir Sips Decay',pipe='Pipe Herb Puffs Decay Lit',bandage='Bandage Poultice Presses Decay'}
local function frame(kind)
 S.text(c,headers[kind]);S.text(c,'--------------------------')
 for i,name in ipairs(lists[kind])do
  local label=kind=='vial'and('an elixir of '..name)or kind=='bandage'and('a '..name..' poultice')or({reishi='a reishi mushroom',willow='some willow bark',yarrow='a yarrow root'})[name]
  if name=='arcane'then label='an elixir of the arcane'elseif name=='purgative'then label='a purgative concoction'end
  S.text(c,kind..i..'  '..label..'  '..(kind=='pipe'and 10 or name=='health'and 17 or 50)..'  A'..(kind=='pipe'and'  Yes'or''))
 end
 if kind=='vial'then S.text(c,'vial99  an elixir of health  50  A')end
 S.text(c,'--------------------------');S.prompt(c)
end
for _,kind in ipairs({'vial','pipe','bandage'})do frame(kind)end
local function health()return S.state(c).ledger.carried.vial.health.count end
check(L.state(c).complete and health()==67,'complete aggregate baseline missing')
S.text(c,'You take a drink of an elixir of health from a plain wooden vial.')
check(health()==66,'plain wooden vial receipt not counted with helper quarantined')
check(S.state(c).stocks.health.count==1050,'sip wrongly charged FC')
S.text(c,'You infuse a plain wooden vial with 50 doses of an elixir of health from your fluidcache.')
S.text(c,'You have 1000 sips remaining in your fluidcache.');S.prompt(c)
check(health()==116,'refill transfer not added exactly once')
check(S.state(c).stocks.health.count==1000,'refill absolute total ignored/double-debited')
check(S.rift(c,{name='anabiotic',amount='199'}),'absolute IC update rejected')
S.text(c,'You remove 1 anabiotic, bringing the total in the cache to 199.')
S.text(c,'You swallow an anabiotic pill.');S.prompt(c)
check(S.state(c).stocks['ic:anabiotic'].count==199,'carried pill use double-charged cache')
check(S.state(c).ledger.carried.pill.anabiotic.used==1,'pill consumption not recorded')
local display=S.render(c)
check(display.containers.tracked and not display.containers.stale,'query quarantine froze passive display')
check(not display.title:find('UNKNOWN',1,true),'passive known quantities still called unknown')
check(display.refill_blocked=='retained test quarantine','safety latch disappeared')
-- Exercise every report row, including all four independent carried-use kinds.
local report=S.report(c);local rows={};local row_count=0
check(report[1]=='CACHE RESERVES / CARRIED USES / CONFIRMED CONSUMPTION (since tracker start)','usage report header missing')
for i=2,#report do
 local key=report[i]:match('^([FI]C [^:]+):')
 if key then check(not rows[key],'duplicate usage row: '..key);rows[key]=report[i];row_count=row_count+1 end
end
check(row_count==#fluids+#herbs,'usage report omitted a supported resource')
check(rows['FC health']=='FC health: reserve 1000 | carried ~116 sips | used 1','vial reserve/carry/usage report incorrect')
for _,key in ipairs(lists.bandage)do
 check(rows['FC '..key]=='FC '..key..': reserve 500 | carried 50 presses | used 0','bandage report misclassified: '..key)
end
for _,key in ipairs(lists.vial)do check(rows['FC '..key]:find(' sips | used ',1,true),'vial report misclassified: '..key)end
for _,key in ipairs(lists.pipe)do
 check(rows['IC '..key]=='IC '..key..': reserve 500 | carried 10 puffs | used 0','pipe report misclassified: '..key)
end
for _,key in ipairs(herbs)do
 if key~='reishi'and key~='willow'and key~='yarrow'then
  local reserve=key=='anabiotic'and 199 or 500;local used=key=='anabiotic'and 1 or 0
  check(rows['IC '..key]=='IC '..key..': reserve '..reserve..' | carried unknown pills | used '..used,'pill report invented carried stock or lost use: '..key)
 end
end
check(report[#report]=='Automatic container refill paused: retained test quarantine. Passive tracking remains active.','usage report lost quarantine warning')
-- Load only the real public command function, never bootstrap's live setup.
local bootstrap_file=assert(io.open(root..'bootstrap.lua','r'));local bootstrap=bootstrap_file:read('*a');bootstrap_file:close()
local snippet=assert(bootstrap:match('(function combat_v2_supplies%(action%).-)\nfunction combat_v2_globe%('),'public supplies command source not found')
local printed={}
local env={tostring=tostring,assert=assert,ipairs=ipairs,print=function(line)printed[#printed+1]=line end,send=function(cmd)commands[#commands+1]=cmd;error('usage command attempted game send')end}
local source='return function(c)\n'..snippet..'\nreturn combat_v2_supplies\nend'
local command_chunk
if setfenv then command_chunk=assert(loadstring(source,'offline supplies command'));setfenv(command_chunk,env)
else command_chunk=assert(load(source,'offline supplies command','t',env))end
local usage=command_chunk()(c)
check(usage('usage')==true,'public usage command did not return true')
check(#printed==#report and #printed==#fluids+#herbs+2,'public usage command did not print header, all resource rows and warning')
for i,line in ipairs(report)do check(printed[i]==line,'public usage output diverged at line '..i)end
check(#commands==0,'report/public usage sent game commands')
check(c.containers_data.quarantine=='retained test quarantine'and c.containers_data.barrier.fault=='unknown action','passive ledger cleared action safeguard')
check(c.runner==R and R.waiting and R.recovery_snapshot.identity==1 and c.elemental_recovery==E and E.committed and c.mode=='BASH','ledger changed combat/recovery')
check(#commands==0,'passive baseline/usage sent commands')
-- One explicit passive check may read containers despite the separate action latch.
check(S.audit_containers(c),'passive explicit baseline blocked by action latch')
check(#commands==3,'explicit baseline was not one three-list batch')
d.requested=true;c.supplies_sender=function(cmd)commands[#commands+1]=cmd end
for i=1,720 do t=t+5;local id=c.supplies_owner.timer;local fn=assert(timers[id]);timers[id]=nil;fn()end
check(#commands==3,'one hour tracking polled inventory/cache')
check(L.state(c).carried.vial.health.count==116,'time fabricated usage')
print('PASS ledger integration '..n..' assertions: independent cache/carry/use, exact FC transfer, all 40 usage rows/four kinds, public usage command, quarantine-independent passive tracking, no polling/actions/combat mutations')
