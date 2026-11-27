-- Passive range picker. No constructor, attachment, mode or permission changes.
local P={VERSION='tour-picker-1'}
local function escape(v)return (tostring(v or ''):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'):gsub('"','&quot;'):gsub("'",'&#39;'))end
P.escape=escape
local function key(r)return tostring(r.name)..'\0'..tostring(r.entry)..'\0'..tostring(r.rating)end
P.key=key
local function up(fn,name)
 for i=1,100 do local n,v=debug.getupvalue(fn,i);if not n then break end;if n==name then return v end end
end
P.up=up
function P.new(c,M,env)
 local t,a,original,plan=c.tour,c.tour_attachment,env.get_command(),M.plan
 local io,s=t.io,t.state
 local p={version=P.VERSION,owner=c,tour=t,attachment=a,original=original,original_plan=plan,serial=0}
 local function clock()return io.now()end
 local function context()
  local st=c.current or {};local w=st.walker or {};local player=st.player or {}
  return {current=st,session=io.stream_session(),class=player.class,connected=st.connected,dead=player.dead,
   generation=s.generation,phase=s.phase,mode=c.mode,runner_mode=c.runner and c.runner.mode,
   epoch=w.intent_epoch,enabled=w.enabled,active=w.active,room=st.room and st.room.id,
   restock_enabled=c.restock_data and c.restock_data.enabled,restock_active=c.restock_data and c.restock_data.active,
   globe_armed=c.elemental_recovery and c.elemental_recovery.armed}
 end
 local function same(x,y)
  for k,v in pairs(x)do if y[k]~=v then return false end end
  for k,v in pairs(y)do if x[k]~=v then return false end end
  return true
 end
 local function owned()
  return env.get_command()==p.command and M.plan==p.plan and c.tour==t and c.tour_attachment==a and a.attached==true
 end
 local function hide(v)if v and v.widget then v.widget:hide()end end
 local function cleanup(q)
  if q.trigger then env.kill_trigger(q.trigger);q.trigger=nil end
  if q.timer then env.kill_timer(q.timer);q.timer=nil end
 end
 local function quarantine()
  local q=p.query
  if q and q.session~=io.stream_session()then cleanup(q);p.query=nil;q=nil end
  return q and not q.closed
 end
 local function drain(q)
  if not q or q.closed or q.draining then return end
  q.cancelled=true;q.draining=true
  cleanup(q)
  -- Retire the wildcard/timeout cohort immediately. A framing-only observer
  -- retains quarantine until the genuine untagged header/terminator drains.
  q.trigger=env.observe(q.on_line,'^\\*.*$')
 end
 function p.cancel()
  local v=p.view;if v then v.cancelled=true;hide(v)end
  drain(p.query)
  return true
 end
 local function valid(v)
  return v and p.view==v and not v.cancelled and not v.started and owned() and same(v.context,context())
 end
 function p.start(v)
  v=v or p.view
  if not valid(v)then return false,'picker stale: reopen the numeric range' end
  if not v.plan or quarantine()then return false,'fresh complete AREAS preview required'end
  if clock()-v.created>120 then return false,'picker expired: reopen the numeric range'end
  local selected,n={},0
  for _,slot in ipairs(v.plan.ready)do local k=key(slot.row);if v.selected[k]then selected[k]=true;n=n+1 end end
  if n==0 then return false,'select at least one ready area'end
  if s.reading or s.ticking then return false,'native coordinator is busy'end
  local generation=s.generation
  v.started=true;hide(v);p.binding=nil
  -- Native start is the sole permission/mode/grant authority. It cancels once,
  -- arms native controls, then creates a fresh ratings parser and native grant.
  local ok,result,why=pcall(original,v.command)
  if not ok then return false,'native start error: '..tostring(result)end
  if result~=true then return false,why or 'native start refused'end
  if not owned()or s.phase~='ratings'or s.generation~=generation+1 or not s.grant or not s.parser or s.reading or s.plan
    or s.lo~=v.lo or s.hi~=v.hi or io.scope(s.grant)~=true then
   return false,'native start changed/reentered; no selection grant installed'
  end
  p.binding={parser=s.parser,rows=s.parser.rows,grant=s.grant,generation=s.generation,lo=s.lo,hi=s.hi,selected=selected}
  return true
 end
 function p.plan(rows,lo,hi,catalog,graph)
  local out=plan(rows,lo,hi,catalog,graph)
  local b=p.binding
  -- Canonical native ratings planning is NEVER an unrestricted preview. If
  -- native start succeeded but selection publication failed/reentered, or an
  -- owner/grant/parser changed later, fail closed rather than restore Barrow.
  local canonical=s.phase=='ratings'and s.parser and rows==s.parser.rows
   and lo==s.lo and hi==s.hi and catalog==io.catalog and graph==io.graph
  local selected=b and owned()and rows==b.rows and s.parser==b.parser and s.grant==b.grant
   and s.generation==b.generation and lo==b.lo and hi==b.hi and io.scope(b.grant)==true
  if canonical then
   local ready={}
   for _,slot in ipairs(out.ready)do
    if selected and b.selected[key(slot.row)]then ready[#ready+1]=slot
    else
     slot.status='skipped';slot.reason=selected and 'disabled in tour picker'or 'tour picker selection missing or stale'
     out.skipped[#out.skipped+1]=slot
    end
   end
   out.ready=ready
   table.sort(out.skipped,function(x,y)
    if x.row.level~=y.row.level then return x.row.level<y.row.level end
    if x.row.name:lower()~=y.row.name:lower()then return x.row.name:lower()<y.row.name:lower()end
    return x.row.entry<y.row.entry
   end)
  end
  return out
 end
 local function ready_preview(v,q)
  if not valid(v)or q.cancelled or q.fault or not q.done then return end
  v.plan=plan(q.rows,v.lo,v.hi,io.catalog,io.graph);v.selected={};v.entries={}
  for _,bucket in ipairs({'ready','unsupported','unmapped','skipped','held'})do
   for _,slot in ipairs(v.plan[bucket]or{})do
    v.entries[#v.entries+1]=slot
    if bucket=='ready'then
     local name=slot.row.name:lower()
     -- Exact native AREAS identity only; never change the global catalog.
     v.selected[key(slot.row)]=not ((name=="the ia'shal barrow" or name=="ia'shal barrow") and tostring(slot.row.entry)=='5517')
    end
   end
  end
  table.sort(v.entries,function(x,y)if x.row.level~=y.row.level then return x.row.level<y.row.level end;return x.row.name:lower()<y.row.name:lower()end)
  p.render(v)
 end
 function p.open(command)
  local lo,hi=M.bounds(command);if not lo then return false,hi end
  if not owned()then return false,'picker detached'end
  if quarantine()then return false,'prior picker AREAS stream not proven closed'end
  local session=io.stream_session()
  if s.parser and s.parser.query_sent and not s.parser.closed and s.parser.session==session then return false,'native AREAS stream not proven closed'end
  if s.phase~='off'and s.phase~='cancelled'and s.phase~='done'then return false,'stop the current native tour before preview'end
  if not c.current.connected or c.current.player.dead then return false,'connected living session required'end
  p.cancel();p.serial=p.serial+1
  local v={command=command,lo=lo,hi=hi,created=clock(),context=context(),selected={},page=1,serial=p.serial}
  p.view=v;p.render(v)
  local q=M.parser();q.session=session;q.view=v;p.query=q
  q.on_line=function(text)
   if p.query~=q then return end
   if q.session~=io.stream_session()then cleanup(q);p.query=nil;return end
   M.line(q,text)
   if q.closed then cleanup(q);p.query=nil;ready_preview(v,q)
    if not q.done and valid(v)and not q.cancelled then v.error=q.fault or 'invalid AREAS frame';p.render(v)end
   end
  end
  q.trigger=env.observe(q.on_line)
  q.timer=env.after(16,function()
   q.timer=nil
   if p.query==q and not q.closed then drain(q);v.error='AREAS timeout; waiting for real stream terminator before retry';p.render(v)end
  end)
  -- Install observer BEFORE sending; handle synchronous server fixtures safely.
  q.query_sent=true
  local ok,result=pcall(io.ratings)
  if not ok or result~=true then drain(q);v.error='AREAS transport unknown; awaiting stream closure';p.render(v);return false,v.error end
  return true,v
 end
 function p.command(command,...)
  local lo=M.bounds(command)
  if lo then return p.open(command)end
  -- Preserve the original status/stop/plan and invalid-command behavior.
  if tostring(command):gsub('^bash +','bash')=='bashstop'then p.cancel();p.binding=nil end
  return original(command,...)
 end
 local function button(parent,name,x,y,w,text,callback)
  local label=env.Geyser.Label:new({name=name,x=x,y=y,width=w,height=27},parent)
  label:echo('<div style="font-size:12px;color:#eeeeee;background-color:#263241;padding:4px;">'..text..'</div>')
  if callback then label:setClickCallback(callback)end
  return label
 end
 function p.render(v)
  if v.cancelled then return end
  -- Reuse a single popup and bounded row widgets; no root/legacy GUI rebuild.
  if not v.widget then
   if p.widget then p.widget:hide()end
   if not p.widget then p.widget=env.Geyser.Container:new({name='CombatV2TourPicker',x='15%',y='12%',width='70%',height=475})end
   v.widget=p.widget;v.labels={}
  end
  v.widget:show()
  for _,label in ipairs(p.labels or{})do label:hide()end
  p.labels={}
  local function add(name,x,y,w,text,cb)
   local id='CombatV2TourPicker_'..name
   p.widgets=p.widgets or {};local label=p.widgets[id]
   if not label then label=button(v.widget,id,x,y,w,text,cb);p.widgets[id]=label
   else label:echo('<div style="font-size:12px;color:#eeeeee;background-color:#263241;padding:4px;">'..text..'</div>');if cb then label:setClickCallback(cb)else label:setClickCallback(function()end)end;label:show()end
   p.labels[#p.labels+1]=label;return label
  end
  add('title',0,0,'100%','BASH '..v.lo..'–'..v.hi..' — choose areas; nothing starts until Start')
  add('notice',0,30,'100%',escape(v.error or (v.plan and 'Only reviewed READY areas selectable. Ia\'shal Barrow is OFF by default.'or 'Reading fresh AREAS (read-only)…')))
  local entries=v.entries or{};local pages=math.max(1,math.ceil(#entries/10));v.page=math.min(v.page,pages)
  for i=1,10 do
   local slot=entries[(v.page-1)*10+i]
   if slot then
    local r=slot.row;local k=key(r);local ready=slot.status=='ready';local g=slot.graph or{};local count=0
    for _ in pairs(g.nodes or{})do count=count+1 end
    local counts=ready and (' — '..count..' reachable / '..tostring(g.mapped_count or '?')..' mapped'..(count<=3 and ' [TINY COMPONENT]'or ''))or (' — '..tostring(slot.reason or slot.status))
    local prefix=ready and (v.selected[k]and '[x] 'or '[ ] ')or '[-] '
    add('row'..i,0,65+(i-1)*30,'100%',escape(prefix..r.rating..' '..r.name..' ['..slot.status..']'..counts),function()
     if not valid(v)or not ready then return end;v.selected[k]=not v.selected[k];p.render(v)
    end)
   end
  end
  add('all',0,375,'25%','Select all READY',function()if valid(v)and v.plan then for _,slot in ipairs(v.plan.ready)do v.selected[key(slot.row)]=true end;p.render(v)end end)
  add('none','25%',375,'25%','Select none',function()if valid(v)then v.selected={};p.render(v)end end)
  add('prev','50%',375,'25%','Previous',function()if valid(v)then v.page=math.max(1,v.page-1);p.render(v)end end)
  add('next','75%',375,'25%','Next ('..v.page..'/'..pages..')',function()if valid(v)then v.page=math.min(pages,v.page+1);p.render(v)end end)
  add('cancel',0,415,'50%','Cancel / Close',function()if p.view==v then p.cancel()end end)
  add('start','50%',415,'50%','Start Bash Tour',function()local ok,why=p.start(v);if not ok then v.error=why;if not v.started then p.render(v)end;env.report(why)end end)
 end
 return p
end
return P
