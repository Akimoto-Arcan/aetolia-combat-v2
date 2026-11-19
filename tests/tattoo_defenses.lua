-- Offline only. Real captured grammar/own lines; all counts are synthetic.
-- No claim that a fresh inactive autoactivated tattoo has been observed: the
-- conditional Uses left projection below is explicitly a hypothetical format
-- compatibility test, NOT a new native Inactive/Unactivated row or fake charge.
local root=assert(arg[1]);local B=dofile(root..'buffs.lua');local S=dofile(root..'state.lua')
local clock=100;function getEpoch()return clock end
function getConnectionInfo()return 'offline',0,true end
local n=0;local function check(v,why)n=n+1;assert(v,why or ('assertion '..n))end
local autos={'boar','moon','moss','owl','mountain'}
local function row(s,k)for _,r in ipairs(B.rows(s))do if r.key==k then return r end end end
local function fresh(class)
 clock=100;local s=S.new();s.connected=true;B.set_class(s,class or 'Monk')
 local p=s.player;p.hp=100;p.maxhp=100;p.mana=100;p.maxmana=100
 p.balance=true;p.equilibrium=true;p.left_arm_balance=true;p.right_arm_balance=true
 B.sync(s,'List',{});for k in pairs(s.buffs.wanted)do s.buffs.wanted[k]=false end
 local sent={};local r={waiting=false,recovery={}};local identity=r.recovery
 local function sender(c)sent[#sent+1]=c end
 local function tick(hold)local out=B.service(s,r,sender,hold);check(r.recovery==identity and not r.waiting,'runner changed');return out end
 return s,sent,tick,r,sender
end
local function report(s,k,count,active)
 B.text(s,'You have the following tattoos:')
 B.text(s,'Head: '..k..(active and ' Active' or ' Uses left: '..count))
 B.on_prompt(s)
end
local function activate(s,k)
 if k=='starburst' then clock=clock+121 end
 check(B.toggle(s,k,true),'explicit toggle '..k)
end
local up={firefly='You touch the firefly tattoo and suddenly your surroundings are alight.',flame='You use Tattoos Flame.',starburst='You walk with the grace of the stars.'}
for _,class in ipairs({'Monk','Archivist'})do
 for k,line in pairs(up)do
  local s,sent,tick=fresh(class);check(not row(s,k).wanted and not s.buffs.master)
  report(s,k,2);tick();check(#sent==0,'fresh ink armed '..k)
  activate(s,k);tick();check(sent[1]=='touch '..k and #sent==1)
  check(s.buffs.tattoos[k].charges==1,'no pre-dispatch debit '..k)
  local p=s.buffs.pending;B.text(s,'Reporter says, "'..line..'"');check(not p.confirmed)
  B.text(s,line);B.text(s,line);check(p.confirmed and s.buffs.tattoos[k].charges==1,'paired ACK double debit')
  tick();check(s.buffs.pending==p,'ACK invented prompt')
  s.player.equilibrium=false;B.on_prompt(s);tick();check(s.buffs.pending==p)
  s.player.equilibrium=true;tick();check(s.buffs.pending==p,'cached readiness released')
  B.on_prompt(s);tick();check(not s.buffs.pending and row(s,k).active)
  for i=1,4 do clock=clock+500;tick()end;check(#sent==1,'periodic ACTIVE retouch')
  check(B.toggle(s,k,false));B.sync(s,'Remove',k);tick();check(#sent==1,'OFF invented cancellation')
 end
 for _,k in ipairs(autos)do
  local s,sent,tick=fresh(class);report(s,k,nil,true)
  check(row(s,k).active and row(s,k).passive and row(s,k).owner=='TATTOO')
  check(s.buffs.tattoos[k].charges==0 and not s.buffs.tattoos[k].touchable)
  check(not B.toggle(s,k,true),'ACTIVE granted TOUCH')
  s.buffs.wanted[k]=true;B.master(s,true)
  for i=1,4 do clock=clock+500;B.sync(s,'List',{});tick()end
  check(row(s,k).active and #sent==0,'List/age erased login-auto status')
  B.text(s,'You have the following tattoos:');B.text(s,'Head: '..k..' Active')
  B.sync(s,'Remove',k);B.on_prompt(s);tick()
  check(row(s,k).active==false and #sent==0,'old ACTIVE report defeated Remove')
  check(not B.availability(s,k) and not s.buffs.tattoos[k].charges,'Remove became fresh ownership')
  report(s,k,nil,true);check(row(s,k).active,'new authoritative ACTIVE failed')
  -- The actual fresh-inactive native format is unknown. Never accept a made-up
  -- Inactive field, assume one use from ownership, or replay a login TOUCH.
  B.text(s,'You have the following tattoos:');B.text(s,'Head: '..k..' Inactive');B.on_prompt(s)
  tick();check(not B.availability(s,k) and #sent==0,'invented inactive format granted capacity')
 end
end
-- Existing captured Uses left grammar, projected for the five conditional
-- producers. These inputs are hypothetical for those tattoo names; observed
-- ACTIVE-only reports above are the real current autoactivated-tattoo fixture.
for _,k in ipairs(autos)do
 local s,sent,tick=fresh();report(s,k,1);check(B.availability(s,k))
 activate(s,k);tick();check(sent[1]=='touch '..k and s.buffs.tattoos[k].charges==0)
 if k=='mountain' then B.sync(s,'Add',k) -- no exact legacy own mountain line supplied
 else B.text(s,'Your '..k..' tattoo has been activated.')end
 B.on_prompt(s);tick();B.sync(s,'Remove',k);clock=clock+3;tick()
 check(#sent==1 and not B.availability(s,k),'conditional fresh-ink action became periodic')
end
-- All three new charged producers inherit every root readiness/interlock gate.
for _,k in ipairs({'firefly','flame','starburst'})do
 for _,barrier in ipairs({'hold','walker','physical','mental','balance','health','mana'})do
  local s,sent,tick,r=fresh();report(s,k,1);activate(s,k)
  if barrier=='walker' then s.walker={pending={}}
  elseif barrier=='physical' then r.fault='unresolved'
  elseif barrier=='mental' then s.mental={eq_pending={}}
  elseif barrier=='balance' then s.player.balance=false
  elseif barrier=='health' then s.player.hp=10
  elseif barrier=='mana' then s.player.mana=10 end
  tick(barrier=='hold');check(#sent==0 and not s.buffs.pending,'root bypass '..k..' '..barrier)
 end
 for _,kind in ipairs({'false','throw','reject','reload','stale','external'})do
  local s,sent,tick,r,sender=fresh();report(s,k,1);activate(s,k)
  if kind=='stale' then B.text(s,'You have the following tattoos:');B.text(s,'Head: '..k..' Uses left: 1')end
  if kind=='external' then
   B.text(s,up[k]);B.sync(s,'Remove',k);clock=clock+121;tick()
   check(#sent==0 and not B.availability(s,k),'external activation retained budget')
  else
   if kind=='false' or kind=='throw' then
    B.service(s,r,function(c)sent[#sent+1]=c;if kind=='throw' then error('offline transport')end;return false end)
   else tick()end
   local p=s.buffs.pending;check(p and p.tattoo_debited and s.buffs.tattoos[k].charges==0)
   if kind=='reject' then B.text(s,k=='firefly' and 'You cannot activate your firefly tattoo again just yet.' or k=='flame' and 'You have no flame.' or 'You must regain equilibrium first.')
   else B.text(s,up[k])end
   B.on_prompt(s)
   if kind=='reload' then
    B.stop(s);B=dofile(root..'buffs.lua');check(s.buffs.pending==p);B.set_class(s,'Archivist');check(s.buffs.pending==p and not p.confirmed)
   end
   tick()
   if kind=='stale' then
    B.sync(s,'Remove',k);clock=clock+121;tick();check(#sent==1 and not B.availability(s,k),'old report replenished debit')
   elseif kind=='false' or kind=='throw' or kind=='reject' or kind=='reload' then
    B.stop(s);clock=clock+20;tick();check(s.buffs.pending==p and #sent<=2,'commit lost '..kind)
   end
  end
 end
end
-- Starburst is consumed, has a two-minute trigger cooldown, and cannot replace
-- another death protection. Saved wanted alone never grants current opt-in.
for _,k in ipairs({'soulcage','rebirth','substitute','soul_store','starburst','resurrection'})do
 local s,sent,tick=fresh();report(s,'Starburst',1);clock=clock+121
 B.sync(s,'Add',k);check(not B.toggle(s,'starburst',true),'death protection conflict '..k)
 s.buffs.wanted.starburst=true;s.buffs.starburst_optin=true;B.master(s,true);tick();check(#sent==0)
end
do
 local s,sent,tick=fresh();report(s,'Starburst',1);clock=clock+121
 s.buffs.wanted.starburst=true;B.master(s,true);tick();check(#sent==0,'saved wanted granted consumed action')
 activate(s,'starburst');B.sync(s,'Add','rebirth');tick();check(#sent==0,'late death-protection conflict bypassed')
 B.sync(s,'Remove','rebirth');tick();check(sent[1]=='touch starburst')
 B.text(s,up.starburst);B.on_prompt(s);tick();B.sync(s,'Remove','starburst');report(s,'Starburst',1)
 clock=clock+119;tick();check(#sent==1,'trigger cooldown bypassed')
 clock=clock+2;tick();check(#sent==2,'conservative cooldown did not expire')
end
-- Synchronous own ACK + prompt still cannot escape the dispatch barrier.
do
 local s,sent,_,r=fresh();report(s,'Firefly',1);activate(s,'firefly');local sender
 sender=function(c)sent[#sent+1]=c;B.text(s,up.firefly);B.on_prompt(s);check(B.service(s,r,sender).busy)end
 B.service(s,r,sender);check(#sent==1 and s.buffs.pending);B.service(s,r,sender);check(#sent==1 and not s.buffs.pending)
end
print('PASS tattoo defenses '..n..' assertions: class-shared opt-in TOUCH, actual ACTIVE rows, conditional capacity, no invented inactive format, own ACK/recovery, conservative death protection/cooldown, stale budget/reload/rejection/root barriers')
