-- Offline fake transport only; genuine-source lines supplied in delegation.
local root=assert(arg[1]);local M=dofile(root..'/buffs.lua');local n=0;local t=100
function getEpoch()return t end
local function check(v,msg)assert(v,msg);n=n+1 end
local function fresh()
 local s={connected=true,mode='OFF',session_id=1,life_generation=1,class_generation=1,player={name='Fixture',class='Monk',hp=100,maxhp=100,mana=100,maxmana=100,balance=true,equilibrium=true,left_arm_balance=true,right_arm_balance=true,defences={},afflictions={}}}
 M.set_class(s,'Monk');local b=M.state(s)
 for _,e in ipairs(M.catalog)do b.wanted[e.key]=e.key=='irongrip' end
 M.race_status(s,'Atavian');M.sync(s,'List',{})
 return s,b
end
local sent={};local function send(c)sent[#sent+1]=c;return true end
local function service(s,hold,policy,runner)return M.service(s,runner or {},send,hold,policy)end
local function frame(s,known)
 for _,l in ipairs({'Irongrip (Racial)                             Known: '..(known or 'Yes'),'---------------------','Syntax: IRONGRIP','        RELAX IRONGRIP','By gripping your weapons tightly, you can prevent others from disarming you of your precious weapons.'})do M.text(s,l)end
 M.on_prompt(s)
end
local function proof(s)
 M.start(s);service(s);check(sent[#sent]=='racial help irongrip','read-only selected discovery');frame(s);check(M.availability(s,'irongrip'),'Known Yes authorizes selected skill')
end
local function issue(s)
 proof(s);service(s);check(sent[#sent]=='IRONGRIP' and s.buffs.pending,'one Buffs pending activation');return s.buffs.pending
end
local function receipt(s)
 M.text(s,'You use Racial Irongrip.');M.text(s,'You concentrate on gripping tightly with your hands so you don’t lose your hold.');M.text(s,'You have gained the irongrip defence.');M.text(s,'Balance Used: 2.79 seconds.');s.player.balance=false;M.vitals(s,{balance=0})
end
local function recover(s)
 s.player.balance=true;M.vitals(s,{balance=1});M.on_prompt(s);service(s)
end
local s,b=fresh();check(b.wanted.irongrip and not b.master,'requested default wanted, startup disarmed');service(s);check(#sent==0,'startup sends nothing')
check(M.toggle(s,'irongrip',true) and not b.master,'selection never arms master');service(s);check(#sent==0,'selection does not send')
-- Unsolicited and malformed help are not permission.
frame(s);check(not M.availability(s,'irongrip'),'unsolicited Known Yes rejected')
M.start(s);service(s);frame(s,'No');check(not M.availability(s,'irongrip'),'Known No denied');service(s);check(not b.pending,'Known No never casts')
s,b=fresh();M.start(s);service(s);M.text(s,'Irongrip (Racial)                             Known: Yes');M.text(s,'Irongrip (Racial)                             Known: Yes');frame(s);check(not M.availability(s,'irongrip'),'same-header duplicate invalid')
s,b=fresh();proof(s);check(not b.master,'one-shot discovery leaves master off');local rows=M.rows(s);local owners=0;for _,r in ipairs(rows)do if r.key=='irongrip'then owners=owners+1;check(r.owner=='SKILL' and not r.tracking_only,'promoted one owner')end end;check(owners==1,'exactly one row')
s.player.name='Other';check(not M.availability(s,'irongrip'),'character switch denies proof');M.race_status(s,'Atavian');check(not M.availability(s,'irongrip'),'fresh new character status cannot renew old proof')
s,b=fresh();proof(s);s.class_generation=2;check(not M.availability(s,'irongrip'),'scope change denies proof')
s,b=fresh();proof(s);M.race_status(s,'Rajamala');check(not M.availability(s,'irongrip'),'race change denies proof')
s,b=fresh();M.start(s);service(s);M.stop(s);frame(s);check(not M.availability(s,'irongrip'),'OFF revokes in-flight capability enrollment')
s,b=fresh();proof(s);M.sync(s,'Add',{name='irongrip'});local before=#sent;service(s);check(#sent==before and not b.pending,'already ACTIVE suppressed')
M.text(s,'Your irongrip defence has been stripped.');check(not b.have.irongrip and not s.player.defences.irongrip,'generic strip tracked');M.master(s,true);service(s);check(b.pending and sent[#sent]=='IRONGRIP','stripped upkeep uses same owner')
local p=b.pending;before=#sent;service(s);check(b.pending==p and #sent==before,'no double owner');M.stop(s);check(b.pending==p,'OFF preserves issued barrier');receipt(s);M.on_prompt(s);service(s);check(b.pending==p,'loss no recovery cannot settle');recover(s);check(not b.pending and not b.master,'real settlement survives OFF without rearming')
s,b=fresh();p=issue(s);M.sync(s,'Add',{name='irongrip'});M.on_prompt(s);service(s);check(b.pending==p,'canonical ACTIVE without own ACK cannot settle');receipt(s);s.player.balance=true;M.vitals(s,{balance=1});service(s);check(b.pending==p,'late raw recovery cannot reuse earlier prompt');M.on_prompt(s);service(s);check(not b.pending,'later prompt settles all witnesses')
s,b=fresh();p=issue(s);M.text(s,'You use Racial Irongrip.');M.text(s,'You have gained the irongrip defence.');M.on_prompt(s);service(s);check(b.pending==p,'ACK+ready flags cannot invent BAL use/loss/recovery')
for _,kind in ipairs({'hold','policy','runner','walker','mental'})do
 s,b=fresh();proof(s);before=#sent
 if kind=='walker'then s.walker={pending={}} elseif kind=='mental'then s.mental={eq_pending={}}end
 service(s,kind=='hold',kind=='policy',kind=='runner' and {waiting=true} or {})
 check(#sent==before and not b.pending,'barrier '..kind)
end
s,b=fresh();proof(s);M.class_router={barrier=function()return true,'Earthcaller primary/rewield pending'end};before=#sent;service(s);check(#sent==before and not b.pending,'shared class/rewield barrier');M.class_router=nil
s,b=fresh();p=issue(s);s.player.dead=true;service(s);check(b.pending==p and not b.master,'death retains commitment');s.player.dead=false;service(s);check(b.pending==p,'revived readiness alone cannot settle')
s,b=fresh();p=issue(s);M.set_class(s,'Archivist');check(b.pending==p and not b.master,'class scope change retains commitment')
-- Same shared producer in all six already-supported class adapters.
local router={barrier=function()return false end}
M.bind_classes(router,{Earthcaller={defense_routes={}},Wayfarer={defense_catalog={}},Infiltrator={defense_catalog={}},Archivist={defenses={}},Shapeshifter={catalog=function()return {} end}}, {},nil)
for _,class in ipairs({'Monk','Wayfarer','Earthcaller','Infiltrator','Archivist','Shapeshifter'})do
 s,b=fresh();s.player.class=class;M.set_class(s,class);M.race_status(s,'Atavian');M.sync(s,'List',{});p=issue(s);check(p.key=='irongrip','shared current-class owner '..class)
end
M.class_router=nil
s,b=fresh();p=issue(s);receipt(s);M.text(s,'Balance Used: 2.79 seconds');recover(s);check(not b.pending,'native measured BAL without punctuation settles')
s,b=fresh();M.start(s);service(s);M.text(s,'Irongrip (Racial)                             Known: Yes');M.on_prompt(s);check(not M.availability(s,'irongrip'),'header alone not capability')
s,b=fresh();proof(s);s.session_id=2;check(not M.availability(s,'irongrip'),'session change denies proof')
s,b=fresh();proof(s);s.life_generation=2;check(not M.availability(s,'irongrip'),'life change denies proof')
s,b=fresh();p=issue(s);M.stop(s);s.player.name='Other';receipt(s);recover(s);check(b.pending==p,'another character cannot settle prior issued owner')
s,b=fresh();p=issue(s);M.set_class(s,'Archivist');s.player.class='Archivist';receipt(s);recover(s);check(not b.pending,'real same-life physical settlement survives class change')
s,b=fresh();p=issue(s);receipt(s);recover(s);M.text(s,'Your irongrip defence has been stripped.');t=t+3;M.master(s,true);service(s);check(sent[#sent]=='racial help irongrip' and not b.pending,'upkeep requires fresh selected Known proof after prior activation')
print('PASS Irongrip '..n..' assertions')
