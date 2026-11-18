-- Pure offline tests: no Mudlet, network, filesystem writes or real commands.
local root=(arg and arg[1]) or 'combat_v2/'
local B=dofile(root..'buffs.lua')
local State=dofile(root..'state.lua')
local Runner=dofile(root..'runner.lua')
local Mental=dofile(root..'mental.lua')
local clock=1000
getEpoch=function() return clock end
getConnectionInfo=function() return 'offline-test',0,true end
local tests,assertions=0,0
local function eq(a,b,why)
 assertions=assertions+1
 assert(a==b,(why or 'mismatch')..': expected '..tostring(b)..', got '..tostring(a))
end
local function test(name,fn)
 local ok,err=pcall(fn)
 if not ok then error('FAIL '..name..': '..tostring(err),0) end
 tests=tests+1;print('PASS '..name)
end
local function fixture(opts)
 clock=1000
 local s=State.new();s.connected=true
 local p=s.player;p.hp=1000;p.maxhp=1000;p.mana=1000;p.maxmana=1000;p.willpower=1000;p.maxwillpower=1000
 p.balance=true;p.equilibrium=true;p.left_arm_balance=true;p.right_arm_balance=true
 B.set_class(s,'Monk')
 if not opts or not opts.unknown then
  local names={};for _,e in ipairs(B.catalog) do names[#names+1]=e.key end
  B.set_known(s,names);B.sync(s,'List',{})
 end
 local sent={};local sender=function(cmd) sent[#sent+1]=cmd end
 local r={waiting=false}
 local function tick(hold) return B.service(s,r,sender,hold) end
 return s,sent,tick,r,sender
end
local function only(s,k)
 local b=B.state(s);for name in pairs(b.wanted) do b.wanted[name]=name==k end
end
local function ack(s,k,off)
 B.sync(s,off and 'Remove' or 'Add',{name=k});B.on_prompt(s)
end

test('catalog safe defaults, no emergency or arbitrary commands',function()
 local s,sent,tick=fixture();local n=0
 for i,e in ipairs(B.catalog) do eq(e.default,i<=8,e.key);if e.default then n=n+1 end end
 eq(n,8);eq(#B.catalog,14);eq(B.state(s).master,false);eq(B.state(s).sequence,false)
 eq(tick().busy,false);eq(#sent,0)
 eq(B.toggle(s,'regeneration on;kill',true),false);eq(B.toggle(s,'numbness',true),false)
 eq(B.toggle(s,'vitality','on'),false);eq(#sent,0)
end)

test('one-shot deterministic sequencing and completion',function()
 local s,sent,tick=fixture();eq(B.start(s),true);eq(#sent,0)
 for i=1,8 do
  local e=B.catalog[i];eq(tick().busy,true);eq(sent[#sent],e.command)
  eq(B.state(s).master,false);ack(s,e.key);eq(tick().busy,false)
 end
 eq(tick().busy,false);eq(B.state(s).sequence,false);eq(#sent,8)
 B.sync(s,'Remove','weathering');tick();eq(#sent,8,'one shot never arms upkeep')
end)

test('maintenance loss reapplies once after backoff',function()
 local s,sent,tick=fixture();only(s,'toughness');eq(B.master(s,true),true);tick();ack(s,'toughness');tick()
 B.sync(s,'Remove','toughness');tick();eq(#sent,1)
 clock=clock+3;tick();eq(#sent,2);eq(sent[2],'toughness');tick();eq(#sent,2)
 ack(s,'toughness');tick();B.master(s,false);B.sync(s,'Remove','toughness');clock=clock+3;tick();eq(#sent,2)
end)

test('default drains excluded; explicit opt-in arms upkeep',function()
 local s,sent,tick=fixture();only(s,'regeneration');B.state(s).wanted.regeneration=false
 B.start(s);tick();eq(#sent,0)
 eq(B.toggle(s,'regeneration',true),true);eq(B.state(s).master,true);tick();eq(sent[1],'regeneration on')
 ack(s,'regeneration');tick();B.master(s,false);eq(B.state(s).have.regeneration,true);tick();eq(#sent,1)
 B.toggle(s,'regeneration',false);s.player.hp=1;s.player.mana=1;s.player.willpower=1
 tick();eq(sent[2],'regeneration off');ack(s,'regeneration',true);tick();eq(B.state(s).have.regeneration,nil)
 eq(B.state(s).master,false)
end)

test('all verified cancellation commands, no guessed cancel',function()
 for k,cmd in pairs({regeneration='regeneration off',projectiles='projectiles off',trance='break trance',splitting='join mind'}) do
  local s,sent,tick=fixture();eq(B.toggle(s,k,false),true);tick();eq(sent[1],cmd);ack(s,k,true);tick();eq(B.state(s).pending,nil)
 end
 local s,sent,tick=fixture();local ok,why=B.toggle(s,'boosting',false)
 eq(ok,true);assert(why:find('no verified cancellation',1,true));tick();eq(#sent,0)
end)

test('off requested during in-flight on survives until on settles',function()
 local s,sent,tick=fixture();only(s,'trance');B.toggle(s,'trance',true);tick();B.toggle(s,'trance',false)
 tick();eq(#sent,1);ack(s,'kai_trance');tick();tick();eq(sent[2],'break trance')
 eq(s.player.defences.kai_trance,true);ack(s,'kai_trance',true);tick();eq(s.player.defences.kai_trance,nil)
end)

test('unknown snapshots query once, independently authoritative',function()
 local s,sent,tick=fixture({unknown=true});only(s,'weathering');B.start(s)
 tick();eq(sent[1],'ab kaido');tick();eq(#sent,1)
 B.set_known(s,{'Weathering'});tick();eq(sent[2],'defences');tick();eq(#sent,2)
 B.sync(s,'Add','toughness');eq(B.state(s).defs_known,false);tick();eq(#sent,2)
 B.sync(s,'List',{});tick();eq(sent[3],'weathering')
end)

test('solicited discovery timeout latches quiet fault',function()
 local s,sent,tick=fixture({unknown=true});B.start(s);tick();clock=clock+13;tick();eq(#sent,1)
 assert(B.state(s).fault);eq(B.state(s).master,false);eq(B.start(s),false);tick();eq(#sent,1)
 B.reset(s);eq(B.state(s).fault,nil);eq(B.state(s).master,false)
end)

test('known unlearned abilities skipped, not retried',function()
 local s,sent,tick=fixture();B.set_known(s,{});B.start(s);tick();eq(#sent,0);eq(B.state(s).sequence,false)
 B.toggle(s,'trance',false);tick();eq(#sent,0)
end)

test('own Kaido rows, authoritative own defence listing and exact lines',function()
 local s,sent,tick=fixture({unknown=true});only(s,'toughness');B.start(s);tick()
 B.text(s,'You possess the following abilities in Kaido:')
 B.text(s,'Toughness        Toughen your skin.')
 B.text(s,'Trance           Generate Kai.')
 B.text(s,'Type AB KAIDO <ability> for more information.')
 eq(B.state(s).known.toughness,true);eq(B.state(s).known.trance,true);eq(B.state(s).known.weathering,nil)
 tick();eq(sent[2],'defences')
 B.text(s,'You have the following active defences:')
 B.text(s,'You are immune to normal weather.')
 B.text(s,'You are protected by 20 defences.')
 eq(B.state(s).defs_known,false);eq(B.state(s).have.weathering,true);eq(B.state(s).have.toughness,nil)
 tick();eq(#sent,2,'partial text cannot establish complete negative knowledge')
 B.sync(s,'List',{'weathering'});tick();eq(sent[3],'toughness')
 B.text(s,'Reporter says, "You have already toughened your skin."');eq(B.state(s).pending.confirmed,false)
 B.text(s,'You have already toughened your skin.');eq(B.state(s).pending.confirmed,true)
 B.on_prompt(s);tick();eq(B.state(s).pending,nil)
end)

test('GMCP payloads and defence ID aliases remain separated',function()
 local s=fixture();s.player.defences.unrelated=true
 B.sync(s,'List',{{name='kai_trance'},{name='boosted_regen'},{name='night sight'}})
 eq(B.state(s).have.trance,true);eq(B.state(s).have.boosting,true);eq(B.state(s).have.nightsight,true)
 eq(s.player.defences.kai_trance,true);eq(s.player.defences.unrelated,true)
 B.sync(s,'Remove',{name='kai_trance'});eq(s.player.defences.kai_trance,nil)
 B.sync(s,'List',{defences={{name='Weathering'}}});eq(B.state(s).have.weathering,true);eq(B.state(s).have.boosting,nil)
end)

test('health/mana/WP reserves and zero encodings',function()
 for _,case in ipairs({{'hp',649,'weathering'},{'mana',499,'weathering'},{'willpower',249,'regeneration'}}) do
  local s,sent,tick=fixture();only(s,case[3]);s.player[case[1]]=case[2];B.start(s);tick()
  eq(#sent,0,case[1]);eq(B.state(s).sequence,false)
 end
 local s,sent,tick=fixture();only(s,'weathering');s.player.hp=650;s.player.mana=500;s.player.balance='0'
 B.start(s);tick();eq(#sent,0);s.player.balance='1';tick();eq(sent[1],'weathering')
 local s2,sent2,tick2=fixture();only(s2,'regeneration');s2.player.willpower=nil;s2.player.maxwillpower=nil
 B.start(s2);tick2();eq(#sent2,0,'unknown WP cannot authorize a new drain')
end)

test('vitality full resources and 180 second loss cooldown',function()
 local s,sent,tick=fixture();only(s,'vitality');s.player.mana=999;B.start(s);tick();eq(#sent,0);eq(B.state(s).sequence,false)
 s.player.mana=1000;B.start(s);tick();eq(sent[1],'vitality');ack(s,'vitality');tick()
 B.sync(s,'Remove','vitality');eq(B.state(s).cooldown.vitality,1180)
 B.start(s);tick();eq(#sent,1);eq(B.state(s).sequence,false)
 clock=1181;B.start(s);tick();eq(sent[2],'vitality','event stream preserves known snapshot past cooldown without polling')
end)

test('boost depends on confirmed regeneration, not sent intent',function()
 local s,sent,tick=fixture();only(s,'boosting');B.start(s);tick();eq(#sent,0)
 B.sync(s,'Add','regeneration');B.start(s);tick();eq(sent[1],'boost regeneration')
 B.text(s,'You are regenerating lost health through the power of Kaido.');B.on_prompt(s);tick()
 eq(B.state(s).have.boosting,true);eq(s.player.defences.boosted_regen,true)
end)

test('readiness, survival, walker, physical and mental waits',function()
 for _,field in ipairs({'balance','equilibrium','left_arm_balance','right_arm_balance'}) do
  local s,sent,tick=fixture();only(s,'weathering');B.start(s);s.player[field]=false;tick();eq(#sent,0,field)
  s.player[field]=true;tick();eq(#sent,1)
 end
 for _,aff in ipairs({'paralysis','paresis','prone','asleep','webbed','stun','left_arm_crippled'}) do
  local s,sent,tick=fixture();only(s,'weathering');B.start(s);s.player.afflictions[aff]=true;tick();eq(#sent,0,aff)
 end
 local s,sent,tick,r=fixture();only(s,'weathering');B.start(s);tick(true);eq(#sent,0)
 s.walker={pending={}};tick();eq(#sent,0);s.walker=nil;r.waiting=true;tick();eq(#sent,0)
 r.waiting=false;r.fault='existing';tick();eq(#sent,0);r.fault=nil
 s.mental={eq_pending=clock};tick();eq(#sent,0);s.mental=nil;tick();eq(#sent,1)
end)

test('death, actual TCP, disconnect, training end, invalid class disarm',function()
 for _,reason in ipairs({'dead','hp','connected','tcp','training','class'}) do
  local s,sent,tick=fixture();only(s,'weathering');B.master(s,true)
  if reason=='dead' then s.player.dead=true elseif reason=='hp' then s.player.hp=0
  elseif reason=='connected' then s.connected=false
  elseif reason=='tcp' then getConnectionInfo=function() return '',0,false end
  elseif reason=='training' then s.training_battle_ended=true else B.set_class(s,'Templar') end
  tick();eq(#sent,0,reason);eq(B.state(s).master,false)
  getConnectionInfo=function() return '',0,true end
 end
 local s=fixture();B.master(s,true);B.set_class(s,'monk');eq(B.state(s).master,true,'unchanged class preserves intent')
 B.set_class(s,'Shapeshifter');eq(B.start(s),false);B.set_class(s,'Monk');eq(B.state(s).known_ready,false)
end)

test('GMCP add alone cannot release; real ready prompt required',function()
 local s,sent,tick=fixture();only(s,'toughness');B.start(s);tick();B.sync(s,'Add','toughness')
 eq(tick().busy,true);eq(B.state(s).pending~=nil,true);eq(#sent,1)
 s.player.equilibrium=false;B.on_prompt(s);eq(tick().busy,true)
 s.player.equilibrium=true;eq(tick().busy,true,'stale unready prompt not ready evidence')
 B.on_prompt(s);eq(tick().busy,false);eq(B.state(s).pending,nil)
end)

test('unconfirmed fresh prompt reconciles once, never resends cast',function()
 local s,sent,tick=fixture();only(s,'weathering');B.start(s);tick();B.on_prompt(s)
 tick();eq(sent[2],'defences');tick();B.on_prompt(s);tick();eq(#sent,2)
 B.sync(s,'List',{'weathering'});tick();eq(B.state(s).pending,nil);eq(#sent,2)
end)

test('missing reconciliation result times out with retained barrier',function()
 local s,sent,tick=fixture();only(s,'weathering');B.start(s);tick();B.on_prompt(s);tick();B.sync(s,'List',{})
 eq(tick().busy,true);clock=clock+13;eq(tick().busy,true);assert(B.state(s).fault)
 eq(B.state(s).master,false);B.stop(s);eq(B.state(s).pending~=nil,true);eq(B.start(s),false);tick();eq(#sent,2)
 ack(s,'weathering');eq(tick().busy,false);eq(B.state(s).pending,nil);eq(B.state(s).fault,nil)
 eq(B.state(s).master,false)
end)

test('stop, disarm, disconnect and rearm never erase committed barrier',function()
 local s,sent,tick=fixture();only(s,'weathering');B.start(s);tick();local p=B.state(s).pending
 B.stop(s);eq(B.state(s).pending,p);B.master(s,true);eq(B.state(s).pending,p);tick();eq(#sent,1)
 s.connected=false;tick();eq(B.state(s).pending,p);eq(B.state(s).master,false)
 s.connected=true;ack(s,'weathering');tick();eq(B.state(s).pending,nil);eq(B.state(s).master,false)
end)

test('sender exception/false fail closed; reviewed reset disarms',function()
 for _,sender in ipairs({function() error('fake failure') end,function() return false end}) do
  local s,sent,tick,r=fixture();only(s,'weathering');B.start(s)
  eq(B.service(s,r,sender,false).busy,true);assert(B.state(s).fault);local p=B.state(s).pending
  ack(s,'weathering');tick();eq(B.state(s).pending,p,'ambiguous delivery cannot auto release')
  B.stop(s);B.master(s,true);eq(B.state(s).pending,p);B.reset(s);eq(B.state(s).pending,nil);eq(B.state(s).fault,nil);eq(B.state(s).master,false)
 end
end)

test('synchronous sender callback and reentrant service cannot duplicate',function()
 local s,sent,tick,r=fixture();only(s,'weathering');B.start(s);local calls=0
 local sender
 sender=function(cmd)
  calls=calls+1;eq(B.state(s).pending~=nil,true)
  B.sync(s,'Add','weathering');B.on_prompt(s)
  eq(B.service(s,r,sender,false).busy,true)
 end
 B.service(s,r,sender,false);eq(calls,1);eq(B.state(s).pending~=nil,true)
 tick();eq(B.state(s).pending,nil);eq(#sent,0)
end)

test('own rejection latches backoff/fault; speech is never own evidence',function()
 local s,sent,tick=fixture();only(s,'weathering');B.start(s);tick()
 B.text(s,'Dummy says, "You must regain balance first."');eq(B.state(s).fault,nil)
 B.text(s,'You must regain balance first.');assert(B.state(s).fault);eq(B.state(s).retry.weathering,1005)
 B.on_prompt(s);tick();eq(#sent,1);eq(B.state(s).pending~=nil,true)
 B.reset(s);eq(B.state(s).sequence,false)
end)

test('full snapshot absence only, Add/Remove do not invent known absence',function()
 local s,sent,tick=fixture({unknown=true});B.sync(s,'Remove','weathering');eq(B.state(s).defs_known,false)
 B.text(s,'Someone tells you, "You are immune to normal weather."');eq(B.state(s).have.weathering,nil)
 B.text(s,'You have gained the Weathering defence.');eq(B.state(s).have.weathering,true);eq(B.state(s).defs_known,false)
 B.sync(s,'List',{});eq(B.state(s).defs_known,true);eq(B.state(s).have.weathering,nil)
end)

test('executor ASSIST approval and mental offense honor buff barrier',function()
 local s,sent,tick=fixture();s.target=State.target('Enemy');s.target_generation=1;s.mode='FULL_AUTO'
 local action={command='combo Enemy sdk spp spp',generation=1}
 local r=Runner.new(s,{choose=function() return action end});r.mode='ASSIST';r.sender=function(cmd) sent[#sent+1]=cmd end
 r.pending=action;r.recovery_snapshot={balance=44};r.waiting_requires={balance=true}
 B.state(s).pending={key='weathering'}
 eq(Runner.execute(r,action,true),false);eq(Runner.approve(r),false);eq(#sent,0)
 eq(r.recovery_snapshot.balance,44);eq(r.pending,action)
 s.policy={players_known=true,players={enemy=true}};s.mental={status='idle',generation=1,retry_at=0,enabled=true}
 eq(Mental.tick(s,r.sender,false),false);eq(#sent,0)
 B.state(s).pending=nil;eq(Runner.execute(r,action,true),true);eq(#sent,1)
end)

test('idle-safe has_work includes explicit-off queue and retained barrier',function()
 local s,sent,tick=fixture();eq(B.has_work(s),false)
 B.start(s);eq(B.has_work(s),true);B.stop(s);eq(B.has_work(s),false)
 B.master(s,true);eq(B.has_work(s),true);B.master(s,false);eq(B.has_work(s),false)
 B.toggle(s,'trance',false);eq(B.has_work(s),true);tick();B.stop(s);eq(B.has_work(s),true)
 ack(s,'trance',true);tick();eq(B.has_work(s),false)
end)

test('native GMCP positive ahead of owned handler suppresses duplicate casts',function()
 local s,sent,tick=fixture();only(s,'trance');s.player.defences.kai_trance=true
 B.start(s);tick();eq(#sent,0);eq(B.state(s).sequence,false)
 eq(B.state(s).have.trance,nil,'canonical positive not fabricated into owned snapshot')
 s.player.defences.kai_trance=nil;B.start(s);tick();eq(sent[1],'kai trance')
 ack(s,'trance');tick();B.sync(s,'Remove','trance');eq(s.player.defences.kai_trance,nil)
 clock=clock+3;B.start(s);tick();eq(sent[2],'kai trance','owned removal permits reapply')
end)

test('owned full absence clears matching canonical aliases, never unrelated defences',function()
 local s,sent,tick=fixture();only(s,'trance');s.player.defences['Kai Trance']=true;s.player.defences.other=true
 B.sync(s,'List',{});eq(s.player.defences['Kai Trance'],nil);eq(s.player.defences.other,true)
 B.start(s);tick();eq(sent[1],'kai trance')
end)

test('canonical missing alone never disproves owned positive',function()
 local s,sent,tick=fixture();only(s,'trance');B.sync(s,'Add','kai_trance');s.player.defences.kai_trance=nil;s.player.defences.trance=nil
 B.start(s);tick();eq(#sent,0);eq(B.state(s).have.trance,true)
 B.sync(s,'Remove','kai_trance');B.start(s);tick();eq(sent[1],'kai trance')
end)

test('pausing maintenance preserves independent one-shot and explicit-off intent',function()
 local s,sent,tick=fixture();only(s,'weathering');B.start(s);B.master(s,false)
 eq(B.state(s).sequence,true);tick();eq(sent[1],'weathering');ack(s,'weathering');tick();tick()
 B.toggle(s,'regeneration',false);B.master(s,false);eq(B.has_work(s),true);tick();eq(sent[2],'regeneration off')
end)

test('disconnect and class changes invalidate stale ready prompt evidence',function()
 local s,sent,tick=fixture();only(s,'weathering');B.start(s);tick();ack(s,'weathering')
 local p=B.state(s).pending;s.connected=false;tick();s.connected=true;eq(tick().busy,true);eq(B.state(s).pending,p)
 B.on_prompt(s);tick();eq(B.state(s).pending,nil)
 local s2,sent2,tick2=fixture();only(s2,'weathering');B.start(s2);tick2();ack(s2,'weathering')
 B.set_class(s2,'Templar');B.set_class(s2,'Monk');B.on_prompt(s2);eq(tick2().busy,true)
 eq(B.state(s2).pending.confirmed,false);eq(sent2[2],'defences')
 B.sync(s2,'List',{'weathering'});tick2();eq(B.state(s2).pending,nil);eq(B.state(s2).master,false)
end)


test('full-resource Vitality goes before mana-spending preparations',function()
 local s,sent,tick=fixture();B.start(s);tick();eq(sent[1],'vitality')
end)
test('unknown willpower cannot enable a new draining defence',function()
 local s,sent,tick=fixture();only(s,'regeneration');s.player.willpower=nil;s.player.maxwillpower=nil
 B.toggle(s,'regeneration',true);tick();eq(#sent,0);eq(B.state(s).pending,nil)
end)
test('explicit drain cancellation remains possible during low-health hold',function()
 local s,sent,tick=fixture();B.sync(s,'Add','regeneration');s.player.hp=100;s.player.mana=0
 B.toggle(s,'regeneration',false);tick(true);eq(sent[1],'regeneration off');eq(B.state(s).pending.off,true)
end)
test('rejected opt-in does not mutate wanted state',function()
 local s,sent,tick=fixture();B.set_class(s,'Shaman');eq(B.state(s).wanted.regeneration,false)
 eq(B.toggle(s,'regeneration',true),false);eq(B.state(s).wanted.regeneration,false);eq(#sent,0)
end)

test('unlearned cancellation never exempts activation from survival hold',function()
 local s,sent,tick=fixture();only(s,'weathering');B.set_known(s,{'weathering'})
 B.start(s);B.toggle(s,'regeneration',false);tick(true)
 eq(#sent,0);eq(B.state(s).pending,nil);eq(B.state(s).sequence,true)
 tick(true);eq(#sent,0);tick(false);eq(sent[1],'weathering')
end)
test('only supported learned OFF bypasses hold, never readiness barriers',function()
 for _,barrier in ipairs({'none','balance','runner','mental','walker'}) do
  local s,sent,tick,r=fixture();only(s,'weathering');B.set_known(s,{'weathering','regeneration'})
  B.start(s);B.toggle(s,'regeneration',false);s.player.hp=1;s.player.mana=0
  if barrier=='balance' then s.player.balance=false elseif barrier=='runner' then r.waiting=true
  elseif barrier=='mental' then s.mental={eq_pending=clock} elseif barrier=='walker' then s.walker={pending={}} end
  tick(true);eq(#sent,barrier=='none' and 1 or 0,barrier)
  if barrier=='none' then eq(sent[1],'regeneration off');ack(s,'regeneration',true);tick(true);tick(true);eq(#sent,1) end
 end
 local s,sent,tick=fixture();only(s,'weathering');B.start(s)
 B.state(s).cancel.weathering=true -- malformed/stale queue must not become an ON command
 tick(true);eq(#sent,0)
end)


test('actual regeneration stream never clears active regen or repeats defences',function()
 local s,sent,tick=fixture();only(s,'regeneration');B.master(s,true)
 tick();eq(sent[1],'regeneration on')
 B.sync(s,'Add','regeneration');B.text(s,'You begin to concentrate on regeneration of your wounds.')
 B.on_prompt(s);tick();eq(B.state(s).pending,nil)
 for i=1,6 do
  B.sync(s,'List',{{name='regeneration'},{name='boosted_regen'},{name='constitution'},{name='nightsight'}})
  B.text(s,'You have the following active defences:')
  B.text(s,'You are regenerating lost health through will.')
  B.text(s,'Your regeneration is boosted.')
  B.text(s,'You are protected by 25 defences.')
  clock=clock+3;B.on_prompt(s);tick()
  eq(B.state(s).have.regeneration,true,'raw listing erased regeneration')
  eq(B.state(s).have.boosting,true,'raw listing confused boost with regeneration')
  eq(B.state(s).have.constitution,true,'partial parser erased GMCP constitution')
  eq(B.state(s).have.nightsight,true,'partial parser erased GMCP nightsight')
  eq(#sent,1,'active regeneration triggered a repeated cast or query')
 end
end)
test('event-driven known snapshots do not poll on idle age',function()
 local s,sent,tick=fixture();only(s,'regeneration');B.sync(s,'List',{'regeneration'});B.master(s,true)
 for _,at in ipairs({1060,1121,1300,1600})do clock=at;tick();eq(#sent,0,'idle age caused a DEFENCES poll')end
 B.sync(s,'Remove','regeneration');tick();eq(sent[1],'regeneration on','observed down failed to reapply')
 B.text(s,'You begin to concentrate on regeneration of your wounds.');B.on_prompt(s);tick();eq(B.state(s).pending,nil,'observed up failed to acknowledge')
end)

test('newer GMCP removal and full absence beat an earlier text row',function()
 for _,kind in ipairs({'Remove','List'})do
  local s,sent,tick=fixture();only(s,'regeneration');B.master(s,true)
  B.text(s,'You have the following active defences:')
  B.text(s,'You are regenerating lost health through will.')
  if kind=='Remove'then B.sync(s,'Remove','regeneration')else B.sync(s,'List',{})end
  B.text(s,'You are protected by 25 defences.')
  eq(B.state(s).have.regeneration,nil,kind..' was overwritten by an older buffered row')
  tick();eq(sent[1],'regeneration on',kind..' did not allow one reapplication')
 end
end)
print(string.format('buffs: %d tests, %d assertions passed (pure fake senders)',tests,assertions))
