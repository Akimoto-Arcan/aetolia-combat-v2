local root=assert(arg[1], 'installed module path required')
local sent={};local clock=100
function getEpoch()return clock end
function send(cmd)sent[#sent+1]=cmd end
local S=dofile(root..'state.lua');local R=dofile(root..'runner.lua');local K=dofile(root..'monk.lua')
local s=S.new();local r=R.new(s,K)
local function vit(b) S.sync_gmcp(s,{Char={Vitals={hp='100',maxhp='100',balance=b,equilibrium=b,left_arm=b,right_arm=b}}}) end
local count=0
local function check(ok,msg)assert(ok,msg);count=count+1 end
vit('1');s.target.name='dummy'
check(not R.tick(r) and #sent==0,'OFF sent')
r.mode='SHADOW';check(not R.tick(r) and #sent==0,'SHADOW sent')
r.mode='BASH';check(R.tick(r) and #sent==1,'BASH failed')
check(not R.tick(r) and #sent==1,'duplicate send')
clock=101;vit('0');check(not R.tick(r),'unbalanced sent');vit('1');check(R.tick(r) and #sent==2,'regain stalled')
R.stop(r);clock=102;r.mode='ASSIST';check(not R.tick(r) and r.pending,'assist not pending')
check(R.approve(r) and r.waiting and #sent==3,'approval did not use real runner')
check(not R.approve(r) and #sent==3,'double approval')
R.stop(r);r.mode='BASH';clock=103;s.connected=false;check(not R.tick(r),'disconnected sent');s.connected=true
s.player.hp=0;check(not R.tick(r),'dead sent');s.player.hp=100
s.target.name=nil;check(not R.tick(r),'no target sent');s.target.name='bad;quit';check(not R.tick(r),'invalid target sent')
s.target.name='dummy';s.player.balance='0';check(not R.tick(r),'string zero ready')
local E=dofile(root..'events.lua');E.event(s,'You are prone.');check(s.player.prone and not s.target.prone,'player prone polluted enemy')
-- Bootstrap integration with fake Mudlet API/GUI.
local realdofile=dofile;local gui={create=function()end,refresh=function()end}
dofile=function(p) if p:match('/gui.lua$') then return gui end;return realdofile(p) end
function getMudletHomeDir()return root:sub(1,-12) end
local handlers={};local trigger,alias
function registerAnonymousEventHandler(e,f)handlers[#handlers+1]={e,f};return #handlers end
function killAnonymousEventHandler()end
function tempRegexTrigger(p,f)trigger=f;return 1 end
function killTrigger()end
function tempAlias(p,f)alias=f;return 2 end
function killAlias()end
function tempTimer()return 3 end
function killTimer()end
gmcp={};getMudletHomeDir=function()return root:gsub('/combat_v2/$','') end
local before=#sent;realdofile(root..'bootstrap.lua');check(#sent==before,'bootstrap sends')
check(not combat_v2_set_target('foo\nquit'),'target newline accepted')
combat_v2_set_target('dummy');combat_v2.current.target.limbs.left_arm=55;combat_v2_set_target('other');check(combat_v2.current.target.limbs.left_arm==0,'target retains limbs')
realdofile(root..'bootstrap.lua');check(#sent==before and combat_v2.mode=='OFF','reload sends')
combat_v2.current.connected=true;combat_v2.current.player.hp=100
combat_v2_set_curing(true);check(sent[#sent-1]=='firstaid on' and sent[#sent]=='firstaid curing on','native curing commands')
combat_v2_set_curing(false);check(sent[#sent]=='firstaid off','native curing off')
print('PASS '..count..' assertions: execution gates, duplicate guard, regain, assist, disconnect/death, validation, target reset, bootstrap/reload, FIRSTAID')
