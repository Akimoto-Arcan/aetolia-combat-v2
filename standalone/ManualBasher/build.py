from pathlib import Path
import hashlib,json,shutil,xml.etree.ElementTree as ET
p=Path(__file__).resolve().parent
for name in ('mobs.lua','mobs.json','source-manifest.json'):
    assert (p/name).is_file(), 'Missing bundled source data: '+name
core=(p/'ManualBasher.lua').read_text(); db=(p/'mobs.lua').read_text(); installer=(p/'install.lua').read_text()
bundle='local Factory=(function()\n'+core+'\nend)()\nlocal DB=(function()\n'+db+'\nend)()\n'+installer
(p/'ManualBasher-bundled.lua').write_text(bundle)
r=ET.Element('MudletPackage',{'version':'1.001'})
sp=ET.SubElement(r,'ScriptPackage');sg=ET.SubElement(sp,'ScriptGroup',{'isActive':'yes','isFolder':'yes'})
ET.SubElement(sg,'name').text='ManualBasher';ET.SubElement(sg,'packageName').text='ManualBasher';ET.SubElement(sg,'script')
s=ET.SubElement(sg,'Script',{'isActive':'yes','isFolder':'no'})
ET.SubElement(s,'name').text='ManualBasher bootstrap';ET.SubElement(s,'packageName').text='ManualBasher';ET.SubElement(s,'script').text=bundle;ET.SubElement(s,'eventHandlerList')
ET.ElementTree(r).write(p/'ManualBasher.xml',encoding='utf-8',xml_declaration=True)
parsed=ET.parse(p/'ManualBasher.xml').find('.//Script/script').text
assert parsed==bundle
presets=json.loads((p/'mobs.json').read_text())
# Catalog schema is an array or object; source remains byte-for-byte copied.
(p/'SHA256SUMS').write_text(''.join(hashlib.sha256(f.read_bytes()).hexdigest()+'  '+f.name+'\n' for f in sorted(p.iterdir()) if f.is_file() and f.name not in ('SHA256SUMS','backup.log')))
with (p/'backup.log').open('a') as f:
    for target in sorted(p.iterdir()):
        if target.is_file(): f.write('CREATE/EDIT offline artifact '+str(target)+' sha256='+hashlib.sha256(target.read_bytes()).hexdigest()+'\n')
print('XML parsed; bundled script exact roundtrip; self-contained; '+str(p/'ManualBasher.xml'))
print('XML sha256 '+hashlib.sha256((p/'ManualBasher.xml').read_bytes()).hexdigest())
