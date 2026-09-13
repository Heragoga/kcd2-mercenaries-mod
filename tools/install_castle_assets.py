"""Prepare/install a castle-only update while preserving the installed mod archive.

python tools/install_castle_assets.py prepare <installed-mercenaries.pak>
python tools/install_castle_assets.py install <installed-mercenaries.pak>
The install refuses to overwrite an archive that changed after preparation.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import zipfile

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'tmp/castle-rework/install'

def digest(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('mode',choices=['prepare','install'])
    ap.add_argument('target',type=Path)
    args=ap.parse_args();target=args.target.resolve()
    if target.name!='mercenaries.pak':raise ValueError('Expected the installed mercenaries.pak')
    WORK.mkdir(parents=True,exist_ok=True)
    prepared=WORK/'mercenaries.pak';record=WORK/'install.json'
    if args.mode=='prepare':
        files=list((ROOT/'data/Objects/mercenaries/walls').glob('merc_castle_*.cgf'))
        files+=list((ROOT/'data/Objects/mercenaries/walls').glob('merc_castle_*.mtl'))
        files+=[ROOT/'data/Scripts/mods/mercenaries_castle.lua']
        files+=[ROOT/('data/Scripts/mods/prefabs/wall_'+n+'_decor.lua') for n in ['castle_tower','castle_tower_hand']]
        updates={p.relative_to(ROOT/'data').as_posix().lower():p for p in files}
        before=digest(target)
        backup=WORK/('mercenaries-before-'+before[:12]+'.pak')
        if not backup.exists():shutil.copy2(target,backup)
        with zipfile.ZipFile(target) as old,zipfile.ZipFile(prepared,'w',compression=zipfile.ZIP_STORED) as new:
            for info in old.infolist():
                if info.filename.lower().replace('\\','/') not in updates:
                    new.writestr(info,old.read(info.filename))
            for p in updates.values():new.write(p,p.relative_to(ROOT/'data').as_posix())
        with zipfile.ZipFile(prepared) as z:
            assert z.testzip() is None
            for name,p in updates.items():assert z.read(p.relative_to(ROOT/'data').as_posix())==p.read_bytes()
        assert digest(target)==before,'Installed archive changed during preparation; prepare again'
        data={'target':str(target),'before_sha256':before,'prepared_sha256':digest(prepared),
              'backup':str(backup),'updated_entries':sorted(updates),'installed':False}
        record.write_text(json.dumps(data,indent=2));print(json.dumps(data,indent=2))
    else:
        data=json.loads(record.read_text())
        assert str(target)==data['target']
        assert digest(target)==data['before_sha256'],'Installed mod changed; prepare again'
        assert digest(prepared)==data['prepared_sha256']
        temporary=target.with_name('mercenaries.castle-update.tmp')
        assert temporary.resolve().parent==target.parent
        if temporary.exists():
            # A running game can deny the final rename. Reuse only the exact
            # verified temporary archive from that interrupted installation.
            assert digest(temporary)==data['prepared_sha256'],'Unexpected temporary archive'
        else:
            shutil.copy2(prepared,temporary)
        assert digest(temporary)==data['prepared_sha256']
        os.replace(temporary,target)
        assert digest(target)==data['prepared_sha256']
        data['installed']=True;record.write_text(json.dumps(data,indent=2))
        print('Installed castle update; original archive backed up at '+data['backup'])

if __name__=='__main__':main()
