-- Cold-only composition binder. No recipes, timers or global-send interception.
local B={}
local function cap(fn,name)
 for i=1,100 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==name then return v,i end end
end
local function compile(s,name)
 local f,e;if loadstring then f,e=loadstring(s,name)else f,e=load(s,name,'t',_G)end;assert(f,e);return f
end
local function unhex(s)return(s:gsub('..',function(x)return string.char(tonumber(x,16))end))end
local function source(fn)return type(fn)=='function'and(debug.getinfo(fn,'S').source or '')or ''end
local function basename(fn)return source(fn):match('/([^/]+)%.lua')end
local function owned_callback(fn)
 local tag=source(fn)
 return tag:find('/combat_v2/',1,true)or tag:match('^@combat_v2/')or tag:match('^@combat%-v2%-')
end
local methods={
 runner={execute=true},mental={tick=true},buffs={service=true},containers={service=true,audit=true},elementals={service=true},supplies={audit=true,audit_containers=true,check_all=true},tattoo={tick=true,request=true},restock={tick=true,start=true,command=true},lunch={tick=true,start=true,command=true},tour={tick=true,start=true},travel={pump=true,request=true},policy={services=true},walker_boot={step=true}}
local role_names={runner='runner',mental='mental',buffs='buffs',containers='containers',elementals='elementals',supplies='supplies',tattoo='tattoo',restock='restock',lunch='lunch',tour='tour',travel='travel',policy='policy',walker_boot='walker'}
-- These are actual transport boundaries, not ingestion/readiness/view methods.
local io_names={send=true,follow=true,recall=true,haven_refresh=true,command=true,query=true,action=true,look=true,travel=true,transfer=true,order=true,put=true,take=true,buy=true,deposit=true,withdraw=true,ink=true}
-- FC/IC are read-only response lanes, not physical purchases/recipes. Preserve
-- their pending facts; fence new queries while survival owns IO. Do not confuse
-- their aggregate boolean with a physical token or unknown query shape.
function B.readonly_supplies(c)
 local d=c.supplies_data
 if type(d)~='table'or d.pending~=true or d.requested~=true or type(d.audit_id)~='number'or d.audit_id<1 or d.audit_id%1~=0 or type(d.sources)~='table'or d.dispatching or d.auditing then return false end
 local allowed={fluidcache=true,ic=true,['fc missing']=true,['ic missing']=true};local pending=false
 for name,row in pairs(d.sources)do
  if not allowed[name]or type(row)~='table'or row.pending~=nil and type(row.pending)~='boolean'or row.frame~=nil and type(row.frame)~='table'then return false end
  pending=pending or row.pending==true
 end
 return pending
