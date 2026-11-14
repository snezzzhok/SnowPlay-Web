from pathlib import Path
import subprocess,plistlib
root=Path(__file__).resolve().parents[1]
product=(root/'Sources/SnowPlay/main.swift').read_text().split('\nlet app=NSApplication.shared')[0]
(root/'.build/LiveMacCheck.swift').write_text(product+'\n'+(root/'Scripts/LiveMacCheck.swift').read_text())
app=root/'.build/SnowPlayLiveCheck.app';(app/'Contents/MacOS').mkdir(parents=True,exist_ok=True)
(app/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'local.snowplay.livecheck','CFBundleName':'SnowPlayLiveCheck','CFBundleDisplayName':'SnowPlay Live Check','CFBundleExecutable':'SnowPlayLiveCheck','CFBundlePackageType':'APPL','NSHighResolutionCapable':True,'NSPrincipalClass':'NSApplication','LSMinimumSystemVersion':'13.0'}))
subprocess.run(['python3','Scripts/compile-native-check.py','.build/LiveMacCheck.swift',str(app/'Contents/MacOS/SnowPlayLiveCheck'),'--release'],cwd=root,check=True)
subprocess.run(['codesign','--force','--sign','-',str(app)],check=True)
