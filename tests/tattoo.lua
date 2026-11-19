-- Standalone Lua 5.1/5.4. No inherited native environment or live sender.
local root=arg[1] or 'combat_v2/'
local M=dofile(root..'tattoo.lua')
local checks=0
local function eq(a,b,msg) checks=checks+1;assert(a==b,(msg or 'assertion')..': '..tostring(a)..' ~= '..tostring(b)) end
local function fixture()
 local sent,clock,stops={},0,0
 local s={mode='BASH',connected=true,player={hp=100,mana=100,balance=true,equilibrium=true,left_arm_balance=true,right_arm_balance=true,mounted=false,afflictions={}},room={id=1,item_version=3,items={}},hunting={ih={room_id=1,responded=true,start_version=2}},buffs={master=true,wanted={mindseye=true},cancel={}},mental={status='idle'}}
 local c={current=s,mode='BASH',runner={mode='BASH'},containers_refill_enabled=true,containers_data={},elemental_recovery={phase='idle',armed=true}}
 local a={clock=function() return clock end,connected=function() return true end}
 c.tattoo_api=a
 a.send=function(cmd) sent[#sent+1]=cmd end
 a.set_mode=function(mode)
  stops=stops+1;eq(mode,'OFF');c.mode='OFF';s.mode='OFF';c.runner.mode='OFF';s.buffs.master=false
  c.elemental_recovery.pending=nil;c.elemental_recovery.phase='idle';c.elemental_recovery.armed=false
  return true
 end
 return c,s,sent,function(n) clock=clock+n end,function() return stops end
end
local function query(c,typ,cost)
 M.text(c,(typ or 'Mindseye')..' (Tattoos)                              Known: Yes')
 M.text(c,cost or 'Required inks: 1 green, and 2 blue inks')
 M.prompt(c)
end
local function receipt(c,n,color) M.text(c,'You remove '..n..' '..color..'ink, bringing the total in the cache to 10.');M.prompt(c) end
local function complete(c,typ)
 M.text(c,"As the "..(typ or 'mindseye').." tattoo's shape is codified, the last of the ink leaves the air, and you pause for a moment to admire your handiwork.")
 M.prompt(c)
end
for _,bad in ipairs({'','mindseye Bob Jones','mindseye;quit','mindseye Bob|quit','mindseye\nquit','mindseye\tBob','mindseye Bob-evil','mindseye 12','mindseye Bob\r','mindseye \\Bob'}) do eq(M.parse(bad),nil,bad) end
eq(M.parse('mindseye').target,'me');eq(M.parse('MINDSEYE Alice').target,'Alice');eq(M.parse(' NEWTAT me ').type,'newtat')
for _,bad in ipairs({'Required inks: none','Required inks: 0 blue inks','Required inks: 1 white ink','Required inks: 1 green, 2 green inks','Required inks: 1000 blue inks','Required inks: 1 blue,','Required inks: 1 green and ???','Required inks: 2 green inks junk'}) do eq(M.recipe(bad),nil,bad) end
eq(#M.recipe('Required inks: 1 green, 1 gold, and 1 obsidian inks.'),3)
eq(M.recipe('Required inks: 5 green inks')[1].count,5)
-- Happy path, exact amounts, exact typed target, no touch/cureset/army/resume.
do
 local c,s,out,advance,stops=fixture();eq(M.request(c,'mindseye Alice'),true);eq(out[1],'ab tattoos mindseye');eq(stops(),0)
 query(c);eq(stops(),1);eq(out[2],'outc 1 greenink');eq(c.user_activity,c.tattoo_owner.txn)
 M.prompt(c);eq(#out,2);receipt(c,1,'green');eq(out[3],'outc 2 blueink');receipt(c,2,'blue');eq(out[4],'ink mindseye on any of Alice')
 eq(M.busy(c),true);advance(26);M.prompt(c);eq(M.busy(c),true,'25s is not completion')
 complete(c);eq(M.busy(c),false);eq(c.user_activity,nil);eq(#out,4);eq(s.mode,'OFF');eq(s.buffs.master,false);eq(s.buffs.wanted.mindseye,true);eq(c.containers_refill_enabled,false)
 M.prompt(c);complete(c);eq(#out,4)
end
-- Actual native header includes the lesson annotation; it must not brick inking.
do local c,s,out=fixture();M.request(c,'mindseye');M.text(c,'Mindseye (Tattoos)                            Known: Yes (56 lessons)');M.text(c,'Required inks: 1 green, and 2 blue inks');M.prompt(c);eq(out[2],'outc 1 greenink')end
-- Cancelling a read-only query never drops a resource action or grants future AB authority.
do local c,s,out=fixture();M.request(c,'mindseye');M.prompt(c);eq(c.tattoo_owner.txn.unknown,true);eq(M.request(c,'cancel'),true);eq(M.busy(c),false);eq(c.user_activity,nil);eq(M.request(c,'tree'),false);eq(#out,1)end
do local c,s,out=fixture();M.request(c,'mindseye');query(c);local t=c.tattoo_owner.txn;eq(M.request(c,'cancel'),false);eq(c.tattoo_owner.txn,t);eq(c.user_activity,t)end
-- Default self and dynamic recipe (legacy costs are never consulted).
do local c,s,out=fixture();M.request(c,'tree');query(c,'Tree','Required inks: 3 green inks');receipt(c,3,'green');eq(out[3],'ink tree on any of me');complete(c,'tree');eq(M.busy(c),false) end
-- All pre-existing barriers must be refused WITHOUT calling destructive STOP.
local blockers={
 function(c) c.transport_unknown=true end,function(c) c.root={transport_unknown=true} end,
 function(c) c.runner.root={dispatching=true} end,function(c) c.root={action_dispatching=true} end,
 function(c) c.current.mental.pending={} end,function(c) c.current.mental.dispatching=true end,
 function(c) c.current.mental.physical_transport={} end,function(c) c.travel_owner={recall_due=true} end,
 function(c) c.runner.waiting=true end,function(c) c.runner.pending={} end,
 function(c) c.runner.dispatching=true end,function(c) c.runner.transport_barrier={} end,
 function(c) c.runner.transport_unknown={} end,function(c) c.runner.fault='x' end,
 function(c) c.current.buffs.pending={} end,function(c) c.current.buffs.fault='x' end,
 function(c) c.current.buffs.todo={'mindseye'} end,function(c) c.current.buffs.cancel={'mindseye'} end,
 function(c) c.current.buffs.sequence=true end,function(c) c.containers_data.barrier={} end,
 function(c) c.containers_data.action_dispatching=true end,function(c) c.current.mental.eq_pending=1 end,
 function(c) c.current.mental.status='requested' end,function(c) c.current.walker={pending={}} end,
 function(c) c.elemental_recovery.committed=true end,
 function(c) c.elemental_recovery.pending={phase='probe',kind='mystery'} end,
 function(c) c.elemental_recovery.pending={phase='drain',kind='recovery'} end,
 function(c) c.elemental_recovery.fault='unknown';c.elemental_recovery.phase=nil end,
 function(c) c.travel_owner={txn={}} end,function(c) c.travel={busy=function() return true end} end,
 function(c) c.user_activity={} end,function(c) c.current.player.mounted=12345 end,
 function(c) c.current.player.mounted=nil end,function(c) c.current.player.hp=0 end,
 function(c) c.current.player.mana=0 end,function(c) c.current.player.balance=false end,
 function(c) c.current.player.afflictions.paralysis=true end,function(c) c.current.room.items={{attrib='m',name='enemy'}} end,
 function(c) c.current.hunting.ih.responded=false;c.current.room.item_version=2 end,
 function(c) c.tattoo_api.connected=function() return false end end
}
for i,f in ipairs(blockers) do local c,s,out,advance,stops=fixture();f(c);eq(M.request(c,'mindseye'),false,'blocker '..i);eq(#out,0);eq(stops(),0) end
-- Timed-out read-only globe probe and container query quarantine are NOT resource barriers.
do
 local c,s,out=fixture();local p={kind='recovery',phase='probe'}
 c.elemental_recovery={armed=false,phase='probe',fault='recovery timeout',pending=p};c.containers_data.quarantine='response timeout'
 eq(M.request(c,'mindseye'),true);query(c);eq(out[2],'outc 1 greenink');eq(c.elemental_recovery.pending,p);eq(c.elemental_recovery.fault,'recovery timeout');eq(c.containers_data.quarantine,'response timeout')
end
-- Query proof failures never STOP or withdraw.
for _,scenario in ipairs({'none','no','wrong','malformed','duplicate','unknowncolor'}) do
 local c,s,out,advance,stops=fixture();M.request(c,'mindseye')
 if scenario~='none' then M.text(c,(scenario=='wrong' and 'Tree' or 'Mindseye')..' (Tattoos) Known: '..(scenario=='no' and 'No' or 'Yes')) end
 if scenario=='duplicate' then M.text(c,'Mindseye (Tattoos) Known: Yes') end
 if scenario~='malformed' then M.text(c,scenario=='unknowncolor' and 'Required inks: 1 white inks' or 'Required inks: 1 green, and 2 blue inks') end
 M.prompt(c);eq(#out,1);eq(stops(),0);eq(c.tattoo_owner.txn.unknown,true)
end
-- Independent Known line supported; quoted speech cannot acknowledge anything.
do local c,s,out=fixture();M.request(c,'mindseye');M.text(c,'Mindseye (Tattoos)');M.text(c,'Known: Yes');M.text(c,'Required inks: 1 green, and 2 blue inks');M.prompt(c);eq(#out,2);M.text(c,'Alice says, "You remove 1 greenink, bringing the total in the cache to 10."');M.prompt(c);eq(#out,2) end
-- No ACK / insufficient stock, duplicates, mismatch: retain partial withdrawals, no retry/INK.
for _,case in ipairs({'missing','insufficient','mismatch','duplicate'}) do
 local c,s,out,advance=fixture();M.request(c,'mindseye');query(c);receipt(c,1,'green');eq(#out,3)
 if case=='insufficient' then M.text(c,'You have no blueink in the cache.')
 elseif case=='mismatch' then M.text(c,'You remove 1 blueink, bringing the total in the cache to 10.')
 elseif case=='duplicate' then M.text(c,'You remove 2 blueink, bringing the total in the cache to 10.');M.text(c,'You remove 2 blueink, bringing the total in the cache to 10.') end
 advance(11);M.tick(c);M.prompt(c);eq(#out,3);eq(M.busy(c),true);eq(#c.tattoo_owner.txn.receipts,case=='duplicate' and 2 or 1);eq(M.request(c,'tree'),false)
end
-- Transport false/throw for each phase; no retry even after exact late receipts.
for _,phase in ipairs({'query','withdraw','ink'}) do for _,behavior in ipairs({'false','throw'}) do
 local c,s,out,advance=fixture();local base=c.tattoo_api.send
 c.tattoo_api.send=function(cmd)
  base(cmd)
  if (phase=='query' and cmd:match('^ab ')) or (phase=='withdraw' and cmd:match('^outc ')) or (phase=='ink' and cmd:match('^ink ')) then
   if behavior=='throw' then error('unknown transport') end;return false
  end
 end
 M.request(c,'mindseye');if phase~='query' then query(c) end
 if phase=='ink' then receipt(c,1,'green');receipt(c,2,'blue') end
 local n=#out;receipt(c,1,'green');complete(c);advance(100);M.tick(c);M.prompt(c);eq(#out,n);eq(c.tattoo_owner.txn.unknown,true)
end end
-- Pause revalidates commitments and room, rather than clearing a new wait.
do local c,s,out,advance,stops=fixture();M.request(c,'mindseye');c.runner.waiting=true;query(c);eq(stops(),0);eq(c.runner.waiting,true);eq(#out,1) end
for _,change in ipairs({'room','disconnect','mode','upkeep','refill'}) do
 local c,s,out=fixture();M.request(c,'mindseye');query(c);receipt(c,1,'green');receipt(c,2,'blue');local txn=c.tattoo_owner.txn
 if change=='room' then s.room.id=2 elseif change=='disconnect' then M.disconnect(c) elseif change=='mode' then c.mode='BASH' elseif change=='upkeep' then s.buffs.master=true elseif change=='refill' then c.containers_refill_enabled=true else s.room.items={{attrib='m'}} end
 complete(c);eq(M.busy(c),true);eq(c.tattoo_owner.txn,txn);eq(txn.unknown,true);eq(#out,4)
end
-- Detach/reload and late events preserve unknown owned transactions.
do local c,s,out=fixture();M.request(c,'mindseye');query(c);local t=c.tattoo_owner.txn;M.detach(c);eq(M.busy(c),true);eq(M.attach(c),false);eq(c.user_activity,t);local N=dofile(root..'tattoo.lua');eq(N.busy(c),true);receipt(c,1,'green');eq(#out,2) end
-- Reentrant fake transport cannot dispatch the next command before it returns.
do
 local c,s,out=fixture();local send=c.tattoo_api.send
 c.tattoo_api.send=function(cmd) send(cmd);eq(M.request(c,'tree'),false);if cmd:match('^outc 1 green') then M.text(c,'You remove 1 greenink, bringing the total in the cache to 10.');M.prompt(c) end end
 M.request(c,'mindseye');query(c);eq(#out,2);M.prompt(c);eq(#out,3)
end
-- Native adapter ownership, atomic hook failure cleanup and third TCP result.
do
 local c,s,out=fixture();local hooks,killed={},{};local a=c.tattoo_api
 local function register(...) hooks[#hooks+1]={...};return #hooks end
 a.tempAlias=register;a.tempRegexTrigger=register;a.tempPromptTrigger=register;a.registerAnonymousEventHandler=register
 a.killAlias=function(id) killed[#killed+1]=id end;a.killTrigger=a.killAlias;a.killAnonymousEventHandler=a.killAlias
 eq(M.attach(c),true);eq(#hooks,5);eq(#out,0);eq(c.tattoo_owner.attached,true);M.detach(c);eq(#killed,5)
 a.tempPromptTrigger=function() return false end;eq(M.attach(c),false);eq(#killed,7);eq(c.tattoo_owner.attached,false)
 a.connected=nil;a.getConnectionInfo=function() return 'host',23,true end;eq(M.safe(c),true)
 a.getConnectionInfo=function() return true,23,false end;eq(M.safe(c),false)
end
-- Completion bookkeeping is not a new action: NPCs/curing do not invalidate exact own success.
for _,change in ipairs({'npc','cure','inspection'}) do
 local c,s,out=fixture();M.request(c,'mindseye');query(c);receipt(c,1,'green');receipt(c,2,'blue')
 if change=='npc' then s.room.items={{attrib='m'}} elseif change=='cure' then s.player.afflictions.paralysis=true else s.hunting.ih=nil end
 complete(c);eq(M.busy(c),false);eq(#out,4);eq(c.mode,'OFF');eq(c.user_activity,nil)
end
-- Missing readiness waits within the finite INK lease; timers cannot complete it.
do
 local c,s,out,advance=fixture();M.request(c,'mindseye');query(c);receipt(c,1,'green');receipt(c,2,'blue')
 s.player.equilibrium=false;complete(c);local t=c.tattoo_owner.txn;eq(t.ack,true);eq(t.unknown,nil)
 advance(3);M.tick(c);eq(M.busy(c),true);s.player.equilibrium=true;M.tick(c);eq(M.busy(c),true)
 M.prompt(c);eq(M.busy(c),false);eq(#out,4)
end
do
 local c,s,out,advance=fixture();M.request(c,'mindseye');query(c);receipt(c,1,'green');receipt(c,2,'blue')
 s.player.balance=false;complete(c);advance(41);M.tick(c);eq(c.tattoo_owner.txn.unknown,true)
 s.player.balance=true;M.prompt(c);eq(M.busy(c),true);eq(M.request(c,'cancel'),false);eq(#out,4)
end
-- Every preflight remains strict after a previous receipt, including NPC arrivals.
do
 local c,s,out=fixture();M.request(c,'mindseye');query(c);s.player.balance=false;receipt(c,1,'green')
 eq(#out,2);eq(c.tattoo_owner.txn.unknown,nil);s.player.balance=true;M.prompt(c);eq(out[3],'outc 2 blueink')
 s.room.items={{attrib='m'}};receipt(c,2,'blue');eq(#out,3);eq(c.tattoo_owner.txn.unknown,true)
end
-- A valid AB response can also wait for genuine recovery before destructive OFF.
do
 local c,s,out,advance,stops=fixture();M.request(c,'mindseye');s.player.balance=false;query(c)
 eq(#out,1);eq(stops(),0);eq(c.tattoo_owner.txn.unknown,nil);s.player.balance=true;M.prompt(c);eq(out[2],'outc 1 greenink');eq(stops(),1)
end
-- Cancelling cannot consume delayed AB proof or cancel a reentrant dispatch.
do
 local c,s,out,advance=fixture();local sender=c.tattoo_api.send
 c.tattoo_api.send=function(cmd) sender(cmd);eq(M.request(c,'cancel'),false) end
 M.request(c,'mindseye');advance(13);M.tick(c);eq(M.request(c,'status'),true);eq(M.request(c,'cancel'),true)
 local q=c.tattoo_owner.query_quarantine;query(c);eq(M.busy(c),false);eq(#out,1);eq(M.request(c,'tree'),false);eq(c.tattoo_owner.query_quarantine,q)
 eq(M.request(c,'status'),true);eq(#out,1);eq(c.user_activity,nil)
end
do local c,s,out=fixture();c.elemental_recovery={phase='idle',fault='recovery timeout'};eq(M.request(c,'mindseye'),true);query(c);eq(out[2],'outc 1 greenink')end
print('tattoo: '..checks..' assertions passed')
