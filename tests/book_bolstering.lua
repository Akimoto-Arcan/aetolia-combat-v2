-- Offline fake senders. Public captured AB/DEF strings, synthetic resources/times.
-- Duration substitution is a template compatibility fixture, not a captured ACK.
local root=assert(arg[1]);local B=dofile(root..'buffs.lua');local S=dofile(root..'state.lua')
local clock=100;function getEpoch()return clock end
function getConnectionInfo()return 'offline',0,true end
local n=0;local function check(v,why)n=n+1;assert(v,why or ('assertion '..n))end
local bookup='Your mind is racing from the effects of the Book tattoo for another 23 hours.'
local bolsterup='You have prepared yourself for incoming attacks.'
local bolsterdown='You allow your muscles to relax once more as you cease to bolster them.'
local function fresh(k,mode)
 clock=100;local s=S.new();s.connected=true;s.mode=mode or 'BASH';B.set_class(s,'Monk')
 local p=s.player;p.hp=100;p.maxhp=100;p.mana=100;p.maxmana=100
 p.balance=true;p.equilibrium=true;p.left_arm_balance=true;p.right_arm_balance=true
 for name in pairs(s.buffs.wanted)do s.buffs.wanted[name]=name==k end
 B.sync(s,'List',{});local sent={};local r={waiting=false};local function sender(c)sent[#sent+1]=c end
 local function tick(hold,policy)return B.service(s,r,sender,hold,policy)end
 return s,sent,tick,r,sender
end
local function report(s,count,active)
 B.text(s,'You have the following tattoos:');B.text(s,'Head: Book Uses left: '..count)
 if active then B.text(s,'Torso: Book Active')end
 B.on_prompt(s)
end
local function row(s,k)for _,r in ipairs(B.rows(s))do if r.key==k then return r end end end
-- Cold unknown evidence plus poisoned saved/direct intent cannot query or TOUCH.
for _,mode in ipairs({'OFF','SHADOW','ASSIST','FULL_AUTO','bash',''})do
 for _,known in ipairs({false,true})do
  local s,sent,tick=fresh('book',mode)
  if known then report(s,2)else B.invalidate(s)end
  check(not B.toggle(s,'book',true),'non-BASH API accepted ON')
  B.master(s,true);B.start(s);tick();clock=clock+100;tick()
  check(#sent==0 and not s.buffs.pending,'non-BASH discovery/activation')
  check(B.toggle(s,'book_tattoo',false) and not s.buffs.wanted.book,'local OFF blocked')
 end
end
-- ACTIVE tracking and alias migration stay available in every mode, without ink.
for _,mode in ipairs({'OFF','SHADOW','ASSIST','FULL_AUTO','BASH'})do
 local s,sent,tick=fresh('book',mode);s.buffs.have.book_tattoo=true
 check(row(s,'book').active and s.buffs.have.book_tattoo==nil)
 check(not s.buffs.tattoos.book,'migration invented ink')
 B.sync(s,'Remove','book_tattoo');check(not row(s,'book').active)
 s.player.defences.book_tattoo=true;check(row(s,'book').active)
 B.sync(s,'List',{});check(not row(s,'book').active,'fresh List failed to revoke alias')
 B.text(s,bookup);check(row(s,'book').active)
 B.text(s,'Your racing mind slows.');check(not row(s,'book').active)
 report(s,0,true);check(row(s,'book').active)
 if mode=='BASH' then check(B.toggle(s,'book_tattoo',true),'ACTIVE Book cannot select future intent')end
 B.master(s,true);tick();check(#sent==0,'ACTIVE touched')
 B.text(s,'You have the following tattoos:');B.text(s,'Head: Book Active')
 B.sync(s,'Remove','book_tattoo');B.on_prompt(s);check(not row(s,'book').active,'stale ACTIVE defeated Remove')
end
-- One debit, own ACK then fresh ready prompt; mode changes cannot unsend TOUCH.
for _,mode in ipairs({'OFF','ASSIST','FULL_AUTO','SHADOW'})do
 local s,sent,tick=fresh('book');report(s,2);check(B.toggle(s,'book_tattoo',true));tick()
 local p=s.buffs.pending;check(p and p.tattoo_debited and sent[1]=='touch book')
 check(s.buffs.tattoos.book.charges==1)
 s.mode=mode;check(B.toggle(s,'book',false));tick();check(s.buffs.pending==p)
 B.text(s,'Reporter says, "'..bookup..'"');check(not p.confirmed)
 B.text(s,bookup);B.sync(s,'Add','book_tattoo');check(p.confirmed and s.buffs.tattoos.book.charges==1)
 tick();check(s.buffs.pending==p)
 s.player.balance=false;B.on_prompt(s);tick();check(s.buffs.pending==p)
 s.player.balance=true;tick();check(s.buffs.pending==p)
 B.on_prompt(s);tick();check(not s.buffs.pending and #sent==1 and row(s,'book').active)
 clock=clock+90000;tick();check(#sent==1,'persistent effect cancelled/retouched')
end
-- Existing death protection is unrelated; no Starburst opt-in or conflict for Book.
do
 local s,sent,tick,r=fresh('book');report(s,1);B.master(s,true)
 local function sender(c)
  sent[#sent+1]=c;s.mode='OFF';B.text(s,bookup);B.on_prompt(s)
  check(B.service(s,r,sender).busy,'reentrant dispatch escaped')
 end
 B.service(s,r,sender);check(#sent==1 and s.buffs.pending,'synchronous ACK lost dispatch barrier')
 tick();check(not s.buffs.pending and #sent==1,'all-mode settlement failed')
end
do
 local s,sent,tick=fresh('book');report(s,1);B.sync(s,'Add','soulcage');check(B.toggle(s,'book',true));tick()
 check(sent[1]=='touch book' and s.buffs.tattoos.book.charges==0)
 B.text(s,'You have the following tattoos:');B.text(s,'Head: Book Uses left: 9')
 B.text(s,bookup);B.on_prompt(s);tick();B.text(s,'Your racing mind slows.');clock=clock+3;tick()
 check(#sent==1 and s.buffs.tattoos.book.charges==0,'unresolved report replenished consumption')
end
for _,barrier in ipairs({'hold','policy','physical','mental','walker','balance','mana','hp'})do
 local s,sent,tick,r=fresh('book');report(s,1);B.master(s,true)
 if barrier=='physical'then r.fault='unknown' elseif barrier=='mental'then s.mental={eq_pending={}}
 elseif barrier=='walker'then s.walker={pending={}} elseif barrier=='balance'then s.player.balance=false
 elseif barrier=='mana'then s.player.mana=1 elseif barrier=='hp'then s.player.hp=1 end
 tick(barrier=='hold',barrier=='policy' and {} or nil);check(#sent==0 and s.buffs.tattoos.book.charges==1,barrier)
end
for _,kind in ipairs({'false','throw','reject','disconnect','class'})do
 local s,sent,tick,r=fresh('book');report(s,1);B.master(s,true)
 if kind=='false' or kind=='throw' then
  B.service(s,r,function(c)sent[#sent+1]=c;if kind=='throw'then error('offline')end;return false end)
 else tick()end
 local p=s.buffs.pending;check(p and p.tattoo_debited)
 if kind=='reject'then B.text(s,'You must regain balance first.')
 elseif kind=='disconnect'then s.connected=false;tick();s.connected=true
 elseif kind=='class'then B.set_class(s,'Archivist')end
 B.stop(s);clock=clock+20;tick();check(s.buffs.pending==p and #sent==1,'commit/refund '..kind)
end
-- Actual native AB is Avoidance Bolstering, not Hunting. Metadata alone grants nothing.
do
 local s,sent,tick=fresh('bolstered');check(not row(s,'bolstered').wanted or not s.buffs.master)
 B.master(s,true);tick();check(sent[1]=='ab avoidance')
 B.set_group_known(s,'avoidance',{'Bolstering'});check(B.availability(s,'bolstered'))
 tick();check(#sent==1,'unknown initial cooldown bypassed')
 clock=701;tick();check(sent[2]=='bolster' and s.buffs.cooldown.bolstered==1301)
 local p=s.buffs.pending;B.text(s,'You must regain balance first.')
 check(s.buffs.pending==p and not p.rejected and not s.buffs.fault and s.buffs.cooldown.bolstered==1301)
 clock=703;B.text(s,bolsterup);check(s.buffs.cooldown.bolstered==1301)
 B.text(s,'You must regain equilibrium first.');check(not p.rejected)
 B.on_prompt(s);tick();check(not s.buffs.pending)
 B.text(s,bolsterdown);clock=1300;tick();check(#sent==2)
 B.sync(s,'List',{});check(s.buffs.cooldown.bolstered==1301,'List extended activation clock')
 clock=1302;tick();check(sent[3]=='bolster')
end
for _,source in ipairs({'owned','observed','canonical','unknown'})do
 local s,sent,tick=fresh('bolstered');B.set_group_known(s,'avoidance',{'Bolstering'});B.master(s,true);clock=701
 if source=='unknown'then s.buffs.defs_known=false
 elseif source=='owned'then B.sync(s,'Add','nimbleness')
 elseif source=='observed'then s.buffs.observed.nimbleness=true
 else s.player.defences.Nimbleness=true end
 check(not B.availability(s,'bolstered'));tick()
 for _,c in ipairs(sent)do check(c=='defences','conflict dispatched '..c)end
 check(not s.buffs.pending,'Nimbleness/unknown bypass')
end
do
 local s,sent,tick=fresh('bolstered');B.set_groups(s,{{name='Avoidance',rank='Transcendent'}})
 check(s.buffs.known.bolstered);B.set_group_known(s,'avoidance',{});B.set_groups(s,{{name='Avoidance',rank='Transcendent'}})
 check(not B.availability(s,'bolstered'),'precise empty List lost authority')
 B.set_group_known(s,'avoidance',{'Bolstering'});B.set_class(s,'Archivist')
 check(not s.buffs.known.bolstered and not B.availability(s,'bolstered'),'class switch retained proof')
 B.set_group_known(s,'avoidance',{'Bolstering'});B.sync(s,'List',{});check(B.availability(s,'bolstered'),'shared Avoidance route lost')
end
print('PASS Book/Bolstering '..n..' assertions: BASH-only new work, persistent tracking/OFF, aliases, debit/ACK/prompt, stale reports, root/transport barriers, Avoidance ownership, Nimbleness absence and 600s cooldown')
