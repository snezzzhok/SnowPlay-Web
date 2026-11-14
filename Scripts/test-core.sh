#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if xcodebuild -version >/dev/null 2>&1; then
  exec swift test
fi
Scripts/local-build.sh build
python3 - <<'PY'
from pathlib import Path
import re
lines=['import Foundation','@main struct TestRunner {','static func main() throws {','var count=0']
for p in sorted(Path('Tests/SnowCoreTests').glob('*.swift')):
 text=p.read_text(); cls=re.search(r'final class (\w+)',text)[1]
 lines.append(f'let {cls.lower()}={cls}()')
 for method in re.findall(r'func (test\w+)\(',text):
  lines += [f'print("RUN {cls}.{method}")',f'try {cls.lower()}.{method}()', 'count+=1']
lines += ['print("\\(count) test methods; \\(assertionFailures) assertion failures")','exit(assertionFailures == 0 ? 0:1)','}','}']
Path('.build/TestRunner.swift').write_text('\n'.join(lines))
PY
.build/toolchain/swiftc -sdk "$(xcrun --show-sdk-path)" -target arm64-apple-macosx13.0 -suppress-warnings -enable-testing -I .build/debug/Modules Scripts/XCTestFallback.swift Tests/SnowCoreTests/*.swift .build/TestRunner.swift .build/debug/SnowCore.build/*.o -o .build/core-tests
.build/core-tests
