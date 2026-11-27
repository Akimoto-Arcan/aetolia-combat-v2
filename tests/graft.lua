-- Disconnected synthetic packets with exact narrative from native Graft receipts.
local root=arg[1]or'combat_v2/'
getEpoch=function()return 100 end
local State=dofile(root..'state.lua');local E=dofile(root..'earthcaller.lua')
local O=dofile(root..'class_observers.lua');local R=dofile(root..'class_router.lua').new({Earthcaller=E})
local Runner=dofile(root..'runner.lua')
local function fixture()
 local s=State.new();s.mode='BASH';s.connected=true;s.player.class='Earthcaller';s.player.hp=4042;s.player.maxhp=4042
 s.target.name='456';s.target_generation=1;s.room.id=1;s.room.items={['456']={name='a test denizen'}}
 O.attach(s,{Earthcaller=E})
 local function ingest(source,raw)
  if source=='Char.Vitals'then State.sync_gmcp(s,{Char={Vitals=raw}})end
  O.ingress(s,source,raw)
 end
 ingest('Char.Status',{name='OfflineFixture',class='Earthcaller'})
 ingest('Char.Skills.List',{group='subjugation',list={{name='Quash',known=true},{name='Graft',known=true},{name='Splinter',known=true}}})
 local function vitals(eq)ingest('Char.Vitals',{hp='4042',maxhp='4042',balance='1',equilibrium=tostring(eq),left_arm='1',right_arm='1'})end
 local function count(n,active)
  ingest('native.text','You draw your gaze upon a swarm of bone fragments, noting its status.')
  if active then ingest('native.text','You currently call upon your swarm for:');ingest('native.text','grafting fragments')end
  ingest('native.text','Your swarm contains '..n..' fragments of a maximum 5000.')
 end
 s.target.earth_evidence={source='offline-fixture',generation=1,room=1,at=100,protected=false,loyal=false,eligible=true,kind='npc',player=false}
 s.earthcaller.equipment={epoch=s.earthcaller.epoch,at=100,wielded=true,calcified=true,bound_to_self=true,shield_wielded=true}
 vitals(1);count(920,false)
 s.earthcaller.equipment={epoch=s.earthcaller.epoch,at=100,wielded=true,calcified=true,bound_to_self=true,shield_wielded=true}
 return s,ingest,vitals,count
end
local s,i,v,count=fixture()
assert(E.choose(s).command=='OSSO GRAFT','full HP BASH upkeep')
s.config.earthcaller_graft_enabled=false;assert(E.choose(s).command=='QUASH 456');s.config.earthcaller_graft_enabled=nil
s.mode='OFF';assert(E.choose(s).command=='');s.mode='BASH'
s.player.afflictions.disfigured=true;assert(E.choose(s).command=='');s.player.afflictions.disfigured=nil
local a=E.choose(s);assert(R.commit(s,a));assert(E.transport_begin(s))
local issue=s.earthcaller.physical;assert(issue.graft and not E.pair_ready(s),'no additive Splinter during Graft reservation')
assert(E.transport_result(s,'graft',true,true));issue.graft.count_transport=true;issue.dispatching=false
i('native.text','Pieces from a swarm of bone fragments shift in wait to hover over your skin, ready to submerge ')
i('native.text','themselves as needed.')
i('native.text','Equilibrium Used: 4.50 seconds');v(0);count(770,true)
i('native.prompt','');assert(s.earthcaller.physical==issue,'prompt cannot replace recovery')
v(1);assert(s.earthcaller.physical==issue,'recovery needs newer prompt')
i('native.prompt','');assert(not s.earthcaller.physical and not s.class_observations.issued,'settled')
assert(issue.graft.state=='physical-settled');assert(issue.graft.token.state=='debit-observed')
assert(not next(s.earthcaller.reservations));s.earthcaller.equipment={epoch=s.earthcaller.epoch,at=100,wielded=true,calcified=true,bound_to_self=true,shield_wielded=true};assert(E.choose(s).command=='QUASH 456','ordinary offense resumes')
s.mode='OFF';assert(s.earthcaller.graft.status=='active','OFF does not stop native drain')
s.mode='BASH';s.config.earthcaller_optional_splinter=false;assert(not E.pair_ready(s),'optional intent preserved')
i('native.text','Your swarm ceases its attempt at graft.');count(760,false);assert(E.choose(s).command=='OSSO GRAFT')
local s2,i2,v2,c2=fixture();assert(R.commit(s2,E.choose(s2)));assert(E.transport_begin(s2));E.transport_result(s2,'graft',true,nil)
assert(s2.earthcaller.physical.unknown);E.physical_stop(s2);assert(s2.earthcaller.physical and next(s2.earthcaller.reservations),'unknown retained across STOP')
local s3,i3,v3,c3=fixture();i3('native.text','You draw your gaze upon a swarm of bone fragments, noting its status.');i3('native.text','unknown status row');assert(s3.earthcaller.graft.status=='unknown');assert(E.choose(s3).command=='QUASH 456','unknown status never causes duplicate Graft')
-- Runner integration: same sender, one Graft and one bounded COUNT, no Splinter.
local s4,i4,v4,c4=fixture();local sent={};local r=Runner.new(s4,{choose=function()return E.choose(s4)end});Runner.bind_classes(r,R)
r.mode='BASH';r.cooldown=0;r.last_send=-100
r.sender=function(command)sent[#sent+1]=command;return true end
Runner.policy=function()return true end;Runner.defense=nil
assert(Runner.execute(r,E.choose(s4)));assert(#sent==2 and sent[1]=='OSSO GRAFT'and sent[2]=='OSSO COUNT','Runner owns bounded activation readback')
print('PASS Graft: BASH/fullHP admission, OFF/disfigurement/opt-out, exact wrapped own ACK, COUNT status+150 debit, EQ loss/recovery/later prompt, unknown retention, no duplicate Graft, optional Splinter preserved, actual Runner Graft+COUNT')
-- One configured-separator transport; both legs exist before native send.
getCommandSeparator=function()return ';;'end
local s5,i5,v5,c5=fixture();s5.config.earthcaller_graft_enabled=false
i5('Char.Vitals',{hp='4042',maxhp='4042',mp='3196',maxmp='3196',balance='1',equilibrium='1',left_arm='1',right_arm='1'})
s5.earthcaller.equipment={epoch=s5.earthcaller.epoch,at=100,wielded=true,calcified=true,bound_to_self=true,shield_wielded=true}
local sends={};local r5=Runner.new(s5,{choose=function()return E.choose(s5)end});Runner.bind_classes(r5,R)
r5.mode='BASH';r5.cooldown=0;r5.last_send=-100;r5.sender=function(cmd)sends[#sends+1]=cmd;return true end
assert(Runner.execute(r5,E.choose(s5)))
assert(#sends==1 and sends[1]=='QUASH 456;;OSSO SPLINTER',table.concat(sends,' | '))
assert(s5.earthcaller.physical.quash.transport and s5.earthcaller.physical.splinter.transport)
print('PASS configured-separator pair: one sender call, both precommitted legs, two transport receipts')
