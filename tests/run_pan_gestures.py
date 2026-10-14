"""Run gesture regressions against the built Defaults module in an isolated suite."""
from pathlib import Path
import os
import re
import subprocess

root = Path(__file__).resolve().parents[1]
work = root / "work"
products = work / "DerivedData/Build/Products/Release"
key = re.search(r'    static let normalizeGestureDirection = .*',
                (root / "boringNotch/models/Constants.swift").read_text()).group(0)
key = key.rsplit(")", 1)[0] + ', suite: UserDefaults(suiteName: "boring-notch-gesture-regression")!)'
source = work / "PanGestureRegressionTests.swift"
source.write_text((root / "boringNotch/extensions/PanGesture.swift").read_text()
                  + "\nextension Defaults.Keys {\n" + key + "\n}\n"
                  + (root / "tests/PanGestureTests.swift").read_text())
binary = work / "pan-gesture-tests"
subprocess.run(["swiftc", "-profile-generate", "-parse-as-library", "-I", str(products),
                str(source), str(products / "Defaults.o"), "-o", str(binary)], check=True)
subprocess.run([str(binary)], check=True,
               env={**os.environ, "LLVM_PROFILE_FILE": str(work / "pan-tests.profraw")})
