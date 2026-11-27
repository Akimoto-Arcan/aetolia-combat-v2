-- Offline pure-module states only. No Mudlet, native ACK fabrication or live sends.
local path=assert(arg[1]);local mode=arg[2]
local M=assert(loadfile(path))()
local clock=100;getEpoch=function() return clock end
local function setup()
 local s={connected=true,player={class='Monk',hp=100,maxhp=100,mana=100,maxmana=100,balance=true,equilibrium=true,left_arm_balance=true,right_arm_balance=true,afflictions={},defences={}}}
 M.set_class(s,'Monk');local b=M.state(s)
 for k in pairs(b.wanted) do b.wanted[k]=false end
 b.wanted.selfishness=true;M.set_group_known(s,'survival',{'selfishness'});M.sync(s,'List',{})
 assert(M.start(s));local sent={}
 local function service() return M.service(s,nil,function(cmd) sent[#sent+1]=cmd;return true end) end
 service();assert(#sent==1 and sent[1]=='selfishness');assert(b.pending and not b.pending.confirmed)
 return s,b,sent,service
end
for _,channel in ipairs({'equilibrium','balance'}) do
 local s,b,sent,service=setup();local pending=b.pending
 M.text(s,'You must regain '..channel..' first.')
 if mode=='baseline' then
  assert(pending.rejected and b.fault and not pending.channel_retry)
  print('BASELINE: '..channel..' rejection faults/disarms and requires reviewed reset')
 else
  assert(pending.rejected and pending.channel_retry and not b.fault and b.sequence)
  -- Cached ready prompt and arbitrarily long elapsed time cannot retry.
  M.on_prompt(s);clock=clock+60;service();assert(#sent==1 and b.pending==pending)
  -- Other channel update cannot release the rejected channel.
  M.vitals(s,{[channel=='balance' and 'equilibrium' or 'balance']=true});M.on_prompt(s);service();assert(#sent==1)
  s.player[channel]=false;M.vitals(s,{[channel]='0'});M.on_prompt(s);service();assert(#sent==1)
  s.player[channel]=true;M.vitals(s,{[channel]='1'});service();assert(#sent==1,'fresh vitals still needs subsequent prompt')
  M.on_prompt(s);service();assert(#sent==2 and sent[2]=='selfishness' and b.pending~=pending and not b.pending.confirmed and not b.fault)
  -- Unknown execution outcome of this second dispatch is never retried.
  clock=clock+60;M.on_prompt(s);service();assert(#sent==2 and b.pending.send_failed~=true and b.fault)
  print('PASS: '..channel..' waits unavailable/cached/timer/other-channel; fresh native ready + prompt retries once; unknown outcome stays fenced')
 end
end
if mode~='baseline' then
 local s,b,sent,service=setup();M.text(s,'You do not possess that ability.');assert(b.fault and b.pending.rejected and not b.pending.channel_retry)
 M.vitals(s,{equilibrium=true,balance=true});M.on_prompt(s);service();assert(#sent==1)
 s,b,sent,service=setup();M.text(s,'You must regain equilibrium first.');M.stop(s,'user stop')
 M.vitals(s,{equilibrium=true});M.on_prompt(s);service();assert(#sent==1 and not b.pending and not b.sequence)
 print('PASS: other errors remain faulted; revoked intent does not resend')
end
