-- Read-only reserve monitor. No native curing, runner or mode ownership.
-- Stock means CACHE RESERVE, never usable carried vials/bandages.
local M = {}
local ELIXIRS = '==============================[     Elixirs     ]=============================='
local POULTICES = '==============================[    Poultices    ]=============================='
local groups = {
  elixirs = {['an elixir of health']='health', ['an elixir of mana']='mana',
    ['an elixir of speed']='speed', ['an elixir of vigor']='vigor',
    ['an elixir of levitation']='levitation', ['an elixir of harmony']='harmony',
    ['an elixir of the arcane']='arcane', ['an elixir of immunity']='immunity'},
  poultices = {['a mass poultice']='mass', ['a caloric poultice']='caloric',
    ['an epidermal poultice']='epidermal', ['a mending poultice']='mending',
    ['a restoration poultice']='restoration'}
}
local keys = {'health','mana','speed','vigor','levitation','harmony','arcane','immunity',
  'mass','caloric','epidermal','mending','restoration'}
local function now(c)
  return c.supplies_clock and c.supplies_clock() or os.time()
end
local function data(c)
  if not c.supplies_data then
    c.supplies_data = {stocks={}, requested=false, stale=true, status='not audited'}
  end
  return c.supplies_data
end
local function connected(c)
  if c.supplies_connected then return c.supplies_connected() == true end
  if type(getConnectionInfo) ~= 'function' then return false end
  local ok, _, _, online = pcall(getConnectionInfo)
  return ok and online == true
end
local function bash(c)
  if c.supplies_is_bash then return c.supplies_is_bash() == true end
  if c.current then return c.current.mode == 'BASH' end
  if c.mode ~= nil then return c.mode == 'BASH' end
  return c.state and c.state.mode == 'BASH'
end
local function expire(c)
  local d = data(c)
  if d.frame and now(c) - d.frame.at >= 10 then
    d.frame = nil; d.pending = false; d.stale = true; d.status = 'response timeout'
  elseif d.pending and now(c) - d.sent_at >= 10 then
    d.pending = false; d.stale = true; d.status = 'response timeout'
  end
  if not connected(c) then d.stale = true end
  if d.last_complete and now(c) - d.last_complete > 90 then d.stale = true end
end
-- Explicit trusted event API; caller must provide its verified evidence source.
-- Future herb/pipe adapters may use namespaced keys. No broad chat/error guessing.
function M.stock(c, key, n, source)
  if type(key) ~= 'string' or not key:match('^[%w_:.%-]+$') or #key > 60 or
    type(n) ~= 'number' or n < 0 or n ~= math.floor(n) or n == math.huge or
    type(source) ~= 'string' or source == '' then return false end
  local d = data(c)
  d.version = (d.version or 0) + 1
  d.stocks[key] = {count=n, source=source, at=now(c), version=d.version}
  M.render(c)
  return true
