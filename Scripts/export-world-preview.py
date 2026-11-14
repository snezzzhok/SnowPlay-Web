#!/usr/bin/env python3
"""Export owned native test frames, without recording a user's desktop."""
import json, subprocess
from pathlib import Path

root=Path(__file__).resolve().parents[1]
report=json.loads((root/'Docs/world-native-result.json').read_text())
count=report['framesRendered']
starts=sorted(report['chapterStartFrames'].values())
ends=starts[1:]+[count]
chosen={min(count-1,(start+end)//2) for start,end in zip(starts,ends)}
for title,start in report['chapterStartFrames'].items():
    if 'strikes' in title:
        end=ends[starts.index(start)]
        chosen.discard((start+end)//2)
        chosen.update([min(end-1,start+18),min(end-1,start+31)])
    if 'Snowplow' in title:chosen.add(min(count-1,start+60))
source=['ffmpeg','-v','error','-y','-framerate','12','-i',str(root/'.build/world-frames/frame-%04d.png')]
subprocess.run(source+['-vf',f'trim=end_frame={count},split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer',str(root/'Docs/world-native-preview.gif')],check=True)
subprocess.run(source+['-frames:v',str(count),'-c:v','libx264','-crf','22','-pix_fmt','yuv420p','-movflags','+faststart',str(root/'Docs/world-native-preview.mp4')],check=True)
select='+'.join(f'eq(n\\,{index})' for index in sorted(chosen))
subprocess.run(source+['-vf',f'select={select},scale=600:360,tile=3x3:padding=8:margin=8:color=0x152432','-frames:v','1',str(root/'Docs/world-native-contact-sheet.jpg')],check=True)
print(f'Exported {count} owned native frames in {len(starts)} chapters: GIF, MP4, contact sheet')
