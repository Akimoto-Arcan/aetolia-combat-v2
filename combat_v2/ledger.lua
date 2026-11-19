-- Passive observations only. No commands, timers, helper authority or Mudlet API.
local M={}
local kinds={'vial','pipe','bandage'}
local required={vial={'health','mana','speed','vigor','levitation','harmony','arcane','immunity','infusion','prudence','purgative'},pipe={'reishi','willow','yarrow'},bandage={'caloric','epidermal','mass','mending','restoration','soothing'}}
local names={vial={},pipe={['a reishi mushroom']='reishi',['some willow bark']='willow',['a yarrow root']='yarrow'},bandage={}}
for _,n in ipairs(required.vial) do names.vial['an elixir of '..n]=n end
names.vial['an elixir of the arcane']='arcane'; names.vial['a purgative concoction']='purgative'
for _,n in ipairs(required.bandage) do names.bandage['a '..n..' poultice']=n;names.bandage['an '..n..' poultice']=n end
local pills={}
for n in ('acuity amaurosis anabiotic antipsychotic coagulation decongestant depressant eucrasia euphoriant kawhepill opiate ototoxin panacea paste pluck somnium steroid stimulant thanatonin waterbreathing'):gmatch('%S+') do pills[n]=true end
local headers={['Vial Elixir Sips Decay']='vial',['Pipe Herb Puffs Decay Lit']='pipe',['Bandage Poultice Presses Decay']='bandage'}
local function now(c) return (c.supplies_clock or c.containers_clock or os.time)() end
local function integer(n)
 if type(n)=='string' then if not n:match('^%d+$') or #n>10 then return nil end;n=tonumber(n) end
 if type(n)=='number' and n>=0 and n<=2147483647 and n==math.floor(n) then return n end
end
local function copy(t)
 if type(t)~='table' then return t end
 local o={};for k,v in pairs(t) do o[k]=copy(v) end;return o
end
local function data(c)
 if not c.supply_ledger_data then
  c.supply_ledger_data={cache={},carried={vial={},pipe={},bandage={},pill={}},used={},refills={},sources={},frames={},serial=0}
 end
 return c.supply_ledger_data
end
local function entry(d,k,n)
 local e=d.carried[k][n]
 if not e then e={used=0,received=0,delta=0,estimated=true,confidence='unknown'};d.carried[k][n]=e end
 return e
end
local function fence(d,k)
 if d.frames[k] then d.frames[k].bad=true end
end
local function change(c,k,n,delta,isuse,verified)
 local d=data(c);fence(d,k);local e=entry(d,k,n);local t=now(c)
 if isuse then
  e.used=e.used+1
  local key=k=='pill' and ('ic:'..n) or n
  d.used[key]=(d.used[key] or 0)+1
 else
  if delta>=0 then e.received=e.received+delta else e.deposited=(e.deposited or 0)-delta end
 end
 e.delta=e.delta+delta;e.estimated=true;e.at=t;e.event_at=t
 if not verified then e.unverified_pattern=true end
 if e.count~=nil then
  if e.count+delta<0 then e.uncertain=true;e.confidence='exhaustion uncertain' end
  e.count=math.max(0,e.count+delta)
 end
end
function M.cache(c,key,count,source,at)
 local d=data(c);local n=integer(count)
 local valid=type(key)=='string' and (names.vial['an elixir of '..key] or key=='purgative' or names.bandage['a '..key..' poultice'] or (key:match('^ic:') and (pills[key:sub(4)] or key=='ic:reishi' or key=='ic:willow' or key=='ic:yarrow')))
 if not valid or not n then return false end
 d.cache[key]={count=n,source=source,at=at or now(c),observed_at=at or now(c),estimated=false,confidence='observed'}
 return true
end
local function use(line)
 local label=line:match('^You take a drink of (.-) from a plain wooden vial%.$') or line:match('^You take a drink of (.-) from an academy vial%.$')
 if label and names.vial[label] then return 'vial',names.vial[label],true end
 label=line:match('^You swallow an? ([a-z]+) pill%.$')
 if label and pills[label] then return 'pill',label,true end
 label=line:match('^You smoke (.-)%.$') or line:match('^You take a long drag from (.-)%.$')
 if label and names.pipe[label] then return 'pipe',names.pipe[label],false end
 label=line:match('^You press (.-) against [%a%s]+%.$') or line:match('^You apply (.- poultice) [%a%s]+%.$')
 if label and names.bandage[label] then return 'bandage',names.bandage[label],false end
