-- OFFLINE ONLY: standalone Lua, synthetic rooms/mount; no live/client inheritance.
local root=(arg[1] or 'combat_v2/'):gsub('/+$','')..'/'
local T=dofile(root..'travel.lua')
local n=0
local function eq(a,b) n=n+1;assert(a==b,'expected '..tostring(b)..' got '..tostring(a)) end
local function fixture()
 local f={clock=0,sent={}}
 f.t=T.new({now=function()return f.clock end,ready=function()return true end,pause=function()return true end,send=function(cmd)f.sent[#f.sent+1]=cmd;if f.on_send then return f.on_send(cmd)end;return true end},{mount_id='99001'})
 f.s=f.t.state;f.t.room('71001');f.t.vitals('99001')
 function f.proof()f.t.text('Distance to Synthetic Shop: 1.');f.t.text('Path: n');f.t.text('Use PATH GO to travel there.')end
 return f
end
local reject='You cannot find a new path so soon.'
for _,speech in ipairs({'Someone says, "'..reject..'"',reject..' '})do
 local f=fixture();f.t.request('pt','71002');f.t.text(speech);f.t.prompt();eq(f.s.pending.kind,'find');eq(f.s.pending.rejected,nil)
end
local f=fixture();f.t.text(reject);eq(f.s.pending,nil);f.t.request('pt','71002')
f.proof();f.t.text(reject);f.t.tick();eq(f.s.pending.kind,'find');eq(f.s.pending.ack,nil);f.t.prompt();eq(f.s.pending,nil);eq(f.s.route_proof,nil)
f.clock=1.99;f.t.tick();eq(#f.sent,1);f.clock=2;f.t.tick();eq(#f.sent,2);eq(f.s.pending.kind,'find');f.t.prompt();eq(#f.sent,2)
f.proof();f.t.prompt();eq(f.sent[3],'path go gallop');local go=f.s.pending;f.t.text(reject);f.t.prompt();eq(f.s.pending,go);eq(f.s.fault,nil)
f=fixture();f.t.request('pt','71002')
for i=1,3 do eq(f.s.pending.kind,'find');f.t.text(reject);f.t.prompt();f.clock=f.clock+2;f.t.tick()end
eq(#f.sent,3);eq(f.s.pending,nil);eq(f.s.intent,nil);eq(f.s.route,nil);eq(f.s.refusal.kind,'find_cooldown');eq(f.s.fault,nil);eq(f.t.unresolved(),false)
for _,outcome in ipairs({'false','throw'})do
 f=fixture();f.on_send=function()f.t.text(reject);f.t.prompt();f.t.tick();if outcome=='throw'then error('synthetic wire')end;return false end
 eq(f.t.request('pt','71002'),false);eq(f.s.pending.kind,'find');assert(f.s.fault);f.clock=99;f.t.tick();eq(#f.sent,1)
end
f=fixture();f.t.request('pt','71001');eq(#f.sent,0);eq(f.s.phase,'idle');eq(f.s.intent,nil)
f=fixture();f.t.request('pt','71002');f.clock=21;f.t.tick();assert(f.s.fault);eq(f.s.pending.kind,'find')
-- Private-plane deferral saves only unsent intent and restores only with newer
-- outside full items/session/owner proof; pending FOLLOW is never cleared.
local tr={follow_due=true,follow_episode=4,item_version=8}
local c={restock_settings={haven_room='71009',globe_haven_return=true},current={room={id=71009}},travel_owner=tr,session_generation=2}
eq(T.haven_deferred(c),true);eq(tr.follow_due,nil);eq(c.haven_handoff.deferred_follow.owner,tr)
c.current.room.id=71008;eq(T.haven_deferred(c),true);tr.presence_room='71008';tr.full_item_version=9;tr.full_item_prompt=0;tr.prompt=0;eq(T.haven_deferred(c),true);tr.prompt=1;eq(T.haven_deferred(c),false);eq(tr.follow_due,true)
c.current.room.id=71009;tr.follow_pending={};local pending=tr.follow_pending;T.haven_deferred(c);eq(tr.follow_pending,pending);eq(tr.follow_due,true)
-- Epoch binding has one owned handle, is idempotent across module reload, and
-- cannot silently succeed without the registration API.
local hook,removed,calls
calls=0;removed=0
local api={registerAnonymousEventHandler=function(name,fn)eq(name,'sysDisconnectionEvent');calls=calls+1;hook=fn;return 701 end,killAnonymousEventHandler=function(id)eq(id,701);removed=removed+1 end}
local native={};eq(T.bind_session(native,{}),false);eq(native.haven_session_token,nil)
eq(T.bind_session(native,api),true);local token=native.haven_session_token
local Reload=dofile(root..'travel.lua');eq(Reload.bind_session(native,api),true);eq(calls,1);eq(native.haven_session_token,token)
hook();assert(native.haven_session_token~=token)
native.travel={state={pending={kind='go'}},unresolved=function()return true end};eq(T.detach(native),false);eq(removed,0)
native.travel={state={},unresolved=function()return false end};eq(T.detach(native),true);eq(removed,1);eq(native.haven_session_token,nil)
print('travel_cooldown: '..n..' assertions passed (offline only)')
