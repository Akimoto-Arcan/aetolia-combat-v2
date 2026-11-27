-- Before/after regression: Safeguard and ordinary Buffs lifecycle unchanged.
local M=dofile(assert(arg[1])..'/buffs.lua');local n=0;local sent={}
function getEpoch()return 100 end
local function check(v,msg)assert(v,msg);n=n+1 end
local function fresh(k)
 local s={connected=true,mode='OFF',player={class='Monk',hp=1000,maxhp=1000,mana=1000,maxmana=1000,balance=true,equilibrium=true,left_arm_balance=true,right_arm_balance=true,defences={},afflictions={}}}
 M.set_class(s,'Monk');local b=M.state(s);for _,e in ipairs(M.catalog)do b.wanted[e.key]=e.key==k end;M.sync(s,'List',{});return s,b
end
local function service(s)M.service(s,{},function(c)sent[#sent+1]=c end,false)end
local s,b=fresh('safeguard');M.race_status(s,'azudim');M.start(s);service(s);check(sent[#sent]=='racial skills','Safeguard original own-race discovery')
for _,l in ipairs({'You possess the following abilities from your race:','  Safeguard','You possess the following racial abilities through other means:','Type RACIAL HELP <skill> to learn more about a specific skill.'})do M.text(s,l)end
check(M.availability(s,'safeguard'),'Safeguard scoped ownership');service(s);check(sent[#sent]=='MIASMA' and b.pending.key=='safeguard','Safeguard literal producer')
local p=b.pending;M.stop(s);check(b.pending==p,'Safeguard OFF retains commitment');M.text(s,'You begin to exude a foul miasma, granting protection upon you and your allies.');service(s);check(b.pending==p,'Safeguard own receipt no prompt keeps barrier');M.on_prompt(s);service(s);check(not b.pending,'Safeguard normal settlement');M.start(s);local before=#sent;service(s);check(#sent==before,'Safeguard ACTIVE no duplicate')
s,b=fresh('toughness');M.set_known(s,{'toughness'});M.start(s);service(s);check(sent[#sent]=='toughness','ordinary skill original owner');p=b.pending;M.stop(s);M.text(s,'You have gained the toughness defence.');service(s);check(b.pending==p,'ordinary skill ACK requires prompt');M.on_prompt(s);service(s);check(not b.pending,'ordinary skill original settlement')
print('PASS unchanged shared regressions '..n..' assertions')
