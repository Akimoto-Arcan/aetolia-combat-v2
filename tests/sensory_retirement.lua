-- Unmodified production module: sensory retirement cannot be bypassed by saved
-- intent, direct APIs, public catalog mutation, fresh proof or pending reloads.
local root=assert(arg[1]);local B=dofile(root..'buffs.lua');local S=dofile(root..'state.lua')
local clock=100;function getEpoch()return clock end
function getConnectionInfo()return 'fixture',0,true end
local n=0;local function check(v,why)n=n+1;assert(v,why or ('assertion '..n))end
local function row(s,k)for _,r in ipairs(B.rows(s))do if r.key==k then return r end end end
local function fresh(class)
 local s=S.new();s.connected=true;B.set_class(s,class)
 local p=s.player;p.hp=100;p.maxhp=100;p.mana=100;p.maxmana=100
 p.balance=true;p.equilibrium=true;p.left_arm_balance=true;p.right_arm_balance=true
 B.sync(s,'List',{});B.vitals(s,{herb=1,blind=0,deaf=0})
 for k in pairs(s.buffs.wanted)do s.buffs.wanted[k]=false end
 return s
end
local function proof(s)
 return {class=s.buffs.class,epoch=s.buffs.sensory_epoch or 0,observed_at=clock,herb=1,priorities={blindness=26,deafness=26},stocks={amaurosis=99,ototoxin=99},eating_allowed=true,curing_clear=true,barriers_clear=true}
end
check(#B.curative_catalog==15,'official curative count')
local native=0;for _ in pairs(B.native_catalog)do native=native+1 end;check(native==12,'native ownership changed')
for _,e in ipairs(B.curative_catalog)do check(e.kind=='official_defence' and e.key~='blindness' and e.key~='deafness','retired curative advertised')end
for _,e in ipairs(B.catalog)do check(not e.self_afflicted and e.key~='blindness' and e.key~='deafness','retired producer advertised')end
for _,class in ipairs({'Monk','Archivist'})do
 for _,k in ipairs({'blindness','deafness'})do
  local s=fresh(class);local b=s.buffs;local sent={};local function tick()return B.service(s,{},function(cmd)sent[#sent+1]=cmd end)end
  check(B.set_sensory_context(s,proof(s)),'receipt/context compatibility broken')
  b.wanted[k]=true;b.sensory_optin={[k]=true};b.todo={[k]=true};b.cancel[k]=true
  check(not B.select_sensory(s,k,true),'direct select enabled retired goal')
  check(not B.toggle(s,k,true),'toggle enabled retired goal')
  check(not B.toggle(s,k=='blindness' and 'blind' or 'deaf',true),'alias enabled retired goal')
  check(not B.sensory_ready(s,k) and not B.availability(s,k),'readiness advertised retired goal')
  check(not row(s,k),'retired row present')
  check(b.wanted[k]==false and not b.sensory_optin[k] and not b.todo[k] and not b.cancel[k],'stale saved intent survived')
  check(B.master(s,true) and B.start(s),'unrelated defense intent blocked')
  for i=1,3 do clock=clock+1;B.on_prompt(s);tick()end
  check(#sent==0 and not b.pending,'saved goal sent command')
  -- A caller can mutate exported metadata but cannot add private authority.
  local e={key=k,class='shared',group='curatives',curative=true,command='eat '..(k=='blindness' and 'amaurosis' or 'ototoxin'),prepare='outc '..(k=='blindness' and 'amaurosis' or 'ototoxin')}
  B.catalog[#B.catalog+1]=e;b.wanted[k]=true;b.sensory_optin[k]=true
  B.set_sensory_context(s,proof(s));tick()
  check(#sent==0 and not b.pending and not row(s,k),'public catalog injection restored producer')
  B.catalog[#B.catalog]=nil
  -- Raw sensory ingestion is retained, but never becomes a defense row.
  B.vitals(s,{blind=1,deaf=1});check(b.vitals_flags.blindness and b.vitals_flags.deafness,'raw Vitals lost')
  B.sync(s,'List',{'blind','deaf'});check(not row(s,'blindness') and not row(s,'deafness'),'DEF data reintroduced sensory rows')
  B.affliction_flags(s,'Add',{name=k});check(b.flag_sources[k]=='afflictions' and b.vitals_flags[k],'Add lost')
  B.affliction_flags(s,'Remove',{name=k});check(b.vitals_flags[k]==false,'native cure lost')
  B.vitals(s,{blind=0,deaf=0});check(b.vitals_flags.blindness==false and b.vitals_flags.deafness==false,'zero flags lost')
  check(B.select_sensory(s,k,false),'local revocation blocked')
  check(#sent==0,'cure caused consumption')
  -- Replacing the module preserves committed uncertainty; it may settle only
  -- after its exact own receipt, actual herb loss/recovery and a later prompt.
  local p={key=k,off=false,curative=true,eat_started=true,at=clock,dispatched_prompt=b.prompt,confirmed=false}
  b.pending=p;b.wanted[k]=true;b.sensory_optin[k]=true
  local reloaded=dofile(root..'buffs.lua');check(reloaded.state(s).pending==p,'reload cleared committed pending')
  reloaded.on_prompt(s);reloaded.service(s,{},function(cmd)sent[#sent+1]=cmd end)
  check(b.pending==p and #sent==0,'ready prompt alone released/replayed pending')
  reloaded.vitals(s,{herb=0});reloaded.affliction_flags(s,'Add',{name=k})
  reloaded.on_prompt(s);reloaded.service(s,{},function(cmd)sent[#sent+1]=cmd end)
  check(b.pending==p,'receipt without recovery released pending')
  reloaded.vitals(s,{herb=1});reloaded.on_prompt(s);reloaded.service(s,{},function(cmd)sent[#sent+1]=cmd end)
  check(not b.pending and #sent==0,'committed legacy settlement broken or replayed')
 end
end
print('PASS sensory retirement '..n..' assertions: production API rejection, stale intent, metadata injection, raw ingestion and committed reload settlement')