end
local function graph(c,extra,A)
 local seen,edges,functions={}, {}, {};local pending={c};local head=1;local count=0
 local function visit(v)
  if v==_G or seen[v]or type(v)~='table'and type(v)~='function'then return end
  if v==registerAnonymousEventHandler or v==killAnonymousEventHandler then return end
  if type(v)=='function'and(source(v):find('/survival',1,true)or source(v):find('@combat_v2/survival',1,true))then
   local original=A.unwrap_owned_guard(v);if original~=v then visit(original)end;return
  end
  seen[v]=true;pending[#pending+1]=v
 end
 for name,fn in next,_G do if type(name)=='string'and name:match('^combat_v2')and type(fn)=='function'then visit(fn)end end
 for _,fn in ipairs(extra or {})do visit(fn)end
 -- c is deliberately not marked until processing; avoid framework/observer
 -- closures dragging the host's unrelated full registries into this plan.
 while head<=#pending do
  local v=pending[head];head=head+1
  if not seen[v]or v~=c then
   seen[v]=true;count=count+1;assert(count<18000,'bounded cold IO graph exhausted')
   if type(v)=='table'then
    for k,x in next,v do
     if k~='survival_module'and k~='survival_arbiter'and k~='observer_check'and k~='emergency_observer_check'and k~='survival_boot'and k~='survival_binding_history'then
      if type(x)=='function'then edges[#edges+1]={edge='field',parent=v,key=k,original=x,label='cold field '..tostring(k)}end
      visit(x)
     end
    end
    local m=getmetatable(v);if type(m)=='table'then visit(m)end
   elseif type(v)=='function'then
    functions[#functions+1]=v
    for i=1,100 do local k,x=debug.getupvalue(v,i);if not k then break end
     if k~='_ENV'and k~='owners'and k~='guard_originals'then
      if type(x)=='function'then edges[#edges+1]={edge='upvalue',parent=v,key=i,name=k,original=x,label='cold capture '..k}end
      visit(x)
     end
    end
   end
  end
 end
 return edges,functions
end
function B.plan(c,A,E,continuity,reload,extra)
 local edges,functions=graph(c,extra,A);local target={};local io_tables={};local namespaces={}
 for _,name in ipairs({'runner_module','mental','buffs','containers','elementals','supplies','tattoo_module','travel','travel_module','convenience','restock_controller','restock_module','lunch_controller','lunch_module','tour','tour_boot','tour_picker_boot'})do
  namespaces[#namespaces+1]={owner=c,key=name,value=rawget(c,name)}
 end
 local function entry(fn,role,result)
  if type(fn)~='function'then return end
  local old=target[fn]
  if old then old.roles[role]=true;return end
  target[fn]={mode='entry',result=result,roles={[role]=true}}
 end
 for _,edge in ipairs(edges)do
  local fn=edge.original;local file=basename(A.unwrap_owned_guard(fn));local role=role_names[file]
  if role and methods[file]and methods[file][edge.key]and not(file=='buffs'and fn==c.emergency_numb.buff_guard)then entry(fn,role,file=='buffs'and'busy'or file=='policy'and'list'or'bool')end
 end
 entry(c.emergency_numb.buff_service_old,'buffs','busy')
 -- Public wrappers can have source tags other than the module they own.
 for _,row in ipairs({{c.runner_module,'execute','runner'},{c.mental,'tick','mental'},{c.buffs,'service','buffs','busy'},{c.containers,'service','containers'},{c.containers,'audit','containers'},{c.elementals,'service','elementals'},{c.travel,'pump','travel'},{c.travel,'request','travel'},{c.tour,'tick','tour'},{c.tour,'start','tour'},{c.restock_controller,'tick','restock'},{c.restock_controller,'start','restock'},{c.tattoo_module,'tick','tattoo'},{c.tattoo_module,'request','tattoo'},{c.policy,'services','policy','list'},{c.walker_boot,'step','walker'}})do
  local parent,key,role,result=row[1],row[2],row[3],row[4]
  if parent then local f=parent[key];if role=='buffs'and f==c.emergency_numb.buff_guard then f=c.emergency_numb.buff_service_old end;entry(f,role,result)end
 end
 -- Close each service's old/base continuation family so copied timers do not
 -- bypass an outer pending guard. Do NOT fence unrelated availability/parsers.
 local changed=true
 while changed do
  changed=false
  for fn,descriptor in pairs(target)do
   for i=1,100 do local name,x=debug.getupvalue(A.unwrap_owned_guard(fn),i);if not name then break end
    if type(x)=='function'and(name=='old'or name=='original'or name=='service'or name:match('^[a-z_]*service$')or name:match('^old_')or name=='pump')and basename(x)==basename(A.unwrap_owned_guard(fn))and not target[x]then
     local roles={};for role in pairs(descriptor.roles)do roles[role]=true end
     target[x]={mode='entry',result=descriptor.result,roles=roles};changed=true
    end
   end
  end
 end
 for _,row in ipairs({{c.travel,'travel'},{c.restock_controller,'restock'},{c.lunch_controller,'lunch'},{c.tour,'tour'}})do
  local owner,role=row[1],row[2]
  if owner and type(owner.io)=='table'then
   io_tables[owner.io]=true
   for name,fn in next,owner.io do if io_names[name]then entry(fn,role,'bool')end end
  end
 end
 -- Convenience's physical preparation always flows through these owned paths.
 for fn,desc in pairs(target)do if desc.roles.travel or desc.roles.buffs or desc.roles.elementals then desc.roles.convenience=true end end
 local nodes={}
 for _,edge in ipairs(edges)do
  local desc=target[edge.original]
  if desc then
   local roles={};for role in pairs(desc.roles)do roles[#roles+1]=role end
   edge.mode=desc.mode;edge.result=desc.result;edge.roles=roles;nodes[#nodes+1]=edge
  end
 end
 -- All fallback recipes use the SAME captured native sender, through owned
 -- fields. Native _G.send and keyboard/C++ FIRSTAID are never replaced.
 for _,row in ipairs({{c,'defense_sender','defense'},{c,'walk_sender','walker'},{c,'buff_sender','buffs'},{c,'mental_sender','mental'},{c.runner,'sender','runner'}})do
  local parent,key,role=row[1],row[2],row[3];local fn=rawget(parent,key)
  if fn~=nil and type(fn)~='function'then error('malformed cold sender '..key)end
  nodes[#nodes+1]={edge='field',parent=parent,key=key,original=fn or send,fallback=fn==nil,mode='raw',roles={role},direct_firstaid=true,label='cold owned sender '..key}
 end
 -- Enumerate aliases of these existing sender objects in retained closures and
 -- fields too; constructors/settings tables are not new dispatch permission.
 for _,row in ipairs({{'supplies_sender','supplies'},{'containers_query_sender','containers'},{'containers_action_sender','containers'}})do
  local fn=c[row[1]]
  if type(fn)=='function'then
   for _,edge in ipairs(edges)do if edge.original==fn and not target[fn]then edge.mode='entry';edge.roles={row[2]};edge.result='bool';nodes[#nodes+1]=edge end end
  end
 end
 return {nodes=nodes,classifiers={passive_restock=E.passive_restock,terminal_globe=E.terminal_globe,readonly_supplies=B.readonly_supplies},continuity=continuity,reload_token=reload,namespaces=namespaces},#functions
end
function B.attach(c,A,E,records,line_fn,prompt_fn,reload)
 local root=getMudletHomeDir()..'/combat_v2/'
 local platform=dofile(root..'survival_native.lua')
 local reg=registerAnonymousEventHandler
 assert(type(reg)=='function','actual native registration API missing')
 local expected
 if _VERSION=='Lua 5.1'then expected=unhex(platform.register_dump_hex)
 else expected=string.dump(compile(platform.register_reference,platform.source)())end
 assert(string.dump(reg)==expected,'actual registration API prototype differs from authenticated boundary')
 for _,name in ipairs({'tempRegexTrigger','tempPromptTrigger','isActive'})do
  assert(type(_G[name])=='function','native callback API missing '..name)
  if platform.require_c_intrinsics~=false then assert(debug.getinfo(_G[name],'S').what=='C','native callback API is not intrinsic '..name)end
 end
 local handlers=cap(reg,'handlers');local idmap=cap(reg,'handlerIdsToHandlers')
 assert(type(handlers)=='table'and type(idmap)=='table','actual named native event maps missing')
 assert(type(cap(reg,'highestHandlerId'))=='number','native mutable ID counter malformed')
 local ids={};for _,r in ipairs(records)do
  local ix=idmap[r.id];assert(type(ix)=='table'and ix.event==r.event and type(ix.index)=='number'and handlers[r.event]and handlers[r.event][ix.index]==r.fn,'new owned native callback mismatch '..r.event)
  ids[#ids+1]={id=r.id,event=r.event,index=ix.index,fn=r.fn}
 end
 local native_registry=debug.getregistry();local line_key,prompt_key
 for key,value in next,native_registry do
  if type(key)=='userdata'and value==line_fn then assert(not line_key,'ambiguous actual line callback ownership');line_key=key end
  if type(key)=='userdata'and value==prompt_fn then assert(not prompt_key,'ambiguous actual prompt callback ownership');prompt_key=key end
 end
 assert(line_key and prompt_key and line_key~=prompt_key,'actual stable C-held line/prompt callbacks missing')
 local n=c.emergency_numb;local s=c.current;local runner=c.runner;local defense=c.defense;local observe=defense.numb_observe;local text=c.defense.text;local prompt=c.buff_sensory_prompt
 local lineid,promptid=c.line_trigger,c.prompt_trigger;local isactive=isActive
 local function check(owner,state)
  if owner~=c or state~=n or c.current~=s or c.runner~=runner or runner.state~=s or c.emergency_numb~=n or c.defense~=defense or defense.numb_observe~=observe or defense.text~=text or c.buff_sensory_prompt~=prompt then return false end
  if registerAnonymousEventHandler~=reg or cap(reg,'handlers')~=handlers or cap(reg,'handlerIdsToHandlers')~=idmap or isActive~=isactive or c.line_trigger~=lineid or c.prompt_trigger~=promptid then return false end
  if native_registry[line_key]~=line_fn or native_registry[prompt_key]~=prompt_fn then return false end
  local one,a=pcall(isactive,lineid,'trigger');local two,b=pcall(isactive,promptid,'trigger');if not one or not two or a~=1 or b~=1 then return false end
  for _,r in ipairs(ids)do local ix=idmap[r.id];if not ix or ix.event~=r.event or ix.index~=r.index or not handlers[r.event]or handlers[r.event][r.index]~=r.fn then return false end end
  return true
 end
 local extra={line_fn,prompt_fn};for _,r in ipairs(records)do extra[#extra+1]=r.fn end
 -- Retained C-held aliases/timers and other owned event callbacks contribute
 -- real incoming service/sender edges, but are NOT stable observer witnesses.
 -- Their disappearance must never be treated as loss of text/prompt coverage.
 for key,fn in next,native_registry do
  if type(key)=='userdata'and type(fn)=='function'and owned_callback(fn)then extra[#extra+1]=fn end
 end
 for _,rows in next,handlers do if type(rows)=='table'then
  for _,fn in next,rows do if type(fn)=='function'and owned_callback(fn)then extra[#extra+1]=fn end end
 end end
 local plan,count=B.plan(c,A,E,function(owner)return check(owner,n)end,reload,extra)
 n.observer_check=check
 local api,why=A.bind(c,plan);assert(api,why)
 assert(check(c,n),'final actual cold callback witness failed')
 return api,{functions=count,guard_edges=#plan.nodes,events=#ids,line=lineid,prompt=promptid}
end
return B
