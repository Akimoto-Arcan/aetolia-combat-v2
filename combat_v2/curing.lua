-- Delegate curing to Aetolia FIRSTAID, not guessed cross-game herb mappings.
local M={}
function M.new() return {enabled=false,status="not requested"} end
function M.set(c,s,on)
 if not s.connected or (tonumber(s.player.hp) or 0)<=0 then c.status="not logged in";return false,c.status end
 send(on and "firstaid on" or "firstaid off")
 if on then send("firstaid curing on") end
 c.enabled=on;c.status="requested; verify server response";return true
end
function M.choose(s,c) return {command="",reason=c.enabled and "server FIRSTAID" or "FIRSTAID not requested"} end
function M.observe()end
return M
