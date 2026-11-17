local M={}
function M.event(s,text)
 if type(text)~="string" then return s end
 s.last_event=text
 local low=text:lower()
 if low:find("you are prone",1,true) then s.player.prone=true end
 if low:find("you have risen",1,true) or low:find("you kip up",1,true) then s.player.prone=false end
 if low:find("you have been slain",1,true) or low:find("you have died",1,true) then s.player.hp=0;s.player.dead=true;s.stop_reason="player death" end
 if low:find("nothing here by that name",1,true) or low:find("cannot see that here",1,true) or low:find("no such target",1,true) then s.stop_reason="target unavailable" end
 local name=s.target.name and tostring(s.target.name):lower()
 if name and low:find("you have slain "..name,1,true) then s.stop_reason="target slain" end
 return s
end
return M
