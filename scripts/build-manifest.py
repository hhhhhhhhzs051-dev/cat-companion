import datetime,hashlib,json,subprocess,sys,plistlib
from pathlib import Path
def run(*args):return subprocess.check_output(args,text=True).strip()
def public_commit():
    if not Path('.git').exists(): return 'source-archive'
    result=subprocess.run(['git','rev-parse','--verify','HEAD'],capture_output=True,text=True)
    return result.stdout.strip() if result.returncode==0 else 'uncommitted-public-snapshot'
def public_dirty():
    if public_commit() in {'source-archive', 'uncommitted-public-snapshot'}: return True
    return bool(run('git','status','--porcelain','--untracked-files=normal'))
files=sorted(p for p in Path('src').rglob('*') if p.is_file())
version=Path('VERSION').read_text(encoding='utf-8').strip()
manifest={'version':version,'commit':public_commit(),'dirty':public_dirty(),'built_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'sdk':run('xcrun','--show-sdk-version'),'swift':run('swiftc','--version'),'host_os':run('sw_vers','-productVersion'),'deployment_target':'14.0','architectures':['arm64','x86_64'],'source_sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}}
destination=Path(sys.argv[1])
manifest['swift_defines']=['CAT_PAW_EXPERIMENT','CAT_ACCESSORY_GAZE','CAT_EYE_INTERACTION','CAT_PUPIL_PLAY','CAT_PUPIL_RECOVERY','CAT_EYE_HANDOFF','CAT_GRAB_HANDOFF']
sequence=Path(sys.argv[2])/'.build-sequence'
number=int(sequence.read_text())+1 if sequence.exists() else 1
if number>9999:raise RuntimeError('Bump release version and reset build sequence explicitly')
sequence.write_text(str(number))
plist_path=destination.parent.parent/'Info.plist'
info=plistlib.loads(plist_path.read_bytes());info['CFBundleVersion']=str(number)
plist_path.write_bytes(plistlib.dumps(info))
manifest['build_number']=number
Path(sys.argv[1]).write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
