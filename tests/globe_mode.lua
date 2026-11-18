-- Actual bootstrap globe-mode wiring, all transports fake.
local root=assert(arg[1]);local realdofile=dofile;local ids=0;local hs,as={},{},{};local sends={}
function getEpoch()return 100 end
function getMudletHomeDir()return root:gsub('/combat_v2/$','')end
function getConnectionInfo()return 'fixture',0,true end
function registerAnonymousEventHandler(event,fn)ids=ids+1;hs[ids]={event,fn};return ids end
function killAnonymousEventHandler(id)hs[id]=nil end
function tempAlias(_,fn)ids=ids+1;as[ids]=fn;return ids end
function killAlias(id)as[id]=nil end
function tempRegexTrigger()ids=ids+1;return ids end
function tempPromptTrigger()ids=ids+1;return ids end
function killTrigger()end
function tempTimer()ids=ids+1;return ids end
function killTimer()end
function send(cmd)sends[#sends+1]=cmd end
function sendGMCP()end
function dofile(p)if p:match('/gui.lua$')then return{create=function()end,refresh=function()end}end;return realdofile(p)end
gmcp={Char={Vitals={hp=100,maxhp=100,mp=100,maxmp=100,balance=1,equilibrium=1,left_arm=1,right_arm=1},Status={class='Monk'}},Room={Info={num=1,area='Fixture'},Players={}}}
realdofile(root..'bootstrap.lua');local c=combat_v2;local n=0
local function check(ok,why)assert(ok,why);n=n+1 end
check(c.elementals and not c.elemental_recovery.armed and not c.elemental_recovery.attached and #sends==0,'startup autoarmed/attached/sent')
check(not combat_v2_globe('on') and #sends==0,'globe enabled outside BASH')
c.mode='BASH';c.current.mode='BASH';c.runner.mode='BASH';c.current.connected=true
check(combat_v2_globe('on') and c.elemental_recovery.armed and #sends==0,'globe activation must authorize without sending')
local addons=0;for _,h in pairs(hs)do if h[1]=='gmcp.Char.Defences.Add'then addons=addons+1 end end
check(addons==2,'globe attachment lost core GMCP handler')
check(combat_v2_globe('off') and not c.elemental_recovery.armed,'explicit globe OFF failed')
check(combat_v2_globe('on'),'globe reenable failed')
combat_v2_set_mode('SHADOW');check(not c.elemental_recovery.armed,'leaving BASH kept globe active')
check(not combat_v2_globe('on'),'SHADOW allowed globe')
c.mode='BASH';c.current.mode='BASH';c.runner.mode='BASH';c.current.connected=true;combat_v2_globe('on')
combat_v2_stop();check(not c.elemental_recovery.armed and c.mode=='OFF','OFF did not disable globe')
check(not combat_v2_globe('on;quit') and #sends==0,'invalid globe control sent commands')
print('PASS globe mode '..n..' assertions: bootstrap default OFF, BASH-only, independent disable, lifecycle and multicast hooks; zero sends')
