-- Disconnected smoke. Model inputs are test fixtures, never native authority.
-- Activation/heal/recovery strings come from the preserved genuine receipt.
local source=arg[1]or'combat_v2/'
local candidate=source
local time=1000
getEpoch=function()return time end
getConnectionInfo=function()return 'offline-fixture',0,true end
local checks=0
local function check(x,why)assert(x,why);checks=checks+1 end
local function fixture()
 local State=dofile(source..'state.lua');local D=dofile(candidate..'defense.lua')
 local E=dofile(source..'earthcaller.lua');local O=dofile(source..'class_observers.lua')
 local Router=dofile(candidate..'class_router.lua').new({Earthcaller=E})
 local S=dofile(candidate..'survival.lua');local s=State.new();s.mode='BASH';s.connected=true
 s.player.hp=1800;s.player.maxhp=4042;s.player.class='Earthcaller';s.player.dead=false
 local sent={};local raw=function(command)sent[#sent+1]=command;return true end
 local c={current=s,mode='BASH',runner={state=s,mode='BASH'},defense=D,walker={},walker_boot={},class_router=Router,earthcaller=E,defense_sender=raw}
 c.walker.emergency_candidate=function()return c.escape==true,{kind='escape',cause=c.escape_cause,session='escape-session'}end
 check(D.numb_bind(c),'bind defense');local n=c.emergency_numb
 n.observers_ready=true;n.observer_check=function()return true end
 O.attach(s,{Earthcaller=E})
 local function ingress(kind,raw)
  if kind=='Char.Vitals'then State.sync_gmcp(s,{Char={Vitals=raw}});D.numb_observe(c,'vitals',raw)end
  if kind=='Char.Status'then D.numb_observe(c,'status',raw)end
  O.ingress(s,kind,raw);Router.observe_defense(s,kind)
 end
 local function vitals(eq,fervour,wp,hp,left,right)
  ingress('Char.Vitals',{hp=tostring(hp or s.player.hp),maxhp='4042',mp='3196',maxmp='3196',wp=tostring(wp or 16851),balance='1',equilibrium=tostring(eq or 1),left_arm=tostring(left or 1),right_arm=tostring(right or 1),charstats={'Class: Earthcaller','Fervour: '..tostring(fervour or 65000),'Impurity: 0'}})
 end
 ingress('Char.Status',{name='OfflineFixture',class='Earthcaller'})
 D.numb_observe(c,'afflictions',{})
 ingress('Char.Skills.List',{group='apocalyptia',list={'Reinforce'}})
 ingress('native.text','Reinforce (Apocalyptia) Known: Yes')
 -- Known header is sufficient with the qualified static schema; no fresh
 -- Fervour-maximum or cost prose is required to make ordinary hunting usable.
 ingress('native.prompt','')
 vitals()
 local role_nodes={}
 -- Model only the already-owned defense transport. Other required entry roles
 -- are absent in this small fixture; no global send or native registry exists.
 role_nodes[1]={edge='field',parent=c,key='defense_sender',original=raw,mode='raw',roles={'defense','runner','walker'},direct_firstaid=true}
 local api,why=S.bind(c,{nodes=role_nodes,classifiers={passive_restock=function()return false end,terminal_globe=function()return false end}})
 check(api~=nil,why)
 return c,ingress,vitals,sent,Router,D
end
local c,ingress,vitals,sent,R,D=fixture();local s=c.current;local a=c.survival_arbiter
check(R.reinforce_known(s),'native list/header proof')
check(R.reinforce_ready(s),'baseline ready')
check(not c.earthcaller.known(s,'reinforce'),'router proof works without offense ability map')
s.class_observations.issued={class='Earthcaller'}
check(not D.numb_service(s,c.defense_sender)and #sent==0,'no concurrent issued action')
s.class_observations.issued=nil
s.config.earthcaller_reinforce_enabled=false
check(not D.numb_service(s,c.defense_sender)and #sent==0,'disabled intent')
s.config.earthcaller_reinforce_enabled=nil
c.mode='OFF';check(not D.numb_service(s,c.defense_sender)and #sent==0,'OFF revoked intent');c.mode='BASH'
s.earthcaller.native.documentation=true
check(not D.numb_service(s,c.defense_sender)and #sent==0,'documentation blocks')
s.earthcaller.native.documentation=nil
s.config.earthcaller_reinforce_health=40
check(not D.numb_service(s,c.defense_sender)and #sent==0,'configurable threshold')
s.config.earthcaller_reinforce_health=nil
vitals(1,65000,16851,2021)
check(not D.numb_service(s,c.defense_sender)and #sent==0,'exact 50 percent excluded')
vitals(1,65000,16851,700);c.escape=true
check(a.choose(c,'reinforce',s.player.hp/s.player.maxhp)=='escape','below20 escape priority')
check(not D.numb_service(s,c.defense_sender)and #sent==0,'below20 no heal')
vitals(1,65000,16851,1800);c.escape_cause='incoming-stall'
check(a.choose(c,'reinforce',s.player.hp/s.player.maxhp)=='escape','incoming-stall escape priority')
check(not D.numb_service(s,c.defense_sender)and #sent==0,'incoming-stall no heal')
c.escape=false;c.escape_cause=nil
vitals(1,65000,16851,1800,0,1);s.player.afflictions.left_arm_broken=true
check(R.reinforce_ready(s),'one functional arm sufficient')
check(D.numb_service(s,c.defense_sender),'service owns heal')
check(#sent==1 and sent[1]=='DIRGE REINFORCE','one self-only send')
local p=s.earth_defense_pending;check(p and p.earth_reservation.token.state=='issued/unknown','resource committed before transport')
check(a.status(c).kind=='reinforce','survival lease retained')
check(c.defense_sender('QUASH 123')==false and #sent==1,'exclusive physical IO')
check(c.defense_sender('firstaid elevate paralysis')==true and #sent==2,'FIRSTAID passthrough')
check(D.numb_service(s,c.defense_sender)and #sent==2,'no repeat while issued')
ingress('native.text','You use Apocalyptia Reinforce.')
ingress('native.text','The strength of stone and sand envelops you as the earth mends your wounds.')
ingress('native.text','Health Gain: 16')
ingress('native.text','Equilibrium Used: 3.00 seconds')
vitals(0,64850,16827,1816,0,1)
ingress('native.prompt','')
check(not a.settle(c),'no prompt-only settlement')
vitals(0,64850,16804,1816,0,1)
check(p.earth_reservation.wp_after~=nil,'regen and clot do not manufacture an exact net-WP debit')
ingress('native.text','You have recovered equilibrium.')
vitals(1,64850,16804,1816,0,1)
check(not a.settle(c),'recovery requires later prompt')
s.config.earthcaller_reinforce_enabled=false;c.mode='OFF';s.mode='OFF';c.runner.mode='OFF'
ingress('native.prompt','')
check(a.settle(c),'issued action settles after OFF without rearming')
check(s.earth_defense_pending==nil and not a.busy(c),'lease/pending released')
check(p.earth_reservation.token.state=='debit-observed','exact fervour ledger settled')
check(not D.numb_service(s,c.defense_sender)and #sent==2,'revoked intent does not recast')
-- Missing/negative ownership never gets inferred from cached AB help alone.
local c2,i2,v2,out2,r2,d2=fixture()
i2('native.text','Reinforce (Apocalyptia) Known: No');i2('native.prompt','');v2()
check(not r2.reinforce_known(c2.current),'negative ownership revokes')
check(not d2.numb_service(c2.current,c2.defense_sender)and #out2==0,'unlearned no send')
-- Bootstrap: exercise the exact inserted acquisition block with a fake sender.
local f=assert(io.open(candidate..'bootstrap.lua'));local boot=f:read('*a');f:close()
local block=assert(boot:match('(   %-%- Native list %+ explicit Known header.-)  if c.supplies'))
local queries={};c2.state={record=function()end};c2.current.player.dead=false
local execute=assert((loadstring or load)('return function(c,new_bash_intent,send) local s=c.current\n'..block..' end'))()
execute(c2,true,function(cmd)queries[#queries+1]=cmd end)
check(#queries==2 and queries[1]=='ab apocalyptia'and queries[2]=='ab apocalyptia reinforce details','new BASH automatic list and header acquisition')
execute(c2,false,function(cmd)queries[#queries+1]=cmd end)
check(#queries==2,'no polling acquisition')
print('PASS Reinforce focused smoke: '..checks..' assertions; disconnected fake transport only')
