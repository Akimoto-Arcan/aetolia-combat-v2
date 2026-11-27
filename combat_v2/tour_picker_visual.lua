-- Display-only decoration. Retain selection, query, grant and click handlers.
local function esc(v)return(tostring(v or ''):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'):gsub('"','&quot;'))end
return function(p)
 assert(p and p.owner and p.owner.tour_picker==p,'exact picker owner required')
 assert(not p.visual_style,'visual style already attached')
 local old=p.render;local info=debug.getinfo(old,'S')
 assert(info.source=='@combat-v2-tour-picker'and info.linedefined==169,'unexpected picker renderer')
 local function paint(v)
  if not v or v.cancelled or not v.widget then return end
  local ww,hh=getMainWindowSize();local width=math.min(1080,ww-64);local height=720
  v.widget:move(math.floor((ww-width)/2),math.max(24,math.floor((hh-height)/2)));v.widget:resize(width,height)
  local W=width-48
  if not p.visual_background then
   p.visual_background=Geyser.Label:new({name='CombatV2TourPickerCard',x=0,y=0,width='100%',height='100%'},v.widget)
   p.visual_background:setStyleSheet('background-color:#101c2a;border:2px solid #516880;border-radius:12px;')
   p.visual_background:echo('')
   p.visual_summary=Geyser.Label:new({name='CombatV2TourPickerSummary',x=24,y=620,width=W,height=28},v.widget)
   p.visual_close=Geyser.Label:new({name='CombatV2TourPickerClose',x=width-66,y=18,width=42,height=38},v.widget)
   p.visual_close:setClickCallback(function()p.cancel()end)
  end
  p.visual_background:show();p.visual_background:raise()
  local function text(l,value,size,color,bold)
   l:echo('<span style="font-family:DejaVu Sans;font-size:'..size..'px;color:'..color..';'..(bold and 'font-weight:600;'or '')..'">'..value..'</span>')
  end
  local function label(name,x,y,w,h,value,size,color,background,border)
   local l=assert(p.widgets['CombatV2TourPicker_'..name],name)
   l:move(x,y);l:resize(w,h)
   l:setStyleSheet('background-color:'..background..';color:'..color..';border:'..(border or 'none')..';border-radius:5px;padding-left:10px;padding-right:10px;')
   text(l,value,size,color);l:show();l:raise();return l
  end
  label('title',24,16,W-64,42,'Bash tour <b>'..v.lo..'–'..v.hi..'</b>',25,'#f3f7fc','#101c2a')
  label('notice',24,65,W,34,esc(v.error or (v.plan and 'Choose areas below. Unchecked areas will be skipped.'or 'Loading available areas…')),16,v.error and '#ffbc86'or '#aabed2','#101c2a')
  local entries=v.entries or {};local selected=0
  for _,slot in ipairs(v.plan and v.plan.ready or {})do if v.selected[slot.row.name..'\0'..slot.row.entry..'\0'..slot.row.rating]then selected=selected+1 end end
  for i=1,10 do
   local slot=entries[(v.page-1)*10+i]
   if slot then
    local r=slot.row;local ready=slot.status=='ready';local checked=v.selected[r.name..'\0'..r.entry..'\0'..r.rating]==true
    local icon=ready and(checked and '☑'or '☐')or '—'
    local status=ready and(checked and 'Selected'or 'Excluded')or(slot.status=='unsupported'and 'Unavailable'or slot.status=='unmapped'and (tonumber(r.entry)==0 and 'No entrance'or 'Unmapped')or slot.status)
    local right
    if ready then
     local g=slot.graph or {};local n=g.room_count or 0
     right=n..' / '..tostring(g.mapped_count or '?')..' rooms'..(n<(g.mapped_count or n)and ' · partial'or '')
    else
     local reason=tostring(slot.reason or '')
     if reason:find('no reviewed',1,true)then right='No hunting preset'
     elseif reason:find('private reviewed',1,true)then right='Private room list required'
     elseif reason:find('entry mapper',1,true)then right='Entry mismatch'
     elseif reason:find('terrain unsupported',1,true)then right='Terrain unsupported'
     elseif reason:match('^mapped entrance locked')then right='Entrance locked'
     elseif reason:match('^mapped entrance weight')then right='Entrance weight unsupported'
     elseif reason:find('unknown or blocked',1,true)then right='No safe mapped entrance'
     elseif tonumber(r.entry)==0 then right='Server supplies no entrance'
     elseif reason:match('^unmapped entrance')then right='Entrance absent from loaded map'
     else right=reason end
    end
    local color=ready and '#edf4fc'or '#879caf'
    local accent=ready and(checked and '#74d9b1'or '#e8b36a')or '#879caf'
    local row='<table width="100%" cellspacing="0" cellpadding="0"><tr><td width="5%"><span style="font-size:23px;color:'..accent..'">'..icon..'</span></td><td width="45%"><span style="font-size:16px;color:'..color..'">'..esc(r.rating..'  '..r.name)..'</span></td><td width="15%"><span style="font-size:14px;color:'..accent..'">'..esc(status)..'</span></td><td width="35%" align="right"><span style="font-size:14px;color:#9db2c8">'..esc(right)..'</span></td></tr></table>'
    local l=label('row'..i,24,111+(i-1)*45,W,42,row,16,color,ready and '#203449'or(i%2==0 and '#172636'or '#1a2b3c'))
    l:setToolTip(tostring(slot.reason or (ready and 'Click to include or exclude this area.'or slot.status)))
   end
  end
  label('all',24,575,190,36,'Select available',15,'#d9e7f5','#283f54','1px solid #47617b')
  label('none',224,575,145,36,'Clear selection',15,'#d9e7f5','#283f54','1px solid #47617b')
  label('prev',width-354,575,150,36,'‹ Previous',15,'#d9e7f5','#283f54','1px solid #47617b')
  label('next',width-194,575,170,36,'Next page ›',15,'#d9e7f5','#283f54','1px solid #47617b')
  label('cancel',24,660,230,40,'Cancel',17,'#d9e7f5','#283f54','1px solid #47617b')
  label('start',width-350,660,326,40,'Start Bash Tour  →',18,'#f2fff8','#237251','1px solid #59b98e')
  p.visual_summary:move(24,620);p.visual_summary:resize(W,28)
  p.visual_summary:setStyleSheet('background-color:#101c2a;border:none;')
  text(p.visual_summary,selected..' selected  ·  '..#entries..' areas  ·  Page '..v.page..' of '..math.max(1,math.ceil(#entries/10))..'   |   Ia’shal Barrow starts excluded.',14,'#aabed2')
  p.visual_summary:show();p.visual_summary:raise()
  p.visual_close:move(width-66,18);p.visual_close:setStyleSheet('background-color:#263b50;border:none;border-radius:5px;')
  text(p.visual_close,'×',26,'#dae7f5');p.visual_close:show();p.visual_close:raise()
 end
 p.visual_style={original_render=old,version=2,paint=paint}
 p.render=function(v)old(v);paint(v)end
 if p.view then p.render(p.view)end
 return p.visual_style
end
