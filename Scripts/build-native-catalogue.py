#!/usr/bin/env python3
"""Build the local visual catalogue from the same two manifests as AssetManager."""
from pathlib import Path
from collections import defaultdict
import json,html
root=Path(__file__).resolve().parents[1];art=root/'Sources/SnowPlay/Resources/SnowPlayAssets'
groups=defaultdict(list)
for path in [art/'manifest.json',art/'World/manifest.json']:
 for a in json.loads(path.read_text())['assets']:groups[a['category']].append(a['id'])
parts=['<!doctype html><html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SnowPlay — модели</title><link rel="stylesheet" href="/style.css"></head><body class="gallery"><nav><a href="/">← Пульт</a></nav><h1>Модели SnowPlay</h1><p>Оригинальные SVG и компоненты Living Winter. Превью подготовлены заранее для Retina.</p>']
for category,ids in groups.items():
 parts.append('<h2>'+html.escape(category)+'</h2><div class="model-grid">')
 for ident in ids:
  key=html.escape(ident,quote=True)
  parts.append(f'<article><img loading="lazy" src="/assets/{key}" alt="{key}"><small>{key}</small></article>')
 parts.append('</div>')
parts.append('</body></html>')
(root/'Sources/SnowPlay/Resources/Web/models.html').write_text('\n'.join(parts)+'\n')
print('Local catalogue:',sum(map(len,groups.values())),'registered assets')
