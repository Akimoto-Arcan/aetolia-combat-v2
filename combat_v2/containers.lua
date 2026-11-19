-- Pure carried-curative evidence and bounded refill helper (Lua 5.1).
-- No send/global callbacks, curing, movement, purchasing, GUI or timer ownership.
-- Inject querySender(command) into audit; service injects actionSender(command).
-- A nil sender return is successful transport, NOT proof of a resulting refill.
local M = {}
local kinds = {'vial','pipe','bandage'}
local commands = {vial='viallist',pipe='pipelist',bandage='bandagelist'}
local required = {
 vial={'health','mana','speed','vigor','levitation','harmony','arcane','immunity','infusion','prudence','purgative'},
 pipe={'reishi','willow','yarrow'},
 bandage={'caloric','epidermal','mass','mending','restoration','soothing'}
}
local names = {vial={},pipe={['a reishi mushroom']='reishi',['some willow bark']='willow',['a yarrow root']='yarrow'},bandage={}}
for _,n in ipairs(required.vial) do names.vial['an elixir of '..n]=n end
names.vial['an elixir of the arcane']='arcane'
names.vial['a purgative concoction']='purgative'
for _,n in ipairs(required.bandage) do
 names.bandage['a '..n..' poultice']=n; names.bandage['an '..n..' poultice']=n
end
local headers = {['Vial Elixir Sips Decay']='vial',['Pipe Herb Puffs Decay Lit']='pipe',
 ['Bandage Poultice Presses Decay']='bandage'}
local function now(c) return (c.containers_clock or c.supplies_clock or os.time)() end
local function online(c)
 local f=c.containers_connected or c.supplies_connected
 if f then return f()==true end
 if type(getConnectionInfo)=='function' then
  local ok,_,_,connected=pcall(getConnectionInfo); return ok and connected==true
 end
 return false
end
local function data(c)
 if not c.containers_data then
  c.containers_data={version=0,sources={},learned={},requested=false}
 end
 local d=c.containers_data
 for _,k in ipairs(kinds) do
  d.sources[k]=d.sources[k] or {rows={},stale=true,status='not audited'}
 end
 c.containers_pipe_assignments=c.containers_pipe_assignments or {}
 return d
end
-- Native lists carry no request ID. Once a reply may have been abandoned,
-- neither a local version nor a prompt proves a later header belongs to a new
-- query. Latch UNKNOWN for this data lifetime; invalidate/hot-load must retain
-- it. There is deliberately no automatic retry or prompt-based recovery.
local function quarantine(c,reason)
 local d=data(c)
 d.quarantine=d.quarantine or reason
 for _,k in ipairs(kinds) do
  local s=d.sources[k]
  s.pending=false;s.frame=nil;s.stale=true;s.status='stream quarantined: '..d.quarantine
 end
 d.active=nil;d.use_due=nil
end
local function fresh(c,s)
 return not data(c).quarantine and not s.stale and s.at~=nil and now(c)>=s.at and now(c)-s.at<=(c.containers_fresh_seconds or 90) and online(c)
end
local function quiet(c) return c.supplies_quiet~=false end
local function tracked(c,s)
 return quiet(c) and s.complete==true and not s.stale and s.at~=nil and
  now(c)>=s.at and not data(c).quarantine and online(c)
end
local function expire(c)
 local d=data(c)
 for _,k in ipairs(kinds) do
  local s=d.sources[k]
  if s.pending and now(c)-s.sent_at>= (c.containers_timeout or 10) then
   quarantine(c,'response timeout');break
  end
 end
 if d.barrier and now(c)-d.barrier.at >= (c.containers_refill_timeout or 15) then
  d.barrier.fault=d.barrier.fault or 'refill readback timeout'
 end
end
local function allowed(k,n)
 for _,v in ipairs(required[k] or {}) do if v==n then return true end end
 return false
end
local function copy(r)
 local out={}; for k,v in pairs(r) do out[k]=v end; return out
