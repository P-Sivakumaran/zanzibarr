"""Record source, lockfiles, dependencies and exact packaged bytes; not signing."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import platform as host_platform
import shutil


def digest(path):
    value=hashlib.sha256()
    with path.open('rb') as stream:
        while chunk:=stream.read(1024*1024): value.update(chunk)
    return value.hexdigest()


def tool_versions():
    result={}
    for name,args in [('rustc',['--version']),('flutter',['--version','--machine'])]:
        executable=shutil.which(name)
        if not executable:
            result[name]=None
            continue
        try:
            process=subprocess.run([executable,*args],capture_output=True,text=True,timeout=15)
            text=process.stdout.strip()
            if process.returncode!=0 or len(text)>=8192:
                result[name]=None
            elif name=='flutter':
                data=json.loads(text)
                # Do not retain repository URLs, local paths or arbitrary tool output.
                result[name]={key:data.get(key) for key in ('frameworkVersion','frameworkRevision','engineRevision','dartSdkVersion','devToolsVersion')}
            else:
                result[name]=text
        except (OSError,subprocess.TimeoutExpired,ValueError):
            result[name]=None
    return result


def collect(root, artifacts, output, platform):
    if not artifacts.is_dir(): raise ValueError('Artifact directory is missing')
    paths=[path for path in sorted(artifacts.rglob('*')) if path.is_file() and path.resolve()!=output.resolve()]
    if not paths: raise ValueError('No artifacts to inventory')
    for path in paths:
        if path.is_symlink() or not path.resolve().is_relative_to(artifacts.resolve()):
            raise ValueError('Artifact link escapes package')
    lockfiles={name:digest(root/name) for name in ('pubspec.lock','rust/Cargo.lock','tools/build-toolchains.json')}
    cargo=(root/'rust/Cargo.lock').read_text(encoding='utf-8')
    packages=[]
    for record in cargo.split('[[package]]')[1:]:
        name=re.search(r'^name = "([^"]+)"',record,re.M)
        version=re.search(r'^version = "([^"]+)"',record,re.M)
        if name and version: packages.append({'ecosystem':'cargo','name':name[1],'version':version[1]})
    dart=(root/'pubspec.lock').read_text(encoding='utf-8')
    for record in re.finditer(r'^  ([a-zA-Z0-9_]+):\n(.*?)(?=^  \S|^sdks:)',dart,re.M|re.S):
        version=re.search(r'^    version: "?([^"\n]+)',record[2],re.M)
        if version: packages.append({'ecosystem':'pub','name':record[1],'version':version[1]})
    return {'schema':1,'kind':'build-dependency-and-artifact-inventory',
        'sourceBinding':'observed checkout context only; not a signed build attestation',
        'sourceRevisionObserved':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),
        'dirty':bool(subprocess.check_output(['git','status','--porcelain'],cwd=root,text=True).strip()),
        'platform':platform,'hostOs':host_platform.platform(),'actualToolVersions':tool_versions(),'lockfiles':lockfiles,'declaredToolchains':json.loads((root/'tools/build-toolchains.json').read_text()),
        'dependencies':packages,'artifacts':{path.relative_to(artifacts).as_posix():digest(path) for path in paths},
        'nativeLicenseAndSourceInventoryComplete':False,'publisherAuthenticated':False,'deviceValidated':False}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifacts',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--platform',choices=['windows-x64','linux-x64','android','ios'],required=True)
    args=parser.parse_args()
    report=collect(Path(__file__).resolve().parents[1],args.artifacts,args.output,args.platform)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(len(report['dependencies']),'locked dependencies;',len(report['artifacts']),'artifact hashes; not publisher authenticated')

if __name__=='__main__': main()
