"""Build a test pak from the currently installed pak without changing source files."""
import zipfile
from pathlib import Path

root=Path(__file__).resolve().parents[1]
installed=Path(r'C:\Program Files\Steam\steamapps\common\KingdomComeDeliverance2\Mods\mercenaries\Data\mercenaries.pak')
backup=root/'tmp/collision-install-backup.pak'
if not backup.exists():
    backup.write_bytes(installed.read_bytes())
out=root/'tmp/collision-test.pak'
with zipfile.ZipFile(backup) as source, zipfile.ZipFile(out,'w',compression=zipfile.ZIP_STORED) as dest:
    for info in source.infolist():
        data=source.read(info.filename)
        if info.filename.replace('\\','/').lower()=='scripts/mods/mercenaries.lua':
            data+=b'\nScript.LoadScript("Scripts/mods/collision_probe.lua")\n'
        dest.writestr(info,data)
    dest.writestr('Scripts/mods/collision_probe.lua',(root/'tools/collision_runtime_probe.lua').read_bytes())
print(out, out.stat().st_size)
