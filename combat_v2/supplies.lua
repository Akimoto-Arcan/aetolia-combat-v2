-- Reserve/container monitor. No native curing, runner or mode ownership.
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
local keys = {'infusion','prudence','purgative','soothing','health','mana','speed','vigor','levitation','harmony','arcane','immunity',
  'mass','caloric','epidermal','mending','restoration'}
groups.elixirs['an elixir of infusion']='infusion'
groups.elixirs['an elixir of prudence']='prudence'
groups.elixirs['an elixir of purgative']='purgative'
groups.elixirs['a purgative concoction']='purgative'
groups.poultices['a soothing poultice']='soothing'
local commands={'fluidcache','ic','fc missing','ic missing'}
local baseSource={fluidcache='fluidcache',ic='ic',['fc missing']='fluidcache',['ic missing']='ic'}
local pills={'acuity','amaurosis','anabiotic','antipsychotic','coagulation','decongestant',
  'depressant','eucrasia','euphoriant','kawhepill','opiate','ototoxin','panacea','paste',
  'pluck','somnium','steroid','stimulant','thanatonin','waterbreathing'}
local herbs={'reishi','willow','yarrow'}
local sourceKeys={fluidcache=keys,ic={}}
local allowed={}
for _,k in ipairs(keys) do allowed[k]='fluidcache' end
for _,section in ipairs({'pills','herbalism'}) do
  groups[section]={}
  for _,name in ipairs(section=='pills' and pills or herbs) do
    local k='ic:'..name
    groups[section][name]=k; allowed[k]='ic'
    sourceKeys.ic[#sourceKeys.ic+1]=k
  end
end
local function now(c)
  return c.supplies_clock and c.supplies_clock() or os.time()
end
local function data(c)
  if not c.supplies_data then c.supplies_data={stocks={},requested=false} end
  local d=c.supplies_data
  if not d.sources then
    d.sources={}
    for _,name in ipairs(commands) do d.sources[name]={stale=true,status='not audited',coverage={}} end
    d.frame=nil; d.pending=false
  end
  for _,name in ipairs(commands) do
    d.sources[name]=d.sources[name] or {stale=true,status='not audited',coverage={}}
  end
  return d
end
local function connected(c)
  if c.supplies_connected then return c.supplies_connected() == true end
  if type(getConnectionInfo) ~= 'function' then return false end
  local ok, _, _, online = pcall(getConnectionInfo)
  return ok and online == true
end
local function periodic_enabled(c)
  -- Standalone legacy consumers retain their original BASH-only policy.
  -- The installed carried-container integration monitors every connected mode.
  if c.containers or c.containers_required then return true end
  if c.supplies_is_bash then return c.supplies_is_bash()==true end
  return (c.current and c.current.mode or c.mode or (c.state and c.state.mode))=='BASH'
end
-- Separate narrow capabilities: no public generic arbitrary-command adapter.
function M.bind_containers(c,transport)
  assert(type(transport)=='function','container transport required')
  if c.containers_refill_enabled==nil then c.containers_refill_enabled=true end
  c.containers_query_sender=function(command)
    if command~='viallist' and command~='pipelist' and command~='bandagelist' then return false end
    if not connected(c) then return false end
    return transport(command)
  end
  c.containers_action_sender=function(command)
    if type(command)~='string' or not c.containers_refill_enabled or not connected(c) then return false end
    local fluid,family,id=command:match('^fluidcache fill ([a-z]+) ([a-z]+)([1-9]%d*)$')
    local valid=false
    if fluid and (family=='vial' or family=='bandage') then
      local source=family=='vial' and groups.elixirs or groups.poultices
      for description,key in pairs(source) do if key==fluid then valid=true end end
    end
    local herb,pipe=command:match('^put ([a-z]+) in pipe([1-9]%d*)$')
    if herb and (herb=='reishi' or herb=='willow' or herb=='yarrow') then valid=true end
    if command=='light pipes' then valid=true end
    if not valid then return false end
    return transport(command)
  end
end
function M.audit_containers(c)
  local d=data(c)
  if not c.containers or type(c.containers.audit)~='function' or
    type(c.containers_query_sender)~='function' or not connected(c) then return false end
  local s=c.containers.state(c)
  if s.pending then return false end
  d.containers_last_attempt=now(c)
  d.containers_refresh_due=nil
  return c.containers.audit(c,c.containers_query_sender)
end
-- Known own pipe-fill acknowledgement is a refresh hint, never a count delta.
-- Other own consumption templates await exact native fixtures; periodic polling
-- remains authoritative rather than guessing broad drink/press/drag patterns.
local function container_hint(c,line)
  if line=='You fill your pipe with a yarrow root.' then
    local d=data(c)
    if d.requested and not d.containers_refresh_due then
      d.containers_refresh_due=math.max(now(c)+1,(d.containers_last_attempt or 0)+5)
    end
  end
end
local function expire(c)
  local d=data(c)
  d.stale=false; d.pending=false
  local status={}
  for _,name in ipairs(commands) do
    local s=d.sources[name]
    if (s.frame and now(c)-s.frame.at>=10) or
      (s.pending and now(c)-(s.sent_at or 0)>=10) then
      s.frame=nil; s.pending=false; s.stale=true; s.status='response timeout'
    end
    if not connected(c) or (s.last_complete and now(c)-s.last_complete>90) then s.stale=true end
    if name==baseSource[name] then d.stale=d.stale or s.stale end
    d.pending=d.pending or s.pending==true
    if name==baseSource[name] then status[#status+1]=name..': '..s.status end
  end
  d.status=table.concat(status,'; ')
end
local function record(c,key,n,source,version)
  local d=data(c)
  d.version=(d.version or 0)+1
  d.stocks[key]={count=n,source=source,at=now(c),version=version or d.version}
  M.render(c)
end
-- Explicit trusted stock events never make an entire source complete/fresh.
function M.stock(c,key,n,source)
  if type(key)~='string' or not key:match('^[%w_:.%-]+$') or #key>60 or
    type(n)~='number' or n<0 or n~=math.floor(n) or n==math.huge or
    type(source)~='string' or source=='' then return false end
  record(c,key,n,source);return true
end
-- Native Rift.Change is an absolute cache count, not a purchase amount.
function M.rift(c,payload)
 if type(payload)~='table' or type(payload.name)~='string' then return false end
 local key='ic:'..payload.name
 if allowed[key]~='ic' then return false end
 local amount=payload.amount
 if type(amount)=='string' and not amount:match('^%d+$') then return false end
 if type(amount)~='string' and type(amount)~='number' then return false end
 return M.stock(c,key,tonumber(amount),'gmcp.IRE.Rift.Change')
end
function M.state(c)
  expire(c)
  local d=data(c)
  local s={stocks={},empty={},low={},unknown={},sources={},stale=d.stale,
    status=d.status,pending=d.pending==true,requested=d.requested}
  for name,v in pairs(d.sources) do
    s.sources[name]={stale=v.stale,pending=v.pending==true,complete=v.complete==true,
      status=v.status,last_complete=v.last_complete}
  end
  for k,v in pairs(d.stocks) do
    s.stocks[k]={count=v.count,source=v.source,at=v.at}
    if allowed[k] then
      if v.count==0 then s.empty[#s.empty+1]=k
      elseif v.count<(c.supplies_low or 200) then s.low[#s.low+1]=k end
    end
  end
  for k in pairs(allowed) do if not d.stocks[k] then s.unknown[#s.unknown+1]=k end end
  table.sort(s.empty); table.sort(s.low); table.sort(s.unknown)
  s.level=#s.empty>0 and 'critical' or
    ((#s.low>0 or #s.unknown>0 or s.stale or s.pending) and 'warning' or 'ok')
  local carried
  if c.containers and type(c.containers.state)=='function' then carried=c.containers.state(c)
  elseif c.containers_required then carried={issues={'Carried containers unavailable'},stale=true} end
  s.containers=carried
  if carried and (#(carried.issues or {})>0 or carried.stale or carried.pending) and s.level=='ok' then
    s.level='warning'
  end
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
  local function entry(k)
    return (allowed[k]=='ic' and 'IC ' or 'FC ')..k:gsub('^ic:','')..': '..s.stocks[k].count
  end
  local zero,low={},{}
  for _,k in ipairs(s.empty) do zero[#zero+1]=entry(k) end
  for _,k in ipairs(s.low) do low[#low+1]=entry(k) end
  local title=#zero>0 and ('EMPTY CACHE: '..table.concat(zero,', ')) or
    (#low>0 and 'LOW CURATIVE RESERVES (<'..(c.supplies_low or 200)..')' or
    ((s.stale or #s.unknown>0 or s.pending) and 'FC + IC CURATIVES: UNKNOWN / STALE' or
    (s.level~='ok' and 'CARRIED SUPPLIES: ISSUES' or 'OK')))
  local note=''
  if not s.containers then note='Carried vials/bandages and pipes unverified.' end
  if #zero>0 then note='Reserve empty; carried vials/bandages may remain. '..note end
  if s.stale or #s.unknown>0 or s.pending then
    note=note..' Unknown: '..#s.unknown..'. '..s.status..'.'
  end
  -- Render only affected entries, without treating carried IDs as stock keys.
  local issues={}
  for _,v in ipairs(low) do issues[#issues+1]=v end
  if s.containers then
    for _,v in ipairs(s.containers.issues or {}) do
      if type(v)=='string' then issues[#issues+1]=v end
    end
    if s.containers.stale or s.containers.pending then
      issues[#issues+1]='Carried containers: UNKNOWN / STALE'
    end
  end
  low=issues
  s.title=title; s.note=note; s.entries=issues
  if not c.supplies_ui and Geyser and Geyser.Label then
    c.supplies_ui = {label=Geyser.Label:new({name='combat_v2_supplies_alarm', x=350,y=10,width=600,height=48})}
  end
  local ui = c.supplies_ui
  if ui and ui.label then
    local w,h = 1920,978
    if type(getMainWindowSize)=='function' then w,h=getMainWindowSize() end
    local width = math.max(1, math.min(600, w-20))
    local columns=math.max(1,math.floor((width-12)/190))
    local cellChars=math.max(1,math.floor(((width-12)/columns-8)/7))
    local bodyRows=0
    local cells={}
    for i=1,#low,columns do
      local rowHeight=1; local row={}
      for j=i,math.min(#low,i+columns-1) do
        row[#row+1]='<td width="'..math.floor(100/columns)..'%" style="padding-right:8px">'..escape(low[j])..'</td>'
        rowHeight=math.max(rowHeight,math.ceil(#low[j]/cellChars))
      end
      bodyRows=bodyRows+rowHeight; cells[#cells+1]='<tr>'..table.concat(row)..'</tr>'
    end
    local body=#low>0 and ('<b>'..(s.containers and 'ISSUES:' or 'LOW:')..'</b><table width="100%" style="font-size:12px; table-layout:fixed">'..table.concat(cells)..'</table>') or ''
    local titleRows=math.ceil(#title/math.max(1,math.floor((width-12)/(s.level=='critical' and 11 or 8))))
    local noteRows=math.ceil(#note/math.max(1,math.floor((width-12)/7)))
    local height=math.max(s.level=='critical' and 106 or 48,
      titleRows*(s.level=='critical' and 24 or 19)+bodyRows*18+(#low>0 and 18 or 0)+noteRows*17+16)
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
      (s.level=='critical' and '20' or '13')..'px">'..escape(title)..'</b><br>'..body..escape(note)..'</div>')
    ui.level=s.level; ui.x=x; ui.y=y; ui.width=width; ui.height=math.min(height,h)
  end
  return s
end
-- Missing queries confirm only explicitly listed zeros, never omitted items.
local function begin(c,name,section)
  local d=data(c); local s=d.sources[name]
  d.version=(d.version or 0)+1
  local version=s.pending and s.sent_version or d.version
  s.sent_version=version
  s.frame={at=now(c),section=section,rows={},version=version,queried=s.pending and s.query_epoch~=nil and s.query_epoch==d.audit_id,missing=name:find('missing',1,true)~=nil}
  s.pending=true;s.sent_at=now(c);s.stale=true;s.complete=false;s.status='receiving'
  local base=baseSource[name]
  d['active_'..base]=name; d.active_source=name
  if name==base then s.coverage={};s.refills={} end
  return s.frame
end
local function missingList(f,text,section)
  text=text:gsub(', and ', ', '):gsub(' and ', ', ')
  if text=='' then f[section]=true; return end
  for token in (text..','):gmatch('(.-),') do
    local item=token:match('^%s*(.-)%s*$')
    if not item:match('^[%a]+$') then f.bad=true; return end
    local description=section=='elixirs' and ('an elixir of '..(item=='arcane' and 'the arcane' or item)) or
      ((item=='epidermal' and 'an ' or 'a ')..item..' poultice')
    local key=groups[section][description]
    if key then
      if f.rows[key]~=nil then f.bad=true; return end
      f.rows[key]=0
    end
  end
  f[section]=true
end
function M.text(c,line)
  if type(line)~='string' then return end
  if c.containers and c.containers.text then c.containers.text(c,line) end
  container_hint(c,line)
  expire(c)
  local d=data(c)
  local purchased=line:match('^You pay %d+ gold sovereigns to add %d+ sips of (.-) to your fluidcache%.$')
  if purchased and (groups.elixirs[purchased] or groups.poultices[purchased]) then
    -- Receipt is a DELTA, so request authoritative stock instead of adding it.
    d.refresh_after_purchase=now(c)+1
  end
  local list=line:match('^Missing elixirs: (.*)$')
  local poultices=line:match('^Missing poultices: (.*)$')
  if list or poultices then
    local source=d.sources['fc missing']
    -- After a timed-out reply, late category lines are not a fresh snapshot.
    -- A newly solicited query explicitly restores authority.
    if source.status=='response timeout' and not source.pending then return end
    local section=list and 'elixirs' or 'poultices'
    local f=source.frame or begin(c,'fc missing',section)
    missingList(f,list or poultices,section)
    return
  end
  if line==ELIXIRS then begin(c,'fluidcache','elixirs');return end
  if line=='Glancing into the cache, you see:' then begin(c,'ic','intro');return end
  if line=='Glancing into the cache, you see the following items missing:' then
    begin(c,'ic missing','intro');return
  end
  local header=line:match('^%-+ ([%a &]+) %-+$')
  local name,section
  if line==POULTICES then name='fluidcache';section='poultices'
  elseif header then
    name=d.active_ic
    section=header=='Pills' and 'pills' or (header=='Herbalism' and 'herbalism' or 'ignored')
  end
  if name then
    local f=d.sources[name].frame
    if not f then return end
    if section=='poultices' then f.poultices=true end
    if section=='pills' then f.pills=true end
    if section=='herbalism' then f.herbalism=true end
    f.section=section;d.active_source=name;return
  end
  local rowName=line:match('^%s*%[[^%]]*%]%s+([^%[]+)')
  local route=d.active_source
  if rowName then
    if rowName:match('^an? ') then route='fluidcache'
    else route=d.active_ic end
  end
  local s=route and d.sources[route]
  local f=s and s.frame
  if not f or not groups[f.section] or route=='fc missing' then return end
  if not line:match('^%s*%[') then return end
  if not line:match('^%s*%[%s*[%d%?%-]') and
    not line:match('^%s*%[[^%]]*%]%s+an? ') then return end
  local rest,found=line,false
  while rest:match('^%s*%[') do
    local n,body=rest:match('^%s*%[%s*(%d+)%]%s+(.+)$')
    if not n then f.bad=true;return end
    local boundary=body:find('[',1,true)
    local item=boundary and body:sub(1,boundary-1) or body
    rest=boundary and body:sub(boundary) or ''
    item=item:match('^(.-)%s*$')
    local key=groups[f.section][item]
    n=tonumber(n)
    -- Herbalism inventories also contain noncurative crafting ingredients.
    if not key and (f.missing or f.section=='herbalism') then
      -- Deliberately ignored, not evidence for a current curative.
    elseif not key or not n or n==math.huge or f.rows[key]~=nil or (f.missing and n~=0) then
      f.bad=true;return
    else f.rows[key]=n end
    found=true
  end
  if not found or not rest:match('^%s*$') then f.bad=true end
end
local function finish(c,name)
  local d=data(c);local s=d.sources[name];local f=s.frame
  if not f then return end
  s.frame=nil;s.pending=false
  local base=baseSource[name];local owner=d.sources[base]
  if f.bad or (name=='fc missing' and not (f.elixirs or f.poultices)) then
    s.stale=true;s.complete=false;s.status='malformed response'
    owner.stale=true;owner.complete=false
    if name==base and d.missing_wanted then d.missing_wanted[base]=nil end
    return
  end
  owner.coverage=owner.coverage or {}
  local count=0
  for _ in pairs(f.rows) do count=count+1 end
  if not f.missing and f.queried and d.missing_wanted then
    d.missing_wanted[base]=count<#sourceKeys[base] or nil
    s.full_done=true
  end
  local directComplete=not f.missing and count==#sourceKeys[base] and
    (base=='ic' and f.pills and f.herbalism or base=='fluidcache' and f.poultices)
  for k,n in pairs(f.rows) do
    local prior=d.stocks[k]
    if not prior or prior.version<=f.version then
      -- Partial full snapshots cannot clear prior critical reserves.
      if prior and prior.count==0 and n>0 and not directComplete then
        owner.refills=owner.refills or {}
        owner.refills[k]={count=n,version=f.version,source=name}
      else record(c,k,n,name,f.version) end
      owner.coverage[k]=now(c)
    else
      -- A newer explicit stock event is current evidence, not the older frame.
      owner.coverage[k]=prior.at
    end
  end
  local covered,oldest=0,now(c)
  for _,k in ipairs(sourceKeys[base]) do
    local at=owner.coverage[k]
    if type(at)=='number' and now(c)-at<=90 then
      covered=covered+1;oldest=math.min(oldest,at)
    end
  end
  local complete=covered==#sourceKeys[base]
  owner.complete=complete;owner.stale=not complete;owner.status=complete and 'complete' or 'partial'
  s.complete=complete;s.stale=not complete;s.status=complete and 'complete' or 'partial'
  if complete then
    owner.last_complete=oldest
    for k,v in pairs(owner.refills or {}) do
      local prior=d.stocks[k]
      if not prior or prior.version<=v.version then record(c,k,v.count,v.source,v.version) end
    end
    owner.refills={}
  end
end
local function dispatch(c,name)
  local d=data(c);local s=d.sources[name]
  d.version=(d.version or 0)+1;s.sent_version=d.version;s.query_epoch=d.audit_id
  s.sent_at=now(c);s.pending=true;s.stale=true;s.status='pending'
  d.dispatching=true
  local ok,result=pcall(c.supplies_sender,name)
  if not ok or result==false then
    s.pending=false;s.frame=nil;s.stale=true;s.status='audit send failed'
    for _,reply in pairs(d.sources) do
      if reply.deferred then reply.frame=nil;reply.pending=false;reply.stale=true end
      reply.deferred=nil
    end
    d.dispatching=false;return false
  end
  for _,command in ipairs(commands) do
    local reply=d.sources[command]
    if reply.deferred then finish(c,command) end
    reply.deferred=nil
  end
  d.dispatching=false;return true
end
local function requestMissing(c)
  local d=data(c);local success=true
  if not d.requested or d.dispatching then return true end
  for _,base in ipairs({'fluidcache','ic'}) do
    local s=d.sources[base]
    if d.missing_wanted and d.missing_wanted[base] and s.full_done then
      -- A full positive IC snapshot needs no huge IC MISSING material dump.
      d.missing_wanted[base]=nil
      local cmd=base=='ic' and 'ic missing' or 'fc missing'
      if not dispatch(c,cmd) then success=false end
    end
  end
  return success
end
function M.prompt(c)
  if c.containers and c.containers.prompt then c.containers.prompt(c) end
  expire(c)
  local d=data(c)
  for _,name in ipairs(commands) do
    local s=d.sources[name]
    if s.frame then
      if d.dispatching then s.deferred=true else finish(c,name) end
    end
  end
  requestMissing(c)
  M.render(c)
end
function M.audit(c,sender,cache_only)
  expire(c)
  local d=data(c)
  if connected(c) and type(sender or c.supplies_sender)=='function' then
    d.requested=true
    if not cache_only then M.audit_containers(c) end
  end
  local framed=false
  for _,s in pairs(d.sources) do framed=framed or s.frame~=nil end
  if d.pending or framed or d.dispatching or d.auditing then return false,'audit already pending' end
  sender=sender or c.supplies_sender
  if type(sender)~='function' then return false,'no injected read-only sender' end
  if not connected(c) then return false,'disconnected' end
  d.requested=true;c.supplies_sender=sender;d.last_attempt=now(c)
  d.audit_id=(d.audit_id or 0)+1
  d.auditing=true;d.missing_wanted={}
  local success=true
  -- At most one full read and one conditional missing read per source/audit.
  for _,name in ipairs({'fluidcache','ic'}) do
    local s=d.sources[name]
    s.coverage={};s.refills={};s.full_done=nil
    if not dispatch(c,name) then success=false end
  end
  if not requestMissing(c) then success=false end
  d.auditing=false
  M.render(c)
  if success then return true end
  return false,'audit send failed'
end
function M.detach(c)
  local o=c.supplies_owner
  if o and o.cleanup then o.cleanup() end
end
function M.attach(c)
  M.detach(c) -- invokes old module closure on dofile/reload, not only new locals
  local d=data(c)
  if c.containers and c.containers.invalidate then c.containers.invalidate(c) end
  d.containers_refresh_due=nil;d.containers_last_attempt=nil
  d.frame=nil; d.pending=false; d.requested=false; d.stale=true;d.refresh_after_purchase=nil
  for _,s in pairs(d.sources) do s.frame=nil; s.pending=false; s.deferred=nil; s.stale=true; s.complete=false; s.coverage={}; s.refills={}; s.full_done=nil; s.status='not audited' end
  local owner={handlers={},triggers={},alive=true}
  c.supplies_owner=owner
  owner.cleanup=function()
    owner.alive=false
    for _,id in ipairs(owner.handlers) do if killAnonymousEventHandler then killAnonymousEventHandler(id) end end
    for _,id in ipairs(owner.triggers) do if killTrigger then killTrigger(id) end end
    if owner.timer and killTimer then killTimer(owner.timer) end
    if c.supplies_ui and c.supplies_ui.label and c.supplies_ui.label.delete then c.supplies_ui.label:delete() end
    c.supplies_ui=nil
    if c.containers and c.containers.invalidate then c.containers.invalidate(c) end
    d.containers_refresh_due=nil
    d.frame=nil; d.pending=false; d.requested=false; d.stale=true;d.refresh_after_purchase=nil
  for _,s in pairs(d.sources) do s.frame=nil; s.pending=false; s.deferred=nil; s.stale=true; s.complete=false; s.coverage={}; s.refills={}; s.full_done=nil; s.status='not audited' end
    if c.supplies_owner==owner then c.supplies_owner=nil end
  end
  if tempRegexTrigger then owner.triggers[#owner.triggers+1]=tempRegexTrigger('^.*$',function()
    if owner.alive then M.text(c,line) end
  end) end
  if tempPromptTrigger then owner.triggers[#owner.triggers+1]=tempPromptTrigger(function()
    if owner.alive then M.prompt(c) end
  end) end
  if registerAnonymousEventHandler then
    owner.handlers[#owner.handlers+1]=registerAnonymousEventHandler('gmcp.IRE.Rift.Change',function()
      if owner.alive then M.rift(c,gmcp and gmcp.IRE and gmcp.IRE.Rift and gmcp.IRE.Rift.Change) end
    end)
    for _,event in ipairs({'sysWindowResizeEvent','sysDisconnectionEvent'}) do
      owner.handlers[#owner.handlers+1]=registerAnonymousEventHandler(event,function()
        if owner.alive then
          if not connected(c) then
            if c.containers and c.containers.invalidate then c.containers.invalidate(c) end
            for _,s in pairs(d.sources) do s.frame=nil; s.pending=false; s.stale=true; s.status='disconnected' end
          end
          M.render(c)
        end
      end)
    end
  end
  local function tick()
    if not owner.alive then return end
    owner.timer=nil
    expire(c)
    if d.refresh_after_purchase and now(c)>=d.refresh_after_purchase and connected(c) and not d.pending and not d.frame and type(c.supplies_sender)=='function' then
      d.refresh_after_purchase=nil;M.audit(c)
    elseif d.requested and connected(c) and periodic_enabled(c) and not d.pending and not d.frame and
      now(c)-(d.last_attempt or 0)>=60 then M.audit(c,nil,true) end
    if d.requested and connected(c) and c.containers then
      if (d.containers_refresh_due and now(c)>=d.containers_refresh_due) or
        now(c)-(d.containers_last_attempt or 0)>=60 then M.audit_containers(c) end
      if c.containers.service and c.containers_refill_enabled==true and
        type(c.containers_action_sender)=='function' then
        c.containers.service(c,c.containers_action_sender)
      end
    end
    M.render(c)
    if owner.alive and tempTimer then owner.timer=tempTimer(5,tick) end
  end
  if tempTimer then owner.timer=tempTimer(5,tick) end
  M.render(c)
  return M.state(c)
end
return M
