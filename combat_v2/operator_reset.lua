-- Explicit operator-only fresh-cohort PROTOTYPE. No gameplay or native calls at load.
-- Never called by STOP/death/timeout. This archives, it does NOT settle the server.
local M={}
local marker='CV2 OPERATOR RESET v1\nAUTOMATION OFF\nUNSETTLED\n'
local function read(path)
 local f,e,code=io.open(path,'r');if not f then return nil,e,code end
 local s=f:read('*a');f:close();return s
end
local function persist(path,data)
 local f,e=io.open(path..'.new','wb');if not f then return nil,e end
 local ok,why=f:write(data);local closed,err=f:close()
 if not ok or not closed then return nil,why or err end
 if read(path..'.new')~=data then return nil,'temporary readback mismatch' end
 local renamed,reason=os.rename(path..'.new',path);if not renamed then return nil,reason end
 if read(path)~=data then return nil,'published readback mismatch' end
 return true
end
function M.intent(root)
 -- ANY existing intent (even corrupt/incomplete) must default OFF, not rearm.
 local s,_,code=read(root..'operator-reset.intent');return s~=nil or code~=2,s==marker
end
-- Complete bounded reachable application graph, including private Lua upvalues.
-- It is DATA, never executable Lua. Functions/userdata are identities, not rebuilt.
-- _G/_ENV are explicit external boundaries, not fake "complete private snapshots".
function M.snapshot(c)
 if type(c)~='table' or type(c.current)~='table' or type(c.runner)~='table' then return nil,'canonical roots missing' end
 local ids,queue,rows={},{},{}
 local function ref(v)
  local t=type(v)
  if v==_G then return 'EXTERNAL_GLOBAL_ENV' end
  if t=='nil' or t=='boolean' or t=='number' or t=='string' then return t..':'..string.format('%q',tostring(v)) end
  if not ids[v] then
   if #queue>=50000 then error('snapshot graph exceeds bound; no reset authorized') end
   ids[v]=#queue+1;queue[#queue+1]=v
  end
  return t..'#'..ids[v]
 end
 local ok,why=pcall(function()
  rows[1]='CV2 INCIDENT v1\nOUTCOME UNSETTLED\nROOT '..ref(c)
  local i=1
  while i<=#queue do
   local v=queue[i];local t=type(v);rows[#rows+1]='NODE '..i..' '..t
   if t=='table' then
    -- next/raw table traversal: no metamethod execution while taking evidence.
    for k,x in next,v do rows[#rows+1]=ref(k)..' => '..ref(x) end
    local mt=debug.getmetatable(v);if mt then rows[#rows+1]='METATABLE '..ref(mt) end
   elseif t=='function' then
    local info=debug.getinfo(v,'S');rows[#rows+1]='SOURCE '..string.format('%q',info.source or '?')..' '..tostring(info.linedefined)..' '..tostring(info.lastlinedefined)
    for n=1,1000 do
     local name,x=debug.getupvalue(v,n);if not name then break end
     rows[#rows+1]='UPVALUE '..string.format('%q',name)..' '..(name=='_ENV' and 'EXTERNAL_GLOBAL_ENV' or ref(x))
     if n==1000 then error('upvalue bound exceeded') end
    end
    if getfenv then local env=getfenv(v);if env~=_G then rows[#rows+1]='ENV '..ref(env) end end
   else rows[#rows+1]='OPAQUE '..string.format('%q',tostring(v)) end
   i=i+1
  end
 end)
 if not ok then return nil,why end
 return table.concat(rows,'\n')..'\n'
end

local function widgets()
 local b=BaseUI or {};local sections=b.sections or{}
 return {combat=combat_v2_ui and combat_v2_ui.root,base=b.container,map=sections.map,chat=sections.chat,vitals=sections.vitals}
end
function M.save_ui(root)
 local manifest={}
 for name,w in pairs(widgets())do
  if name=='combat' then
   if w then
    local v={};for _,key in ipairs({'x','y','width','height'})do
     -- Persist native raw constraints; absolute child getters are NOT relative geometry.
     local raw=w[key]
     if type(raw)=='string' then
      if #raw>128 or raw:find('[%c]') then return false,'invalid raw combat constraint: '..key end
      v[#v+1]='S:'..raw
     elseif type(raw)=='number' then
      if raw~=raw or math.abs(raw)==math.huge then return false,'invalid combat constraint: '..key end
      v[#v+1]='N:'..string.format('%.17g',raw)
     else
      local fn=w['get_'..key];local ok,n=pcall(function()return type(fn)=='function' and fn(w)end)
      if not ok or type(n)~='number' or n~=n or math.abs(n)==math.huge then return false,'combat geometry unavailable: '..key end
      v[#v+1]='N:'..string.format('%.17g',n)
     end
    end
    manifest[#manifest+1]='combat\t'..table.concat(v,'\t')
   end
  elseif w then
   if type(w.save)~='function' or type(w.load)~='function' then return false,'known Adjustable API unavailable: '..name end
   local ok,result=pcall(w.save,w,'operator-reset',root..'operator-reset-ui/')
   if not ok or result~=true then return false,'Adjustable save failed: '..name end
   if type(w.name)~='string' or not w.name:match('^BaseUI[%w_]*$') or not read(root..'operator-reset-ui/'..w.name..'.lua') then return false,'Adjustable saved geometry readback failed: '..name end
   manifest[#manifest+1]=name
  end
 end
 return persist(root..'operator-reset.ui',table.concat(manifest,'\n')..'\n')
end
function M.restore_ui(root,done)
 local data=read(root..'operator-reset.ui');if not data then return true end
 done=done or{}
 local ws=widgets();local complete=true
 local rows={};for row in data:gmatch('[^\n]+')do rows[#rows+1]=row end
 -- Adjustable parent constraints must be restored before its sections.
 table.sort(rows,function(a,b)if a=='base' then return b~='base' end;if b=='base' then return false end;return a<b end)
 for _,row in ipairs(rows)do
 if not done[row] then
  local x,y,w,h=row:match('^combat\t([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$')
  if x then
   local function constraint(value)
    if value:sub(1,2)=='S:' and #value<=130 and not value:find('[%c]')then return value:sub(3)end
    if value:sub(1,2)=='N:' then local n=tonumber(value:sub(3));if n and n==n and math.abs(n)~=math.huge then return n end end
   end
   x,y,w,h=constraint(x),constraint(y),constraint(w),constraint(h)
   if x==nil or y==nil or w==nil or h==nil then return false end
   local obj=ws.combat
   if obj then obj:move(x,y);obj:resize(w,h);done[row]=true else complete=false end
  elseif row=='base' or row=='map' or row=='chat' or row=='vitals' then
   local obj=ws[row];if obj then
    local ok,result=pcall(obj.load,obj,'operator-reset',root..'operator-reset-ui/');if not ok or result~=true then complete=false else done[row]=true end
   else complete=false end
  end
 end
 end
 return complete
end
function M.attach_reset_lifecycle(c)
 local root=getMudletHomeDir()..'/combat_v2/'
 c.operator_reset_firstaid_sender=function(command)assert(command=='firstaid on','only owned FIRSTAID ON');return send(command)end
 local transfer=false;local seen={};local duty;local restored=false;local dispatching=false;local sent=false;local attempted=false;local ack=false
 local ui_done={};local ui_complete=false
 local function restore_ui_once()if not ui_complete then ui_complete=M.restore_ui(root,ui_done)end end
 local raw=read(root..'operator-reset.firstaid')
 if raw then local name,class,room=raw:match('^OWNED_FIRSTAID_ON_V1\n([^\n]+)\n([^\n]+)\n([^\n]+)\n$');if name then duty={name=name,class=class,room=room}end end
 local function try_restore()
  if not transfer or not duty or restored or attempted or dispatching or not(seen.name and seen.class and seen.room and seen.vitals) then return end
  local s=c.current or{};local p=s.player or{}
  if not s.connected or p.dead or (tonumber(p.hp)or 0)<=0 or p.class~=duty.class or tostring((s.room or{}).id)~=duty.room or (s.policy or{}).self_name~=duty.name then return end
  attempted=true;dispatching=true;local ok,result=pcall(c.operator_reset_firstaid_sender,'firstaid on');dispatching=false
  sent=ok and result~=false;c.operator_firstaid_restore_status=sent and 'owned FIRSTAID ON requested; native ACK pending' or 'owned FIRSTAID ON transport unknown; duty retained'
 end
 local ids={};c.operator_reset_handlers=ids
 local function on(event,fn)ids[#ids+1]=registerAnonymousEventHandler(event,fn)end
 on('sysLoadEvent',function(_,initial)
  transfer=initial==false;seen={}
  if initial==true and duty and not restored then persist(root..'operator-reset.firstaid','INVALIDATED_BY_NEW_PROFILE_SESSION\n');duty=nil end
  if transfer then restore_ui_once();if type(tempTimer)=='function'then tempTimer(0,function()
   restore_ui_once()
   -- Late BaseUI construction/show: preserve existing functions, geometry only.
   if BaseUI then for _,name in ipairs({'build','show'})do
    local original=BaseUI[name];if type(original)=='function' and not BaseUI['operator_reset_wrapped_'..name]then
     BaseUI['operator_reset_wrapped_'..name]=original
     local function after(...)restore_ui_once();return ... end
     BaseUI[name]=function(...)return after(original(...))end
    end
   end end
  end)end end
 end)
 local function connection_changed()transfer=false;seen={};if duty and not restored then persist(root..'operator-reset.firstaid','INVALIDATED_BY_CONNECTION_CHANGE\n');duty=nil end end
 on('sysConnectionEvent',connection_changed)
 on('sysDisconnectionEvent',connection_changed)
 on('sysDataSendRequest',function(_,command)
  if type(command)=='string' then local normalized=command:lower():match('^%s*(.-)%s*$')
   if normalized=='firstaid off' or normalized=='firstaid curing off' then
    local tattoo=c.tattoo_module
    if tattoo and type(tattoo.operator_firstaid_off)=='function' and tattoo.operator_firstaid_off(c)==false then return end
    transfer=false;duty=nil;c.operator_firstaid_restore_status='new explicit FIRSTAID OFF supersedes old restoration duty';persist(root..'operator-reset.firstaid','SUPERSEDED_BY_NEW_FIRSTAID_OFF\n')
   end
  end
 end)
 for event,key in pairs({['gmcp.Char.Name']='name',['gmcp.Char.Status']='class',['gmcp.Room.Info']='room',['gmcp.Char.Vitals']='vitals'})do
  on(event,function()if transfer then seen[key]=true;try_restore()end end)
 end
 on('operator.reset.firstaid.text',function(_,text)
  if sent and not dispatching and text=='You will now begin to utilize first aid.' then ack=true end
 end)
 on('operator.reset.firstaid.prompt',function()
  if sent and ack and transfer and not dispatching then restored=true;persist(root..'operator-reset.firstaid','RESTORED_NATIVE_FIRSTAID_ON\n');c.operator_firstaid_restore_status='native FIRSTAID ON acknowledged; no automation restored' end
 end)
end

function M.request(c,authorization)
 if authorization~='OPERATOR_ABANDON_CLIENT_JOBS_UNSETTLED' then return false,'explicit operator authorization required' end
 if type(resetProfile)~='function' then return false,'native resetProfile unavailable; nothing changed' end
 local root=getMudletHomeDir()..'/combat_v2/'
 local duty,duty_reason
 if c.tattoo_module and type(c.tattoo_module.operator_reset_duty)=='function' then duty,duty_reason=c.tattoo_module.operator_reset_duty(c)end
 local image,why=M.snapshot(c);if not image then return false,why end
 -- Append-only logical history: never overwrite an older incident, even after reset.
 local old,read_error,code=read(root..'operator-reset.history')
 if old==nil and code~=2 then return false,'existing incident history unreadable: '..tostring(read_error) end
 old=old or ''
 local record='BEGIN '..tostring(#image)..'\n'..image..'END UNSETTLED\n'
 local ok,err=persist(root..'operator-reset.history',old..record)
 if not ok then return false,'incident persistence failed: '..tostring(err) end
 if duty then
  for _,key in ipairs({'name','class','room'})do if type(duty[key])~='string' or duty[key]:find('[%c]')then return false,'invalid typed FIRSTAID duty scope' end end
  ok,err=persist(root..'operator-reset.firstaid','OWNED_FIRSTAID_ON_V1\n'..duty.name..'\n'..duty.class..'\n'..duty.room..'\n')
  if not ok then return false,'FIRSTAID duty persistence failed: '..tostring(err)end
 else
  local previous,duty_read_error,duty_read_code=read(root..'operator-reset.firstaid')
  if previous==nil and duty_read_code~=2 then
   return false,'existing FIRSTAID duty unreadable; reset not requested: '..tostring(duty_read_error)
  end
  if previous and previous:match('^OWNED_FIRSTAID_ON_V1\n') then
   ok,err=persist(root..'operator-reset.firstaid','INVALIDATED_NO_CURRENT_OWNED_FIRSTAID_DUTY\n')
   if not ok then return false,'FIRSTAID invalidation persistence failed: '..tostring(err)end
  end
 end
 ok,err=M.save_ui(root);if not ok then return false,err end
 ok,err=persist(root..'operator-reset.intent',marker)
 if not ok then return false,'intent persistence failed; incident retained: '..tostring(err) end
 -- Do not nil owners, mutate private Survival guards, repin, or call mode setters.
 -- Native reset owns destruction. An API return is NOT reset-completion proof.
 local called,result=pcall(resetProfile)
 if not called or result==false then return false,'native reset refused/failed; durable OFF intent retained: '..tostring(result) end
 return true,{reason='fresh Lua cohort reset REQUESTED; server outcomes UNSETTLED; native completion unverified',outcome='UNSETTLED',reset_requested=true,reset_completed=false}
end
return M
