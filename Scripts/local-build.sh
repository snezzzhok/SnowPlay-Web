#!/bin/bash
# Local workaround for this host's mixed Command Line Tools installation.
# Does not alter /Library/Developer or system caches. Normal Xcode: use swift build/test.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/toolchain
python3 - <<'PY'
import json,os
root='/Library/Developer/CommandLineTools/usr'
empty=os.path.abspath('.build/toolchain/empty.modulemap')
open(empty,'w').write('// Mask duplicate legacy SwiftBridging definition\n')
entries=[{'type':'file','name':root+'/include/'+case+'/module.modulemap','external-contents':empty} for case in ['swift','Swift']]
import shutil
local=os.path.abspath('.build/toolchain/ManifestAPI')
os.makedirs(local+'/PackageDescription.swiftmodule',exist_ok=True)
for arch in ['arm64','x86_64']:
    p=f'{root}/lib/swift/pm/ManifestAPI/PackageDescription.swiftmodule/{arch}-apple-macos'
    for suffix in ['.swiftinterface','.private.swiftinterface']:
        shutil.copyfile(p+'.swiftinterface',local+f'/PackageDescription.swiftmodule/{arch}-apple-macos'+suffix)
json.dump({'version':0,'roots':entries},open('.build/toolchain/overlay.json','w'))
PY
cat > .build/toolchain/swiftc <<EOF2
#!/bin/bash
exec /Library/Developer/CommandLineTools/usr/bin/swiftc -I "$PWD/.build/toolchain/ManifestAPI" -vfsoverlay "$PWD/.build/toolchain/overlay.json" "\$@"
EOF2
chmod +x .build/toolchain/swiftc
export SWIFT_EXEC="$PWD/.build/toolchain/swiftc"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/local-module-cache"
exec swift "${@:-build}"
