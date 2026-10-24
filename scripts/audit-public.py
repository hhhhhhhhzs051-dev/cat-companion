"""Scan distributable files; print classifications and locations, never values."""
from pathlib import Path
import hashlib,json,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
PATTERNS={
 'personal-root': re.compile(rb'/(?:Users|Volumes)/[^\s\x00\"\x27]+'),
 'email-address': re.compile(rb'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
 'github-token': re.compile(rb'(?:gh[pousr]_[A-Za-z0-9_]{30,}|github_pat_[A-Za-z0-9_]{30,})'),
 'api-secret': re.compile(rb'\bsk-(?:proj-)?[A-Za-z0-9_-]{30,}'),
 'aws-key': re.compile(rb'\bAKIA[0-9A-Z]{16}\b'),
 'private-key': re.compile(rb'-----BEGIN (?:RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----'),
 'credential-url': re.compile(rb'(?:https?|postgres(?:ql)?|mysql|mongodb)://[^\s/:]+:[^\s/@]+@'),
 'jwt': re.compile(rb'\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'),
 'password-assignment': re.compile(rb'(?i)(?:password|api_key|access_token)\s*[=:]\s*[\"\x27][A-Za-z0-9_+/=-]{20,}[\"\x27]'),
}
DENIED_SUFFIXES={'.pem','.key','.p12','.pfx','.sqlite','.sqlite3','.db','.log','.zip','.dmg','.pyc'}
def main():
 if (ROOT/'.git').exists():
  result=subprocess.run(['git','ls-files','--cached','--others','--exclude-standard','-z'],cwd=ROOT,capture_output=True,check=True)
  files=sorted(set(x.decode() for x in result.stdout.split(b'\0') if x))
 else:
  generated={'.git','.build','reports','node_modules','__pycache__'}
  files=sorted(str(p.relative_to(ROOT)) for p in ROOT.rglob('*') if p.is_file() and not any(part in generated for part in p.relative_to(ROOT).parts))
 findings=[];inventory=[]
 for rel in files:
  path=ROOT/rel
  if path.is_symlink():
   findings.append({'file':rel,'type':'symlink'});continue
  if not path.is_file():continue
  if path.suffix.lower() in DENIED_SUFFIXES or any(p in {'.git','data','logs','node_modules','__pycache__','.private'} for p in Path(rel).parts) or path.name.startswith('.env'):
   findings.append({'file':rel,'type':'excluded-file-type'})
  data=path.read_bytes()
  inventory.append({'file':rel,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
  if path.suffix.lower() not in {'.png','.icns'}:
   for name,pattern in PATTERNS.items():
    for match in pattern.finditer(data):findings.append({'file':rel,'line':data.count(b'\n',0,match.start())+1,'type':name})
  if path.suffix.lower()=='.png':
   position=8
   while position+12<=len(data):
    size=int.from_bytes(data[position:position+4],'big');kind=data[position+4:position+8]
    if kind in {b'tEXt',b'iTXt',b'zTXt',b'eXIf',b'caBX'}:findings.append({'file':rel,'type':'image-metadata-needs-review','chunk':kind.decode()})
    position+=12+size
 report={'file_count':len(inventory),'total_bytes':sum(x['bytes'] for x in inventory),'findings':findings,'inventory':inventory}
 print(json.dumps(report,ensure_ascii=False,indent=2))
 return bool(findings)
if __name__=='__main__':sys.exit(main())