end
local function fields(line)
 local a={};for part in (line..'  '):gmatch('(.-)%s%s+') do a[#a+1]=part:match('^%s*(.-)%s*$') end;return a
end
local function expire(c)
 local d=data(c);local t=now(c)
 if d.infuse and (t-d.infuse.at>3 or t<d.infuse.at or d.serial-d.infuse.serial>6) then d.infuse=nil end
 for k,f in pairs(d.frames) do
  if t-f.at>15 or t<f.at or d.serial-f.serial>512 then
   d.frames[k]=nil;d.sources[k]=d.sources[k] or {};d.sources[k].confidence='incomplete frame'
   if d.active==k then d.active=nil end
  end
 end
end
function M.text(c,line)
 if type(line)~='string' or #line>2048 then return nil end
 local d=data(c);d.serial=d.serial+1;expire(c)
 line=line:gsub('\27%[[%d;]*m',''):match('^%s*(.-)%s*$')
 local k,n,verified=use(line)
 if k then change(c,k,n,-1,true,verified)
 else
  local unknownKind
  if line:match('^You take a drink of .+%.$') then unknownKind='vial'
  elseif line:match('^You smoke .+%.$') or line:match('^You take a long drag from .+%.$') then unknownKind='pipe'
  elseif line:match('^You press .+ against .+%.$') or line:match('^You apply .+ poultice .+%.$') then unknownKind='bandage' end
  if unknownKind then
   fence(d,unknownKind);d.sources[unknownKind]=d.sources[unknownKind] or {}
   d.sources[unknownKind].confidence='unrecognized use receipt'
  end
 end
 -- Refill transfer is carried-only; the paired absolute is the sole FC update.
 local vessel,amount,label=line:match('^You infuse (.-) with (%d+) doses of (.-) from your fluidcache%.$')
 if line:match('^You infuse ') then
  local old=d.infuse;d.infuse=nil
  amount=integer(amount)
  local kind=label and (names.vial[label] and 'vial' or names.bandage[label] and 'bandage')
  local knownVessel=vessel=='a plain wooden vial' or vessel=='an academy vial'
  -- Only the actually observed vial form is enabled; no guessed bandage receipt.
  if kind=='vial' and knownVessel and amount and amount>0 then
   local fluid=names[kind][label];change(c,kind,fluid,amount,false,true)
   d.refills[fluid]=(d.refills[fluid] or 0)+amount
   if not old and not d.infuse_ambiguous then d.infuse={key=fluid,at=now(c),serial=d.serial}
   else d.infuse_ambiguous=true end
  else d.infuse_ambiguous=true end
 end
 local remaining=line:match('^You have (%d+) sips remaining in your fluidcache%.$')
 if remaining then
  local p=d.infuse;d.infuse=nil
  local value=integer(remaining)
  if p and value and not d.infuse_ambiguous then return {cache={key=p.key,count=value,source='native FC refill'}} end
 elseif line:match('^You have .* remaining in your fluidcache') then d.infuse=nil end
 local qty,item,total=line:match('^You remove (%d+) ([a-z]+), bringing the total in the cache to (%d+)%.$')
 local deposit=false
 if not qty then qty,item,total=line:match('^You store (%d+) ([a-z]+), bringing the total to (%d+)%.$');deposit=true end
 qty,total=integer(qty),integer(total)
 if qty and qty>0 and total and pills[item] then
  change(c,'pill',item,deposit and -qty or qty,false,true)
  return {cache={key='ic:'..item,count=total,source=deposit and 'native IC deposit' or 'native IC withdrawal'}}
 end
 local header=headers[(line:gsub('%s+',' '))]
 if header then
  if d.frames[header] then d.frames[header].bad=true;return nil end
  if d.active then d.frames[d.active].bad=true end
  d.frames[header]={rows={},at=now(c),serial=d.serial};d.active=header;return nil
 end
 local f=d.active and d.frames[d.active]
 if f and line:match('^%-%-%-+%s*$') then
  if not f.separator then f.separator=true elseif not f.closed then f.closed=true;d.active=nil else f.bad=true end
  return nil
 end
 local rowkind=line:match('^(vial)') or line:match('^(pipe)') or line:match('^(bandage)')
 if rowkind then
  f=d.frames[rowkind]
  if not f then return nil end
  local a=fields(line);local id=a[1];local count=integer(a[3]);local decay=a[4]
  local valid=#a==(rowkind=='pipe' and 5 or 4) and id and #id<=32 and id:match('^'..rowkind..'%d+$') and count and (decay=='A' or integer(decay))
  valid=valid and (rowkind~='pipe' or a[5]=='Yes' or a[5]=='No')
  if not valid or d.active~=rowkind or not f.separator or f.closed or f.rows[id] then f.bad=true;return nil end
  local empty=a[2]=='empty'
  if (empty and count~=0) or (not empty and count==0) then f.bad=true;return nil end
  f.rows[id]={id=id,type=names[rowkind][a[2]],description=a[2],count=count,decay=decay=='A' and 'A' or integer(decay),lit=rowkind=='pipe' and a[5]=='Yes' or nil,observed_at=f.at}
 end
 return nil
end
function M.prompt(c)
 expire(c);local d=data(c)
 for _,k in ipairs(kinds) do
  local f=d.frames[k]
  if f then
   local s=d.sources[k] or {};d.sources[k]=s
   if f.separator and f.closed and not f.bad then
    local totals={}
    for _,r in pairs(f.rows) do if r.type then totals[r.type]=(totals[r.type] or 0)+r.count end end
    -- Known absent types become zero only after a complete native kind frame.
    for _,n in ipairs(required[k]) do
     local e=entry(d,k,n);e.count=totals[n] or 0;e.baseline=e.count;e.baseline_used=e.used
     e.baseline_delta=e.delta;e.at=f.at;e.observed_at=f.at;e.estimated=false;e.uncertain=nil;e.confidence='observed';e.unverified_pattern=nil
    end
    s.rows=f.rows;s.complete=true;s.at=f.at;s.confidence='observed'
   else s.confidence='malformed or incomplete frame' end
  end
 end
 d.frames={};d.active=nil;d.infuse=nil;d.infuse_ambiguous=nil
end
function M.invalidate(c)
 local d=data(c);d.frames={};d.active=nil;d.infuse=nil;d.infuse_ambiguous=nil
 for _,s in pairs(d.sources) do s.confidence='disconnected' end
 for _,group in pairs(d.carried) do for _,e in pairs(group) do e.confidence='disconnected';e.uncertain=true end end
 for _,e in pairs(d.cache) do e.confidence='disconnected' end
end
function M.state(c)
 expire(c);local d=data(c)
 local out={cache=copy(d.cache),carried=copy(d.carried),used=copy(d.used),refills=copy(d.refills),sources=copy(d.sources),issues={},complete=true,pending=next(d.frames)~=nil or d.infuse~=nil,estimated=true}
 for _,k in ipairs(kinds) do
  local s=d.sources[k];out.complete=out.complete and s~=nil and s.complete==true
  if not s or not s.complete then out.issues[#out.issues+1]=k..': baseline unknown'
  elseif s.confidence~='observed' then out.issues[#out.issues+1]=k..': '..s.confidence end
  if s and s.complete then
   for _,n in ipairs(required[k]) do
    local e=out.carried[k][n]
    if not e or e.count==0 then out.issues[#out.issues+1]=n..': missing/depleted '..k..' coverage' end
    if e and e.count and e.count>0 and e.count<=(c['containers_'..k..'_low'] or (k=='pipe' and 2 or 10))then out.issues[#out.issues+1]=n..': low ('..e.count..', tracked)'end
    if e and e.uncertain then out.issues[#out.issues+1]=n..': carried estimate uncertain' end
   end
   for id,r in pairs(s.rows or {}) do
    local row=out.sources[k].rows[id]
    if k=='pipe'and r.type and r.count>0 and not r.lit then out.issues[#out.issues+1]=id..': unlit (last observed)'end
    if type(r.decay)=='number' then
     row.days_remaining=math.max(0,r.decay-math.max(0,now(c)-r.observed_at)/86400)
     if row.days_remaining<5 then out.issues[#out.issues+1]=id..': expires in '..string.format('%.2f',row.days_remaining)..'d' end
    end
   end
  end
 end
 table.sort(out.issues);return out
end
return M