end
local function commit(c,k)
 local d=data(c); local s=d.sources[k]; local f=s.frame
 if d.quarantine or not s.pending or not f or not f.prompt then return end
 s.pending=false; s.frame=nil
 if f.bad or not f.closed or not f.separator then
  s.stale=true;s.status='malformed or incomplete response';return
 end
 -- Empty pipe inference is legal ONLY for this unique three-pipe mapping.
 if k=='pipe' then
  local count,empties,unknown,seen,empty=0,0,0,{},nil
  for id,r in pairs(f.rows) do
   count=count+1
   if r.empty then empties=empties+1;empty=id
   elseif r.type then seen[r.type]=(seen[r.type] or 0)+1 else unknown=unknown+1 end
  end
  local missing={};local unique=true
  for _,n in ipairs(required.pipe) do
   if not seen[n] then missing[#missing+1]=n elseif seen[n]~=1 then unique=false end
  end
  if count==3 and empties==1 and unknown==0 and unique and #missing==1
    and not c.containers_pipe_assignments[empty] then
   c.containers_pipe_assignments[empty]=missing[1]
  end
 end
 for id,r in pairs(f.rows) do
  if r.empty then
   r.type = k=='pipe' and c.containers_pipe_assignments[id] or d.learned[id]
  elseif r.type then
   d.learned[id]=r.type
   if k=='pipe' then c.containers_pipe_assignments[id]=r.type end
  else
   -- A freshly identified unrelated fluid revokes old refill authority.
   d.learned[id]=nil
   if k=='pipe' then c.containers_pipe_assignments[id]=nil end
  end
 end
 s.rows=f.rows;s.at=now(c);s.version=f.version;s.stale=false;s.status='complete';s.complete=true
 s.debt={};s.usage_count=0
 -- A positive native readback, not time or another use, rearms the budget.
 if s.readback_types then
  local positive=true
  for n in pairs(s.readback_types) do
   local found=false
   for _,r in pairs(s.rows) do
    if r.type==n then
     if r.count<=0 then positive=false else found=true end
    end
   end
   positive=positive and found
  end
  if positive then s.usage_readback=nil;s.readback_types=nil end
 end
 local b=d.barrier
 if b and not d.action_dispatching and b.kind==k and s.version>b.fence then
  local r=s.rows[b.id]
  if r and r.type==b.type and r.count>0 then
   if b.phase=='light' then
    if r.lit==true then d.barrier=nil end
   elseif k=='pipe' and r.lit==false then
    b.phase='needs light';b.fence=s.version;b.fault=nil;b.at=now(c)
   else d.barrier=nil end
  end
 end
end
function M.audit(c,querySender,kind)
 if kind~=nil and not commands[kind] then return false end
 local selected=kind and {kind} or kinds
 expire(c);local d=data(c)
 if d.quarantine or type(querySender)~='function' or not online(c) or d.dispatching then return false end
 for _,k in ipairs(kinds) do if d.sources[k].pending then return false end end
 d.querySender=querySender;d.requested=true;d.dispatching=true;d.last_query=now(c);d.use_due=nil
 -- Reserve selected versions before calling any potentially reentrant sender.
 for _,k in ipairs(selected) do
  d.version=d.version+1
  local s=d.sources[k];s.query_version=d.version;s.pending=true;s.sent_at=now(c);s.frame=nil;s.bad_prefix=nil
  -- An explicit audit spends any outstanding usage readback budget too.
  if s.usage_readback then s.usage_readback='sent' end
 end
 local success=true
 for _,k in ipairs(selected) do
  if d.quarantine then success=false;break end
  local s=d.sources[k]
  d.sending=k
  local ok,result=pcall(querySender,commands[k])
  d.sending=nil
  if not ok or result==false then
   quarantine(c,'query transport failed');success=false
  end
 end
 d.dispatching=false
 for _,k in ipairs(kinds) do commit(c,k) end
 return success and not d.quarantine
end
local function fields(line)
 local out={}
 -- Native columns are separated by at least two spaces, never single words.
 for part in (line..'  '):gmatch('(.-)%s%s+') do
  part=part:match('^%s*(.-)%s*$');out[#out+1]=part
 end
 return out
end
-- Match only anchored own receipts and exact native curative descriptions.
-- The vial suffix is the observed native receipt; no guessed container ID.
local function receipt(line)
 local label=line:match('^You take a drink of (.-) from an academy vial%.$') or
  line:match('^You take a drink of (.-)%.$') or line:match('^You take a drink from (.-)%.$')
 if label and names.vial[label] then return 'vial',names.vial[label] end
 label=line:match('^You smoke (.-)%.$') or line:match('^You take a long drag from (.-)%.$')
 if label and names.pipe[label] then return 'pipe',names.pipe[label] end
 label=line:match('^You press (.-) against [%a%s]+%.$') or
  line:match('^You apply (.- poultice) [%a%s]+%.$')
 if label and names.bandage[label] then return 'bandage',names.bandage[label] end
end
-- One cache-proof budget per native source generation. Coalesce FC requests;
-- retain another source's intent if the parent's single marker is occupied.
local function request_stock(d,s,source)
 if s.stock_budget_version==s.version then return end
 s.stock_due=source
 if not d.stock_needed or d.stock_needed==source then
  d.stock_needed=source;s.stock_budget_version=s.version;s.stock_due=nil
 end
end
local function usage(c,k,n)
 local d=data(c);local s=d.sources[k]
 -- Fence even a pre-header query: it cannot overwrite this later use.
 if s.pending then s.bad_prefix=true;if s.frame then s.frame.bad=true end end
 if not tracked(c,s) then return end
 s.debt=s.debt or {};s.usage_count=(s.usage_count or 0)+1
 local matches={}
 for _,r in pairs(s.rows) do if r.type==n then matches[#matches+1]=r end end
 if #matches==0 then
  -- A known fluid with an unknown ID is not an empty-container proof.
  s.unknown_uses=(s.unknown_uses or 0)+1;return
 end
 local possible=false
 if #matches==1 then
  local r=matches[1]
  r.verified_count=r.verified_count or r.count -- hot-loaded pre-tracking baseline
  r.count=math.max(0,r.count-1);r.usage_derived=true;r.empty=false
  possible=r.count==0
 else
  -- Each row remains at its last verified value. Debt is aggregate, not a
  -- fabricated choice of which duplicate lost a sip (or which is empty).
  local total=0
  for _,r in ipairs(matches) do
   total=total+r.count;r.usage_derived=true
  end
  s.debt[n]=math.min(total,(s.debt[n] or 0)+1)
  for _,r in ipairs(matches) do if r.count<=s.debt[n] then possible=true end end
 end
 if possible then
  s.readback_types=s.readback_types or {};s.readback_types[n]=true
  if not s.usage_readback then
   s.usage_readback='needed'
   -- Last-use native FC autofill can debit reserves without a cache push.
   -- Verify FC once alongside the targeted list, not each sip/press/timer.
   if k~='pipe' then request_stock(d,s,'fluidcache') end
  end
 end
end
function M.text(c,line)
 expire(c);local d=data(c)
 if d.quarantine then return false end
 if type(line)~='string' then return false end
 line=line:gsub('\27%[[%d;]*m',''):match('^%s*(.-)%s*$')
 local k=headers[(line:gsub('%s+',' '))]
 if k then
  local s=d.sources[k]
  if not s.pending or (d.dispatching and d.sending~=k) then return false end
  if s.frame then s.frame.bad=true;return false end
  if d.active then d.sources[d.active].frame.bad=true end
  s.frame={rows={},at=now(c),version=s.query_version};d.active=k;return true
 end
 local active=d.active;local s=active and d.sources[active];local f=s and s.frame
 if f and line:match('^%-%-%-+%s*$') then
  if not f.separator then f.separator=true elseif not f.closed then f.closed=true;d.active=nil else f.bad=true end
  return true
 end
 -- Any expected-looking row outside its active frame invalidates that query.
 local rowkind=line:match('^(vial)') or line:match('^(pipe)') or line:match('^(bandage)')
 if rowkind then
  local rs=d.sources[rowkind]
  if rs.pending and (not f or active~=rowkind) then
   if rs.frame then rs.frame.bad=true else rs.stale=true end
   -- Remember a prefix row preceding the real header, too.
   rs.bad_prefix=true
   return false
  end
 end
 if f and line:match('^'..active) then
  local a=fields(line);local expected=active=='pipe' and 5 or 4
  local id=a[1];local n=a[3];local decay=a[4]
  if #a~=expected or not id or not id:match('^'..active..'%d+$') or
   not n or not n:match('^%d+$') or not decay or
   (decay~='A' and not decay:match('^%d+$')) or f.rows[id] or not f.separator or f.closed or
   (active=='pipe' and a[5]~='Yes' and a[5]~='No') then f.bad=true;return false end
  local empty=a[2]=='empty';local count=tonumber(n)
  if count==math.huge or (empty and count~=0) or (not empty and count==0) then f.bad=true;return false end
  f.rows[id]={id=id,kind=active,type=names[active][a[2]],empty=empty,count=count,verified_count=count,
   decay=decay=='A' and 'A' or tonumber(decay),lit=active=='pipe' and a[5]=='Yes' or false}
  return true
 end
 if quiet(c) then
  local kind,n=receipt(line)
  if kind then usage(c,kind,n) end
  return false
 end
 -- Explicit legacy policy keeps the old all-source debounced refresh.
 if line:match('^You take a drink from .+%.$') or line:match('^You take a drink of .+%.$') or
    line:match('^You smoke .+%.$') or line:match('^You take a long drag from .+%.$') or
    line:match('^You press .+ against .+%.$') or line:match('^You apply .+ poultice .+%.$') then
  for _,kind in ipairs(kinds) do
   local source=d.sources[kind];source.stale=true
   -- A list requested before this use cannot re-authorize old counts.
   if source.pending then source.bad_prefix=true;if source.frame then source.frame.bad=true end end
  end
  d.use_due=d.use_due or now(c)+5
 end
 return false
end
function M.prompt(c)
 expire(c);local d=data(c)
 for _,k in ipairs(kinds) do
  local s=d.sources[k]
  if s.frame then
   s.frame.prompt=true
   if s.bad_prefix then s.frame.bad=true end
   if not d.dispatching then commit(c,k) end
  end
 end
 d.active=nil
end
function M.invalidate(c)
 local d=data(c)
 -- Cancelling a dispatched query abandons an uncorrelated response too.
 for _,k in ipairs(kinds) do
  if d.sources[k].pending then quarantine(c,'query abandoned');break end
 end
 for _,k in ipairs(kinds) do
  local s=d.sources[k];s.pending=false;s.frame=nil;s.stale=true;s.bad_prefix=nil
 end
 d.active=nil;d.use_due=nil
 -- Deliberately retain learned IDs, quarantine and resource barriers on reload.
end
function M.state(c)
 expire(c);local d=data(c)
 local out={issues={},containers={},stale=false,pending=false,complete=true,completefresh=true,sources={},quarantine=d.quarantine}
 for _,k in ipairs(kinds) do
  local s=d.sources[k];local authoritative=fresh(c,s);local retained=tracked(c,s)
  local valid=authoritative or retained
  out.sources[k]={fresh=authoritative,tracked=retained,complete=s.complete==true,pending=s.pending==true,
   at=s.at,version=s.version,status=s.status,usage_count=s.usage_count or 0,debt=copy(s.debt or {}),
   readback=s.usage_readback,unknown_uses=s.unknown_uses or 0}
  out.stale=out.stale or not valid;out.pending=out.pending or s.pending==true
  out.complete=out.complete and valid and not s.pending
  out.completefresh=out.completefresh and authoritative and (s.usage_count or 0)==0 and not s.pending
  if not valid then out.issues[#out.issues+1]=k..' list: stale/unknown ('..s.status..')' end
  local coverage={}
  for id,r in pairs(s.rows) do
   local row=copy(r);out.containers[id]=row
   local debt=(s.debt or {})[r.type] or 0
   row.count_lower=math.max(0,r.count-debt);row.count_upper=r.count
   row.estimated=r.usage_derived==true or debt>0;row.tracked=retained
   row.authoritative=authoritative and not row.estimated
   if type(r.decay)=='number' and s.at then row.decay=math.max(0,r.decay-math.max(0,now(c)-s.at)/86400) end
   if r.type then
    coverage[r.type]=true
    local label=r.type..' '..id
    local low=c['containers_'..k..'_low'] or (k=='pipe' and 2 or 10)
    if row.estimated and row.count_lower==0 then out.issues[#out.issues+1]=label..': possibly empty (tracked)'
    elseif r.count==0 then out.issues[#out.issues+1]=label..': EMPTY'
    elseif row.count_lower<=low then out.issues[#out.issues+1]=label..': low ('..row.count_lower..(row.estimated and ', tracked' or '')..')' end
    if type(row.decay)=='number' and row.decay<5 then out.issues[#out.issues+1]=label..': expires in '..string.format('%g',row.decay)..'d' end
    if k=='pipe' and r.count>0 and not r.lit then out.issues[#out.issues+1]=label..': unlit' end
   elseif r.empty then out.issues[#out.issues+1]=id..': EMPTY (unassigned)' end
  end
  if valid then for _,n in ipairs(required[k]) do
   if not coverage[n] then out.issues[#out.issues+1]=n..': missing '..k..' coverage' end
  end end
 end
 local b=d.barrier
 if b then out.refill=copy(b);out.issues[#out.issues+1]=b.id..': '..(b.fault or ('refill '..b.phase)) end
 if out.pending then out.issues[#out.issues+1]='container audit pending' end
 table.sort(out.issues)
 out.level=#out.issues==0 and 'ok' or 'warning'
 return out
end
local function stock(c,k,n)
 if not c.supplies or type(c.supplies.state)~='function' then return false,true end
 local ok,s=pcall(c.supplies.state,c)
 local v=ok and s and s.stocks and s.stocks[k=='pipe' and 'ic:'..n or n]
 local known=v and type(v.count)=='number' and v.count>=0 and v.count<math.huge and v.count==math.floor(v.count) and
  type(v.at)=='number' and now(c)>=v.at and now(c)-v.at<=(c.containers_stock_fresh_seconds or 90)
 return known and v.count>0,not known
end
local function service(c,actionSender,policy)
 local existing=data(c).barrier
 local session=c.current
 expire(c);local d=data(c)
 -- A hold may read back exactly one already committed transaction, never
 -- discover usage/stock, select a refill or LIGHT. Keep audit's native framing
 -- and transport quarantine; do not turn a failed readback into a retry.
 if policy=='settle' then
  local b=existing
  if not b then return false end
  local kind,phase=b.kind,b.phase
  local sender=d.querySender
  local function intact(inAudit)
   local root=c.current or {};local r=c.runner or {}
   if c.current~=session or c.containers_data~=d or d.barrier~=b or
    b.kind~=kind or b.phase~=phase or not commands[kind] or
    (phase~='waiting' and phase~='needs light' and phase~='light') or
    b.fault or d.quarantine or d.action_dispatching or
    c.transport_unknown or root.connected==false or root.transport_unknown or root.dispatching or root.action_dispatching or
    r.transport_unknown or r.transport_barrier or r.fault or r.dispatching then return false end
   if inAudit then
    if not d.dispatching or d.sending~=kind then return false end
   elseif d.dispatching then return false end
   for _,k in ipairs(kinds) do
    local source=d.sources[k]
    if source.frame or (source.pending and not (inAudit and k==kind)) then return false end
   end
   return true
  end
  if not intact(false) or b.query_due~=true or type(sender)~='function' then return false end
  -- State and connectivity providers may run callbacks. Recheck ownership
  -- after each, and again after audit's expiry/clock/connection reads.
  M.state(c)
  if not intact(false) then return false end
  local connected=online(c)
  if not connected or not intact(false) or b.query_due~=true then return false end
  local forwarded=false
  local function guarded(command)
   if forwarded or command~=commands[kind] or not intact(true) then return false end
   local connectedNow=online(c)
   if not connectedNow or not intact(true) then return false end
   forwarded=true
   return sender(command)
  end
  b.query_due=nil -- spend the single readback before any reentrant callback
  local ok=pcall(M.audit,c,guarded,kind)
  -- audit remembers its sender for future ordinary queries; never leave a
  -- transaction-scoped closure installed as that long-lived transport.
  if d.querySender==guarded then d.querySender=sender end
  if not ok then quarantine(c,'query transport failed') end
  return false
 end
 -- Expiry/readback may settle an old barrier; never fall through to a new fill.
 if policy and (policy~='continue' or not existing or d.barrier~=existing) then return false end
 if d.quarantine or d.dispatching or d.action_dispatching or not online(c) then return false end
 if quiet(c) then
  for _,k in ipairs(kinds) do
   local source=d.sources[k]
   if source.stock_due then request_stock(d,source,source.stock_due) end
  end
 end
 -- One targeted readback per possible-empty episode or committed action.
 local querykind
 if d.barrier and d.barrier.query_due then querykind=d.barrier.kind
 elseif quiet(c) and not d.barrier then
  for _,k in ipairs(kinds) do
   if d.sources[k].usage_readback=='needed' then querykind=k;break end
  end
 end
 local legacy=not quiet(c) and d.use_due and now(c)>=d.use_due and now(c)-(d.last_query or -math.huge)>=5
 if d.querySender and (querykind or legacy) then
  local busy=false
  for _,k in ipairs(kinds) do busy=busy or d.sources[k].pending==true end
  if not busy then
   if d.barrier then d.barrier.query_due=nil end
   if querykind and not d.barrier then d.sources[querykind].usage_readback='sent' end
   M.audit(c,d.querySender,querykind)
  end
  return false
 end
 if c.containers_refill_enabled==false or type(actionSender)~='function' then return false end
 local s=M.state(c)
 if not quiet(c) and not s.completefresh then return false end
 local b=d.barrier;local command
 if policy and b~=existing then return false end
 if b then
  if b.phase~='needs light' or b.fault or not fresh(c,d.sources[b.kind]) or d.sources[b.kind].pending then return false end
  local r=s.containers[b.id]
  if not r or r.estimated or r.count<=0 or r.type~=b.type or r.lit then return false end
  command='light pipes';b.phase='light';b.fence=d.version;b.at=now(c)
 else
  local ids={};for id in pairs(s.containers) do ids[#ids+1]=id end;table.sort(ids)
  for _,id in ipairs(ids) do
   local r=s.containers[id]
   local source=d.sources[r.kind]
   if r.empty and r.count==0 and not r.estimated and allowed(r.kind,r.type) and
    id:match('^'..r.kind..'%d+$') and fresh(c,source) and not source.pending then
    local positive,needsproof=stock(c,r.kind,r.type)
    -- Recheck source-local proof after potentially reentrant stock callbacks.
    local current=M.state(c).containers[id]
    local eligible=fresh(c,source) and not source.pending and source.version==s.sources[r.kind].version and
     current and current.empty and current.count==0 and not current.estimated and current.type==r.type
    if eligible and needsproof then request_stock(d,source,r.kind=='pipe' and 'ic' or 'fluidcache') end
    if positive and eligible then
     b={id=id,kind=r.kind,type=r.type,phase='waiting',fence=d.version,at=now(c)}
     command=r.kind=='pipe' and ('put '..r.type..' in '..id) or ('fluidcache fill '..r.type..' '..id)
     break
    end
   end
  end
  if not command then return false end
  d.barrier=b
 end
 -- Commit BEFORE invoking transport; nested service must not duplicate sends.
 d.action_dispatching=true
 local ok,result=pcall(actionSender,command)
 d.action_dispatching=false
 -- Evidence whose query began inside transport is not post-send readback.
 b.fence=d.version
 if not ok or result==false then b.fault='refill transport unresolved' end
 b.query_due=true
 return ok and result~=false,command
end
function M.service(c,actionSender,policy)
 local d=data(c)
 if d.servicing then return false end
 d.servicing=true
 local ok,result,command=pcall(service,c,actionSender,policy)
 d.servicing=false
 if not ok then return false end
 return result,command
end
return M
