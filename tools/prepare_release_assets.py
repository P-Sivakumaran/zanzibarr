"""Prepare one platform's draft assets from one source revision, without publishing."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import zipfile

ASSETS={
 'windows':{'zanzibarr-windows-x64.zip','zanzibarr-windows-x64-setup.exe'},
 'linux':{'zanzibarr-linux-x64.tar.gz','zanzibarr-linux-x64.deb'},
 'ios':{'zanzibarr-ios-unsigned.ipa'},
 'android':{f'zanzibarr-android-{abi}.apk' for abi in ('arm64-v8a','armeabi-v7a','x86_64','universal')},
}


def prepare(root, platform, source):
    if not re.fullmatch('[a-f0-9]{40}',source): raise ValueError('Expected a resolved source SHA')
    selected=set(ASSETS) if platform=='all' else {platform}
    if not selected <= set(ASSETS): raise ValueError('Unknown release platform')
    expected=set().union(*(ASSETS[item] for item in selected))
    if 'android' in selected:
        with zipfile.ZipFile(root/'zanzibarr-android.zip') as archive:
            entries=archive.infolist()
            if {entry.filename for entry in entries}!=ASSETS['android'] or len(entries)!=4:
                raise ValueError('Android archive has unexpected entries')
            for entry in entries:
                if entry.file_size>512*1024*1024: raise ValueError('APK exceeds package limit')
                target=root/entry.filename
                if target.exists() or target.is_symlink(): raise ValueError('APK destination already exists')
                with archive.open(entry) as src,target.open('wb') as dest: shutil.copyfileobj(src,dest)
    for name in expected:
        path=root/name
        if not path.is_file() or path.is_symlink(): raise ValueError('Missing or linked platform asset: '+name)
    # Only explicit assets are published; no wildcard can pick up another build.
    metadata=root/'SOURCE.json'
    if metadata.exists() or metadata.is_symlink() or (root/'SHA256SUMS').is_symlink():
        raise ValueError('Draft metadata destination already exists or is linked')
    metadata.write_text(json.dumps({'schema':1,'sourceSha':source,'platforms':sorted(selected),
        'state':'draft-candidate','publisherAuthenticated':False,'deviceValidated':False},indent=2)+'\n')
    files=sorted(expected|{'SOURCE.json'})
    lines=[]
    for name in files:
        value=hashlib.sha256()
        with (root/name).open('rb') as stream:
            while chunk:=stream.read(1024*1024): value.update(chunk)
        lines.append(f'{value.hexdigest()}  {name}\n')
    (root/'SHA256SUMS').write_text(''.join(lines))
    return files+['SHA256SUMS']


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform',choices=['all',*ASSETS],required=True)
    parser.add_argument('--source-sha',required=True)
    parser.add_argument('--directory',type=Path,default=Path('.'))
    args=parser.parse_args()
    files=prepare(args.directory,args.platform,args.source_sha)
    if 'GITHUB_OUTPUT' in os.environ:
        with open(os.environ['GITHUB_OUTPUT'],'a',encoding='utf-8') as output:
            output.write('files<<ZANZIBARR_ARTIFACTS\n'+'\n'.join(files)+'\nZANZIBARR_ARTIFACTS\n')
    print('Prepared',len(files),'draft assets; not published or authenticated')
if __name__=='__main__': main()
