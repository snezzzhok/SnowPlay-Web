#!/usr/bin/env python3
"""Verify the anonymous static deployment and every original vector checksum."""
import argparse,hashlib,json,subprocess,re
from pathlib import Path
from urllib.parse import urljoin

parser=argparse.ArgumentParser()
parser.add_argument('url',nargs='?',default='https://snezzzhok.github.io/SnowPlay-Web/')
parser.add_argument('--out',default='Docs/pages-deployment-result.json')
args=parser.parse_args();base=args.url.rstrip('/')+'/'
def get(path):
    return subprocess.check_output(['curl','--fail','--silent','--show-error','--max-time','20',urljoin(base,path)])
html=get('./');assert b'/api/' not in html,'Public page must not require the native server'
registry=json.loads(get('assets/manifest.json'));assets=[]
for entry in registry['assets']:
    body=get('assets/'+entry['svg'])
    assert hashlib.sha256(body).hexdigest()==entry['sha256'],entry['id']
    assets.append({'id':entry['id'],'status':200,'sha256Matches':True})
for name in ['app.js','assets.js','scene.js','renderer.js','style.css']:
    body=get(name)
    local=Path(__file__).resolve().parents[1]/'Web'/name
    normalized=re.sub(rb'(\./[A-Za-z0-9_-]+\.js)\?v=[a-f0-9]{12}',rb'\1',body)
    assert hashlib.sha256(normalized).digest()==hashlib.sha256(local.read_bytes()).digest(),f'Outdated deployment: {name}'
result={'url':base,'anonymousHTTP':True,'htmlStatus':200,'assetCount':len(assets),'allHashesMatch':True,'scriptsMatchCurrentSource':True,'assets':assets,'sourceRepository':'https://github.com/snezzzhok/SnowPlay-Web'}
Path(args.out).write_text(json.dumps(result,indent=2)+'\n')
print(f'PASS: anonymous deployment, current scripts/styles and {len(assets)} original SVGs; all hashes match')
