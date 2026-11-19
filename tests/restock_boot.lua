-- OFFLINE ONLY. Synthetic native root and multicast registry; no live APIs.
local root=(arg[1] or '.'):gsub('/+$','')
-- The common runner passes the installed module directory, not the repo root.
local probe=io.open(root..'/restock.lua','r')
if probe then probe:close();root=root:gsub('/?combat_v2$','');if root==''then root='.'end end
local R=dofile(root..'/combat_v2/restock.lua')
local B=dofile(root..'/combat_v2/restock_boot.lua')
local tests,checks=0,0
local function eq(a,b,m) checks=checks+1;assert(a==b,(m or '')..' expected '..tostring(b)..' got '..tostring(a)) end
local function test(name,fn) local ok,e=pcall(fn);assert(ok,name..': '..tostring(e));tests=tests+1 end
local function fixture()
 local f={modes={},globes={},requests={},sent={},recalls=0,follows=0}
 local items={};local players={};local ih={room_id=73001,responded=true,start_version=1,items=items}
 local c={mode='BASH',runner={mode='BASH'},current={mode='BASH',connected=true,room={id=73001,area=77,items=items,item_version=2},hunting={ih=ih},player={class='Monk',hp=100,maxhp=100,balance=true,equilibrium=true,left_arm_balance=true,right_arm_balance=true,mounted=false,afflictions={}},buffs={master=true,wanted={fixture=true}},policy={players_known=true,players_room=73001,players=players,self_name='Fixture'}},elemental_recovery={armed=false,phase='idle'},travel_owner={serial=0,phase='idle'},defense={plan=function() return {hold=false} end},restock_module=R,supplies_data={stocks={health={count=150,version=1},['ic:anabiotic']={count=960,version=1}},sources={}}}
 c.supplies={state=function() return {stocks=c.supplies_data.stocks} end,audit=function(_,_,only,kind) f.audit={only,kind};return true end}
 local api={clock=function() return 100 end,connected=function() return true end,send=function(cmd) f.sent[#f.sent+1]=cmd;return true end}
 api.combat_v2_set_mode=function(mode) f.modes[#f.modes+1]=mode;c.mode=mode;c.runner.mode=mode;c.current.mode=mode;return true end
 api.combat_v2_globe=function(action) f.globes[#f.globes+1]=action;if action=='on' then c.elemental_recovery.armed=true elseif action=='off' then c.elemental_recovery.armed=false end;return true end
 local serial=0;f.hooks={trigger={},timer={},event={}}
 local function add(k,fn) serial=serial+1;f.hooks[k][serial]=fn;return serial end
 api.tempRegexTrigger=function(_,fn)return add('trigger',fn)end;api.tempPromptTrigger=function(fn)return add('trigger',fn)end;api.tempTimer=function(_,fn)return add('timer',fn)end;api.registerAnonymousEventHandler=function(name,fn)f.events=f.events or {};f.events[name]=fn;return add('event',fn)end
 api.killTrigger=function(id)f.hooks.trigger[id]=nil end;api.killTimer=function(id)f.hooks.timer[id]=nil end;api.killAnonymousEventHandler=function(id)f.hooks.event[id]=nil end
 c.travel={io={pause=function()return api.combat_v2_set_mode('OFF')end,recall_ready=function()return true end,send_recall=function()f.recalls=f.recalls+1;return true end,send_follow=function()f.follows=f.follows+1;return true end}}
 c.travel.request=function(action,destination)
  f.requests[#f.requests+1]={action,destination}
  if action=='pt' then
   local tr=c.travel_owner;tr.serial=tr.serial+1;tr.intent='pt';tr.destination=tostring(destination);tr.route='finding';tr.phase='find'
   if not c.travel.io.pause() then return false end
  end
  if f.on_request then f.on_request(action,destination) end
  return true
 end
 c.convenience={hold=function()return false end};c.restock_api=api;f.c=c;f.api=api
 assert(B.attach(c));f.d=c.restock_data;f.t=c.restock_controller
 function f.lease(phase)
  local d=f.d;d.active=true;d.enabled=true;d.busy=true;d.reserved=true;d.resume_consent=true;d.phase=phase;d.return_room=73001;d.return_area=77;c.user_activity=d
  return d
 end
 return f
end

test('attach installs public API disabled without sends or cached parse',function()
 local f=fixture();eq(f.d.enabled,false);eq(f.d.active,false);eq(#f.modes,0);eq(#f.globes,0);eq(#f.requests,0);eq(#f.sent,0);eq(type(f.api.combat_v2_restock),'function');local ok,status=f.api.combat_v2_restock('status');eq(ok,true);assert(status:find('Restock OFF',1,true));eq(B.attach(f.c),true);eq(#f.modes,0)
end)
test('public ON/OFF changes only restock permission while OFF',function()
 local f=fixture();f.api.combat_v2_set_mode('OFF');local n=#f.modes;eq(f.api.combat_v2_restock('on'),true);eq(f.d.enabled,true);f.t.tick();eq(f.c.mode,'OFF');eq(#f.requests,0);eq(#f.modes,n);eq(f.api.combat_v2_restock('off'),true);eq(f.d.enabled,false);eq(f.c.mode,'OFF')
end)
test('real adapter trip pause passes guards and uses exact native PT',function()
 local f=fixture();eq(f.api.combat_v2_restock('on'),true);f.t.tick();eq(f.c.mode,'OFF');eq(f.d.fault,nil);eq(f.d.return_room,73001);eq(f.d.return_area,77);eq(f.c.user_activity,f.d);eq(f.d.pending.kind,'route');eq(f.requests[1][1],'pt');eq(f.requests[1][2],'12669');eq(R.movement_borrowed(f.c),true);eq(f.d.route_serial,f.c.travel_owner.serial)
end)
test('reservation does not globally hold offense before fight ends',function()
 local f=fixture();f.c.current.room.items.enemy={attrib='m',name='Synthetic foe'};assert(f.api.combat_v2_restock('on'));f.t.tick();eq(R.movement_reserved(f.c),true);eq(B.hold(f.c),false);eq(f.d.busy,false);eq(#f.requests,0);eq(f.c.mode,'BASH')
end)
test('public GLOBE OFF does not cancel low reservation or enabled flag',function()
 local f=fixture();f.c.current.room.items.enemy={attrib='m',name='Synthetic foe'};f.c.elemental_recovery.armed=true;assert(f.api.combat_v2_restock('on'));f.t.tick();eq(f.d.resume_globe,true);eq(f.api.combat_v2_globe('off'),true);eq(f.d.enabled,true);eq(f.d.active,true);eq(f.d.resume_globe,false);eq(f.d.fault,nil)
end)
test('Globe ON blocked during reservation, not merely BUSY',function()
 local f=fixture();f.c.current.room.items.enemy={attrib='m',name='Synthetic foe'};assert(f.api.combat_v2_restock('on'));f.t.tick();eq(f.api.combat_v2_globe('on'),false);eq(#f.globes,0);eq(f.d.enabled,true)
end)
test('public GLOBE OFF during trip never calls operator restock stop',function()
 local f=fixture();local d=f.lease('wares');d.resume_globe=true;eq(f.api.combat_v2_globe('off'),true);eq(d.active,true);eq(d.enabled,true);eq(d.resume_globe,false);eq(d.fault,nil);eq(B.hold(f.c),true)
end)
test('public mode ON cannot bypass retained transaction',function()
 for _,mode in ipairs({'BASH','FULL_AUTO','ASSIST','SHADOW'})do local f=fixture();local d=f.lease('buy');d.purchase={};d.pending={kind='buy'};eq(f.api.combat_v2_set_mode(mode),false);eq(#f.modes,0);eq(d.resume_consent,false);assert(d.purchase);assert(d.pending) end
end)
test('explicit mode OFF even already OFF revokes resume and preserves barrier',function()
 local f=fixture();local d=f.lease('buy');f.c.mode='OFF';d.pending={kind='buy'};d.purchase={};local p=d.pending;eq(f.api.combat_v2_set_mode('OFF'),true);eq(d.resume_consent,false);eq(d.pending,p);assert(d.purchase);eq(f.c.restock_intent_epoch,1);eq(d.enabled,true)
end)
test('owned pause and resume mode dispatch do not revoke consent',function()
 local f=fixture();local d=f.lease('pausing');d.dispatching=true;eq(f.api.combat_v2_set_mode('OFF'),true);eq(d.resume_consent,true);eq(f.c.restock_intent_epoch,nil);d.phase='resume';eq(f.api.combat_v2_set_mode('BASH'),true);eq(d.resume_consent,true);eq(f.c.restock_intent_epoch,nil);d.dispatching=false
end)
test('mode owned scope requires exact root owner and no fault',function()
 local f=fixture();local d=f.lease('resume');d.dispatching=true;f.c.user_activity={};eq(f.api.combat_v2_set_mode('BASH'),false);eq(d.resume_consent,false)
end)
test('owned rearm only saved still desired Globe intent',function()
 local f=fixture();local d=f.lease('resume');d.dispatching=true;d.resume_globe=false;eq(f.api.combat_v2_globe('on'),false);d.resume_globe=true;eq(f.api.combat_v2_globe('on'),true);eq(#f.globes,1);d.dispatching=false;eq(f.api.combat_v2_globe('on'),false);eq(#f.globes,1)
end)
test('external PT QM QD RH INK blocked while owned exact PT allowed',function()
 local f=fixture();local d=f.lease('route');d.destination='12669';d.pending={kind='route'}
 for _,action in ipairs({'pt','qm','qd','rh','ink'}) do eq(f.c.travel.request(action,'99999'),false) end;eq(#f.requests,0)
 d.dispatching=true;eq(f.c.travel.request('pt','99999'),false);eq(f.c.travel.request('qm','12669'),false);eq(f.c.travel.request('pt','12669'),true);eq(#f.requests,1);eq(d.resume_consent,true)
end)
test('async native PT pause allowed only exact borrowed owner',function()
 local f=fixture();assert(f.api.combat_v2_restock('on'));f.t.tick();eq(R.movement_borrowed(f.c),true);eq(f.c.travel.io.pause(),true);eq(f.d.resume_consent,true);eq(f.c.restock_intent_epoch,nil);f.c.travel_owner.destination='99999';eq(f.c.travel.io.pause(),false);eq(f.d.resume_consent,true)
end)
test('recall blocked shopping but allowed during genuine return preparation',function()
 local f=fixture();local d=f.lease('wares');eq(f.c.travel.io.recall_ready(),false);eq(f.c.travel.io.send_recall(),false);eq(f.recalls,0);eq(f.c.travel.io.send_follow(),true);eq(f.follows,1);eq(f.c.convenience.hold(f.c),true);d.phase='resume';eq(f.c.travel.io.recall_ready(),true);eq(f.c.travel.io.send_recall(),true);eq(f.recalls,1);eq(f.c.convenience.hold(f.c),false);d.fault='unknown';eq(f.c.convenience.hold(f.c),true)
end)
test('enabled OFF graceful trip still holds all transaction guards',function()
 local f=fixture();local d=f.lease('wares');eq(f.api.combat_v2_restock('off'),true);eq(d.active,true);eq(d.enabled,false);eq(B.busy(f.c),true);eq(B.hold(f.c),true);eq(f.c.travel.request('pt','99999'),false);eq(f.api.combat_v2_globe('on'),false);local ok,status=f.api.combat_v2_restock('status');eq(ok,true);assert(status:find('Restock OFF',1,true));assert(status:find('busy=true',1,true))
end)
test('bind idempotent retains wrappers and resource identities',function()
 local f=fixture();local mode=f.api.combat_v2_set_mode;local globe=f.api.combat_v2_globe;local request=f.c.travel.request;local owner=f.c.restock_data;local runner=f.c.runner;eq(B.attach(f.c),true);eq(f.api.combat_v2_set_mode,mode);eq(f.api.combat_v2_globe,globe);eq(f.c.travel.request,request);eq(f.c.restock_data,owner);eq(f.c.runner,runner);eq(#f.sent,0)
end)
test('mode and Globe status readback never grants actions',function()
 local f=fixture();local d=f.lease('buy');d.purchase={};d.pending={kind='buy'};eq(f.api.combat_v2_globe('status'),true);local ok=f.api.combat_v2_restock('status');eq(ok,true);eq(#f.modes,0);eq(#f.requests,0);eq(#f.sent,0);eq(f.api.combat_v2_restock('bogus'),false)
end)
test('native FirstAid and wanted defenses are not modified by attachment or toggles',function()
 local f=fixture();local wanted=f.c.current.buffs.wanted;f.c.firstaid={enabled=true};eq(f.api.combat_v2_restock('on'),true);eq(f.api.combat_v2_restock('off'),true);eq(f.c.firstaid.enabled,true);eq(f.c.current.buffs.wanted,wanted);eq(f.c.current.buffs.master,true)
end)

test('owned Room.Info hook accepts shopping duplicate and rejects unexpected travel',function()
 local f=fixture();local d=f.lease('wares');d.candidate={room='12668'};d.stage_area=88;f.c.mode='OFF';f.c.current.room.id=12668;f.c.current.room.area=88;f.events['gmcp.Room.Info']();eq(d.fault,nil);f.c.current.room.id=99999;f.events['gmcp.Room.Info']();eq(d.active,false);eq(d.resume_consent,false)
end)
test('synchronous native route ACK is recognized before request returns',function()
 local f=fixture();f.on_request=function(action,dest)
  eq(action,'pt');eq(R.movement_borrowed(f.c),true);f.c.current.room.id=tonumber(dest);f.c.current.room.area=88;f.c.travel_owner.intent=nil;f.c.travel_owner.route=nil;f.c.travel_owner.phase='idle';eq(R.movement_borrowed(f.c),true);f.events['gmcp.Room.Info']();f.t.prompt();eq(#f.sent,0)
 end
 assert(f.api.combat_v2_restock('on'));f.t.tick();eq(f.d.fault,nil);eq(f.d.pending.kind,'route');eq(#f.requests,1);eq(#f.sent,0);f.t.tick();eq(f.d.pending.kind,'directory');eq(#f.sent,1)
end)
test('XP cutoff observer and handlers remain untouched through restock rebinding',function()
 local f=fixture();local observer={enabled=true,triggered=true,handles={91,92},module={}};f.c.xp_globe_cutoff=observer;eq(B.bind(f.c),true);eq(f.c.xp_globe_cutoff,observer);eq(observer.handles[1],91);eq(observer.handles[2],92);local d=f.lease('resume');d.resume_globe=true;d.dispatching=true;eq(R.adapter(f.c,f.api).arm_globe(),false);eq(#f.globes,0);eq(d.enabled,true)
end)


test('native checkpoint capture can inspect readiness without inheriting its own hold',function()
 local f=fixture();local cp
 f.c.current.walker={active=true}
 f.c.walker_boot={restock_ready=function()return true end,restock_suspend=function(c,d)
  eq(R.busy(c),true);eq(B.busy(c),false);eq(B.hold(c),false);eq(c.convenience.hold(c),false);eq(R.owns_transition(c),false);eq(c.travel.request('pt','99999'),false)
  cp={lease=d,room=tostring(c.current.room.id),area=c.current.room.area};d.checkpoint=cp;return cp
 end}
 assert(f.api.combat_v2_restock('on'));f.t.tick();eq(f.d.fault,nil);eq(f.d.checkpoint,cp);eq(f.d.capturing_checkpoint,nil);eq(f.d.pending.kind,'route');eq(#f.requests,1)
end)
test('trusted checkpoint resume passes upstream busy guard but public actions remain fenced',function()
 local f=fixture();local d=f.lease('resume');d.dispatching=true;eq(B.busy(f.c),false);eq(R.busy(f.c),true);eq(B.hold(f.c),false);eq(f.c.travel.request('pt','99999'),false);d.dispatching=false;eq(B.busy(f.c),true)
end)
test('deferred recall can settle only at exact owned return gap, never while shopping',function()
 local f=fixture();local d=f.lease('route');d.after_route='return_check';d.pending={kind='route'};f.c.travel_owner.recall_due=true
 eq(B.hold(f.c),false);eq(f.c.travel.io.recall_ready(),true);eq(f.c.travel.io.send_recall(),true);eq(f.recalls,1);eq(R.movement_reserved(f.c),true);eq(f.c.travel.request('pt','99999'),false)
 f.c.current.room.area=999;eq(B.hold(f.c),true);eq(f.c.travel.io.send_recall(),false);f.c.current.room.area=77;d.after_route='wares';eq(B.hold(f.c),true);eq(f.c.travel.io.send_recall(),false)
end)

print('restock_boot: '..tests..' tests, '..checks..' assertions passed (offline native fakes only)')
