local root=arg[1] or '.'
local M=dofile(root..'/ManualBasher.lua')
local count=0
local function check(x,label) assert(x,label); count=count+1 end
local db={woods={label='Woods',areas={Woods=true},mobs={rat=true,wolf=true,['mountain crocodile']=true,['a roc']=true,['a guard']=true,['a horse']=true}}}
local function fresh()
 local clock=100; local sent,requests,notes={},{},{}; local conflict=false
 local b=M.new({now=function()return clock end,send=function(c)sent[#sent+1]=c end,gmcp=function(c)requests[#requests+1]=c end,notice=function(c)notes[#notes+1]=c end,conflict=function()return conflict end},db)
 local function vit(over)
  local v={hp='100',maxhp='100',bal='1',eq='1',left_arm='1',right_arm='1',prone='0',wield_left='crozier123',wield_right='empty',charstats={'Class: Earthcaller'}}
  for k,x in pairs(over or {}) do v[k]=x end; b.vitals(v)
 end
 local function list(items) b.list({location='room',items=items or {{id='11',name='rat',attrib='m'},{id='12',name='wolf',attrib='m'}}}) end
 b.status({name='Tester',class='Earthcaller'}); b.room({num=1,area='Woods'}); b.afflictions({}); vit(); b.ironKnown(true); b.iron(true); list()
 return b,sent,requests,vit,list,function(t)clock=clock+(t or 1)end,function(v)conflict=v end,notes
end
local function cycle(b,v,advance) v({bal='0'}); advance(); v(); b.prompt() end
local b,s,r,v,l,t,c,n=fresh()
check(not b.state.enabled and #s==0,'default OFF')
b.prompt();check(#s==0,'OFF prompt inert');check(b.on(),'ON valid');b.prompt();check(s[1]=='quash 11','first numeric NPC')
for i=1,30 do b.prompt() end;check(#s==1,'duplicate prompt no sends')
v();t();b.prompt();check(#s==1,'stale ready does not ack')
cycle(b,v,t);check(s[2]=='quash 11','second same mob')
cycle(b,v,t);check(s[3]=='quash 11','third same mob')
b.item('remove',{location='room',item={id='11'}});cycle(b,v,t);check(s[4]=='quash 12','kill then next')
b.off();cycle(b,v,t);check(#s==4,'OFF settles no send');check(b.state.pending==nil,'pending settled while OFF')
b,s,r,v,l,t=fresh();b.on();b.prompt();b.off();b.on();t();v();b.prompt();check(#s==1,'OFF ON cannot bypass BAL')
b,s,r,v,l,t=fresh();b.on();b.room({num=2,area='Woods'});b.prompt();check(#s==0,'move invalidates target');l({{id='88',name='wolf',attrib='m'}});b.prompt();check(s[1]=='quash 88','new room fresh response')
b,s,r,v,l,t=fresh();b.on();b.room({num=2,area='Woods'});b.room({num=3,area='Woods'});local nr=#r;l();check(b.state.snapshot==nil and #r==nr+1,'inflight old response drained');b.prompt();check(#s==0,'old snapshot cannot attack');l({{id='99',name='rat',attrib='m'}});b.prompt();check(s[1]=='quash 99','postdrain current list')
for _,attrs in ipairs({'p','mp','ml','mv','mc','md','mR',''}) do b,s,r,v,l,t=fresh();b.refresh();l({{id='42',name='rat',attrib=attrs}});b.on();b.prompt();check(#s==1 and s[1]=='look','reject attrs '..attrs) end
for _,name in ipairs({'a roc','a guard','a horse'}) do b,s,r,v,l,t=fresh();b.refresh();l({{id='42',name=name,attrib='m'}});b.on();b.prompt();check(#s==1,'protect '..name) end
b,s,r,v,l,t=fresh();b.refresh();l({{id='42',name='mountain crocodile',attrib='m'}});b.on();b.prompt();check(s[2]=='quash 42','no mount/roc substring bug')
for _,item in ipairs({{id='rat42',name='rat',attrib='m'},{id='42',name='rat',attrib='m',icon='player'},{id='42',name='rat',attrib='m',loyal=true},{id='42',name='rat',attrib='m',protected=true}}) do b,s,r,v,l,t=fresh();b.refresh();l({item});b.on();b.prompt();check(#s==1,'reject malformed/protected item') end
b,s,r,v,l,t=fresh();v({hp='20'});b.on();b.prompt();check(s[1]=='quash 11','exact20 allowed');v({hp='19'});check(not b.state.enabled,'below20 OFF')
b,s,r,v,l,t=fresh();b.on();v({charstats={'Class: Monk'}});b.prompt();check(not b.state.enabled and #s==0,'charstats mismatch OFF')
b,s,r,v,l,t=fresh();b.on();b.status({class='Monk'});check(not b.state.enabled,'status class change OFF')
b,s,r,v,l,t=fresh();b.on();v({wield_left='empty'});b.prompt();check(#s==0,'unwield hold')
b,s,r,v,l,t=fresh();b.on();v({prone='1'});b.prompt();check(#s==0,'prone hold')
b,s,r,v,l,t=fresh();b.on();v({left_arm='0'});b.prompt();check(#s==0,'arm hold')
b,s,r,v,l,t=fresh();b.on();b.afflictions({crippled_left_arm=true});b.prompt();check(#s==0,'crippled hold')
b,s,r,v,l,t=fresh();b.on();t(4);b.prompt();check(#s==0,'stale vitals hold')
b,s,r,v,l,t=fresh();b.on();b.prompt();t(11);b.timeout();check(not b.state.enabled and b.state.pending,'no ACK timeout OFF retains pending')
b,s,r,v,l,t=fresh();b.on();b.prompt();v({bal='0'});t(11);b.timeout();check(not b.state.enabled,'no recovery timeout OFF')
b,s,r,v,l,t,c=fresh();c(true);check(not b.on(),'competing offense refuses ON')
b,s,r,v,l,t=fresh();b.on();check(not b.configure('command','attack {target}'),'ON config rejected');b.off();for _,cmd in ipairs({'quash {target};look','quash {target}|look','quash {target}\nlook','quash {target} {target}','quash','quash {target} {oops}'}) do check(not b.configure('command',cmd),'bad template') end;check(b.configure('command','quash {target}'),'valid template');check(b.configure('area','woods'),'explicit scope');check(not b.configure('area','all'),'no union scope')
b,s,r,v,l,t=fresh();b.room({num=2,area='Unknown'});check(not b.on(),'unknown area blocks');check(b.configure('area','woods') and b.on(),'explicit manual scope')
b,s,r,v,l,t=fresh();b.on();b.disconnect();check(not b.state.enabled and not b.state.snapshot and b.state.ironKnown==nil,'disconnect clears knowledge OFF')
b,s,r,v,l,t=fresh();b.state.ironActive=false;b.on();b.prompt();check(s[1]=='irongrip','upkeep first');b.prompt();check(#s==1,'upkeep single flight');v({bal='0'});t();v();b.prompt();check(#s==1,'upkeep requires own ACK');b.iron(true);v();b.prompt();check(s[2]=='quash 11','upkeep ACK BAL recovery later prompt');b.iron(false);cycle(b,v,t);check(s[3]=='irongrip','strip schedules upkeep after attack settlement')
b,s,r,v,l,t=fresh();b.state.ironKnown=nil;b.on();check(s[1]=='racial help irongrip','one setup help');b.prompt();check(#s==1,'no unknown racial use');b.ironKnown(false);check(not b.state.enabled,'Known No OFF')
b,s,r,v,l,t=fresh();b.configure('irongrip','off');b.on();b.state.ironActive=false;b.prompt();check(s[1]=='quash 11','irongrip off no relax or use')
b,s,r,v,l,t=fresh();b.state.ironActive=false;b.on();b.prompt();t(11);b.timeout();check(not b.state.enabled,'upkeep timeout OFF')
b,s,r,v,l,t=fresh();b.on();b.item('update',{location='room',item={id='11',attrib='mp'}});b.prompt();check(s[1]=='quash 12','target protection update selects next')
b,s,r,v,l,t=fresh();b.cleanup();check(b.state.destroyed and not b.state.enabled,'cleanup OFF')
b,s,r,v,l,t=fresh();b.refresh();l({{id='42',name='rat',attrib='m',icon='face-angry-horns'}});b.on();b.prompt();check(s[2]=='quash 42','actual Aetolia hostile NPC icon')
b,s,r,v,l,t=fresh();b.refresh();l({{id='42',name='Rat',attrib='m',icon='face-angry-horns'}});b.on();b.prompt();check(s[2]=='quash 42','native name capitalization matches catalog')
b,s,r,v,l,t=fresh();v({wield_left='empty',wield_right='shield987'});b.on();b.prompt();check(#s==0,'shield alone is not a Quash weapon')
print('PASS '..count..' core assertions ('.._VERSION..')')
