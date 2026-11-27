-- Optional Poker/Farkle convenience. Exact friend commands; never combat actions.
local M={}
local poker={
 ['It is now your turn. Do you wish to check, raise, fold or allin?']='poker check',
 ['It is now your turn. Do you wish to call, raise, fold or allin?']='poker call',
 ['It is now your turn. Do you wish to check, fold, allin or bet?']='poker check',
 ['It is your turn to open. Do you wish to call, raise, fold or allin?']='poker call',
}
function M.new(c,api,playing)
 api=api or {};local o={poker=false,farkle=false,playing=playing==true,last='loaded OFF'}
 function o.stop(reason)
  o.poker=false;o.farkle=false;o.last=reason or 'disabled';return true
 end
 function o.disconnect()
  o.stop('disconnected; enable again deliberately');o.playing=false
 end
 function o.status()
  return 'Poker '..(o.poker and 'ON' or 'OFF')..'; Farkle '..(o.farkle and 'ON' or 'OFF')..'; buy-in 200 gold; seated/buy-in requested '..tostring(o.playing)..'; '..o.last
 end
 function o.command(which,action)
  which=tostring(which or 'games'):lower();action=tostring(action or ''):lower():match('^%s*(.-)%s*$')
  if which~='games'and which~='poker'and which~='farkle'then return false,'cv2 games|poker|farkle on|off|status'end
  if action==''or action=='status'then return true,o.status()end
  if action~='on'and action~='off'then return false,'cv2 '..which..' on|off|status'end
  if which=='games'or which=='poker'then o.poker=action=='on'end
  if which=='games'or which=='farkle'then o.farkle=action=='on'end
  o.last=action=='on'and 'enabled for this session; game replies require combat OFF' or 'disabled; already-sent game actions are not cancelled'
  return true,o.status()
 end
 local function ready()
  local s=c.current or {};local p=s.player or {};local r=c.runner or {};local b=s.buffs or {};local m=s.mental or {};local w=s.walker or {};local t=c.travel_owner or {}
  if s.connected~=true or p.dead or c.mode~='OFF'or s.mode and s.mode~='OFF'then return false end
  if r.waiting or r.dispatching or r.transport_commit or r.transport_barrier or r.transport_unknown or c.transport_unknown then return false end
  if b.pending or b.dispatching or m.pending or m.eq_pending or m.dispatching or w.active or w.pending or w.dispatching or w.arrival_hold then return false end
  if t.pending or t.dispatching or t.phase and t.phase~='idle'then return false end
  if (s.earthcaller or {}).physical or (s.class_observations or {}).issued or (c.emergency_numb or {}).pending then return false end
  return true
 end
 function o.line(text)
  if type(text)~='string'then return false end
  -- Keep table bookkeeping current even while the automation is disabled.
  if text:match('^You take your remaining %d+ gold and leave the poker table%.$')then o.playing=false;return true end
  if not o.poker and not o.farkle then return false end
  if not ready()then o.last='paused: disconnected, combat or another action owner';return false end
  local command,buyin
  if o.poker then
   command=poker[text]
   if not command and not o.playing and text:match('^[%w_]+ takes a seat at the poker table%.$')then command='poker buyin for 200';buyin=true end
  end
  if not command and o.farkle then
   if text=='It is now your turn! Please FARKLE ROLL to continue.'then command='farkle done'
   elseif text:match('^[%w_]+ has initiated a game of Farkle! You can PLAY FARKLE within the next thirty seconds to join%.$')then command='PLAY FARKLE'end
  end
  if not command then return false end
  -- Set before transport, including a possibly unknown/failed buy-in. No retry loop.
  if buyin then o.playing=true end
  local ok,result=pcall(assert(api.send,'minigames sender missing'),command)
  if not ok or result==false then o.stop('game send failed/unknown; review before enabling');return false end
  o.last='sent: '..command;return true,command
 end
 return o
end
return M