end
function M.state(c)
  expire(c)
  local d = data(c)
  local s = {stocks={}, empty={}, low={}, unknown={}, stale=d.stale,
    status=d.status, pending=d.pending == true, requested=d.requested}
  for k,v in pairs(d.stocks) do
    s.stocks[k] = {count=v.count, source=v.source, at=v.at}
    if v.count == 0 then s.empty[#s.empty+1] = k
    elseif v.count <= (c.supplies_low or 100) then s.low[#s.low+1] = k end
  end
  for _,k in ipairs(keys) do if not d.stocks[k] then s.unknown[#s.unknown+1]=k end end
  table.sort(s.empty); table.sort(s.low)
  s.level = #s.empty > 0 and 'critical' or
    ((#s.low > 0 or #s.unknown > 0 or s.stale) and 'warning' or 'ok')
  return s
end
local function escape(s)
  return (s:gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'))
end
-- Session-local position survives refresh and module reload; never owns combat.
function M.drag(c, phase, event)
 local ui=c.supplies_ui
 if not ui or type(event)~='table' then return false end
 if phase=='release' then ui.drag=nil;return true end
 local gx,gy=tonumber(event.globalX),tonumber(event.globalY)
 if not gx or not gy then return false end
 if phase=='press' then
  if event.button~='LeftButton' and event.button~='Left' then return false end
  ui.drag={gx=gx,gy=gy,x=ui.x,y=ui.y};return true
 end
 if phase~='move' or not ui.drag then return false end
 if type(event.buttons)=='table' then
  local held=false
  for key,value in pairs(event.buttons)do
   if value=='LeftButton' or value=='Left' or ((key=='LeftButton' or key=='Left')and value==true)then held=true end
  end
  if not held then ui.drag=nil;return false end
 end
 local d=ui.drag;c.supplies_position={x=d.x+gx-d.gx,y=d.y+gy-d.gy}
 M.render(c);return true
end
function M.render(c)
  local s = M.state(c)
  local title = 'FLUIDCACHE RESERVES'
  if #s.empty > 0 then title = 'EMPTY CACHE: '..table.concat(s.empty, ', ')
  elseif #s.low > 0 then title = 'LOW CACHE: '..table.concat(s.low, ', ')
  elseif s.level ~= 'ok' then title = 'FLUIDCACHE: UNKNOWN / STALE'
  else title = 'Fluidcache: audited reserves above low threshold' end
  local note = 'Carried supplies unverified; herbs / pipes not audited.'
  if #s.empty > 0 then note = 'Reserve empty; carried vials/bandages may remain. '..note end
  if #s.low > 0 and #s.empty > 0 then note = 'LOW: '..table.concat(s.low, ', ')..'. '..note end
  if s.stale or #s.unknown > 0 then note = note..' Incomplete/stale evidence ('..s.status..').' end
  s.title=title; s.note=note
  if not c.supplies_ui and Geyser and Geyser.Label then
    c.supplies_ui = {label=Geyser.Label:new({name='combat_v2_supplies_alarm', x=350,y=10,width=600,height=48})}
  end
  local ui = c.supplies_ui
  if ui and ui.label then
    local w,h = 1920,978
    if type(getMainWindowSize)=='function' then w,h=getMainWindowSize() end
    local width = math.max(1, math.min(600, w-20))
    local height = s.level=='critical' and 106 or (s.level=='warning' and 76 or 48)
    if s.level=='critical' then
      local titleRows=math.ceil(#title/math.max(1,math.floor((width-12)/11)))
      local noteRows=math.ceil(#note/math.max(1,math.floor((width-12)/7)))
      height=math.max(height,titleRows*24+noteRows*17+12)
    end
    local position=c.supplies_position
    local x=math.max(0,math.min(position and position.x or 350,math.max(0,w-width-10)))
    local y=math.max(0,math.min(position and position.y or 10,math.max(0,h-height)))
    local label = ui.label
    if not ui.drag_bound and type(label.setClickCallback)=='function' and type(label.setMoveCallback)=='function' and type(label.setReleaseCallback)=='function' then
      label:setClickCallback(function(event)M.drag(c,'press',event)end)
      label:setMoveCallback(function(event)M.drag(c,'move',event)end)
      label:setReleaseCallback(function(event)M.drag(c,'release',event)end)
      ui.drag_bound=true
    end
    label:move(x,y)
    label:resize(width, math.min(height,h))
    local color = s.level=='critical' and '#a40000' or (s.level=='warning' and '#5e4100' or '#172832')
    if type(label.setStyleSheet)=='function' then
      label:setStyleSheet('background-color:'..color..'; color:white; border:2px solid '..
        (s.level=='critical' and '#ff5555' or '#e2ad45')..'; qproperty-alignment: AlignTop;')
    elseif type(label.setColor)=='function' then label:setColor(color) end
    label:echo('<div style="color:white; padding:4px"><b style="font-size:'..
      (s.level=='critical' and '20' or '13')..'px">'..escape(title)..'</b><br>'..escape(note)..'</div>')
    ui.level=s.level; ui.x=x; ui.y=y; ui.width=width; ui.height=math.min(height,h)
  end
  return s
end
function M.text(c, line)
  if type(line) ~= 'string' then return end
  expire(c)
  local d = data(c)
  -- Exact native headers, never substrings of speech/chat.
  if line == ELIXIRS then
    d.frame = {at=now(c), section='elixirs', rows={}, version=d.version or 0}
    return
  end
  local f = d.frame
  if not f then return end
  if line == POULTICES then
    if f.section ~= 'elixirs' then f.bad=true end
    f.section='poultices'; f.poultices=true; return
  end
  if line:match('^%s*$') then return end
  -- Other combat lines may interleave. Only a full anchored count-row is parsed.
  if not line:match('^%s*%[') then return end
  -- Native FIRSTAID diagnostics may interleave with the response, but are not rows.
  if not line:match('^%s*%[%s*[%d%?%-]') and
    not line:match('^%s*%[[^%]]*%]%s+an? ') then return end
  local rest, found = line, false
  while rest:match('^%s*%[') do
    local n, body = rest:match('^%s*%[%s*(%d+)%]%s+(.+)$')
    if not n then f.bad=true; return end
    local boundary=body:find('[',1,true)
    local name=boundary and body:sub(1,boundary-1) or body
    local tail=boundary and body:sub(boundary) or ''
    name = name:match('^(.-)%s*$')
    local key = groups[f.section][name]
    n=tonumber(n)
    if not key or not n or n == math.huge or f.rows[key] ~= nil then f.bad=true; return end
    f.rows[key]=n; found=true; rest=tail
  end
  if not found or not rest:match('^%s*$') then f.bad=true end
end
function M.prompt(c)
  expire(c)
  local d = data(c)
  local f = d.frame
  if not f then return end
  d.frame=nil; d.pending=false
  if f.bad then d.stale=true; d.status='malformed response'; M.render(c); return end
  local count=0
  for k,n in pairs(f.rows) do
    count=count+1
    local prior=d.stocks[k]
    -- A newer trusted adapter event beats an older in-flight frame.
    if not prior or prior.version <= f.version then M.stock(c,k,n,'fluidcache') end
  end
  local complete=count==#keys and f.poultices
  d.stale=not complete; d.status=complete and 'complete fluidcache' or 'partial fluidcache'
  if complete then d.last_complete=now(c) end
  M.render(c)
end
function M.audit(c, sender)
  expire(c)
  local d=data(c)
  if d.pending or d.frame or d.dispatching then return false,'audit already pending' end
  sender=sender or c.supplies_sender
  if type(sender)~='function' then return false,'no injected read-only sender' end
  if not connected(c) then return false,'disconnected' end
  d.requested=true; c.supplies_sender=sender
  d.sent_at=now(c); d.last_attempt=now(c); d.pending=true; d.dispatching=true
  local ok,result=pcall(sender,'fluidcache')
  d.dispatching=false
  if not ok or result==false then
    d.pending=false; d.frame=nil; d.stale=true; d.status='audit send failed'
    M.render(c); return false,d.status
  end
  M.render(c); return true
end
function M.detach(c)
  local o=c.supplies_owner
  if o and o.cleanup then o.cleanup() end
end
function M.attach(c)
  M.detach(c) -- invokes old module closure on dofile/reload, not only new locals
  local d=data(c)
  d.frame=nil; d.pending=false; d.requested=false; d.stale=true
  local owner={handlers={},triggers={},alive=true}
  c.supplies_owner=owner
  owner.cleanup=function()
    owner.alive=false
    for _,id in ipairs(owner.handlers) do if killAnonymousEventHandler then killAnonymousEventHandler(id) end end
    for _,id in ipairs(owner.triggers) do if killTrigger then killTrigger(id) end end
    if owner.timer and killTimer then killTimer(owner.timer) end
    if c.supplies_ui and c.supplies_ui.label and c.supplies_ui.label.delete then c.supplies_ui.label:delete() end
    c.supplies_ui=nil
    d.frame=nil; d.pending=false; d.requested=false; d.stale=true
    if c.supplies_owner==owner then c.supplies_owner=nil end
  end
  if tempRegexTrigger then owner.triggers[#owner.triggers+1]=tempRegexTrigger('^.*$',function()
    if owner.alive then M.text(c,line) end
  end) end
  if tempPromptTrigger then owner.triggers[#owner.triggers+1]=tempPromptTrigger(function()
    if owner.alive then M.prompt(c) end
  end) end
  if registerAnonymousEventHandler then
    for _,event in ipairs({'sysWindowResizeEvent','sysDisconnectionEvent'}) do
      owner.handlers[#owner.handlers+1]=registerAnonymousEventHandler(event,function()
        if owner.alive then
          if not connected(c) then d.frame=nil; d.pending=false; d.stale=true; d.status='disconnected' end
          M.render(c)
        end
      end)
    end
  end
  local function tick()
    if not owner.alive then return end
    owner.timer=nil
    expire(c)
    if d.requested and connected(c) and bash(c) and not d.pending and not d.frame and
      now(c)-(d.last_attempt or 0)>=60 then M.audit(c) end
    M.render(c)
    if owner.alive and tempTimer then owner.timer=tempTimer(5,tick) end
  end
  if tempTimer then owner.timer=tempTimer(5,tick) end
  M.render(c)
  return M.state(c)
end
return M
