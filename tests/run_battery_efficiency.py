#!/usr/bin/env python3
"""Compile production owners with inert adapters; no app launch/live storage.
Only external dependencies are substituted. Source extraction fails on drift.
"""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
out = root / 'work/battery-efficiency/harness'
out.mkdir(parents=True, exist_ok=True)
def source(path): return (root / path).read_text()
def write(name, text):
    path = out / name
    path.write_text(text)
    return str(path)
files = [str(root / p) for p in [
    'boringNotch/components/Today/TodayPayload.swift',
    'boringNotch/components/Today/TodayBridgeStatus.swift',
    'boringNotch/components/Today/TodaySchedule.swift',
    'boringNotch/components/Today/TodayStore.swift',
    'boringNotch/models/CameraModel.swift',
    'boringNotch/components/Shelf/ViewModels/ShelfStateViewModel.swift',
    'boringNotch/components/Shelf/Services/ShelfPersistenceService.swift',
    'tests/BatteryEfficiencyStubs.swift', 'tests/BatteryEfficiencyTests.swift']]
engine = source('boringNotch/managers/CameraSessionEngine.swift')
files += [write('CameraTypes.swift', engine[:engine.index('/// Owns AVFoundation')])]
calendar = source('boringNotch/managers/CalendarManager.swift').replace('import Defaults\n', '')
# os.Logger privacy interpolation depends on the logging adapter, not query behavior.
calendar = calendar.replace(', privacy: .public', '')
files += [write('CalendarManager.swift', calendar)]
youtube = source('boringNotch/MediaControllers/YouTubeMusicController/YouTubeMusicController.swift')
a = youtube.index('    func requestPeriodicUpdate(')
b = youtube.index('    private func stopPeriodicUpdates()', a)
files += [write('PeriodicOwner.swift', 'import Foundation\n@MainActor final class PeriodicOwner {\nvar periodicUpdateTask: Task<Void, Never>?\nvar operation: (@MainActor () async -> Void)?\nfunc updatePlaybackInfo() async { await operation?() }\n' + youtube[a:b] + '\n}\n')]
# Exercise the actual audio demand/evaluate methods with inert PID/capture adapters.
audio = source('boringNotch/managers/AudioCaptureManager.swift')
a = audio.index('    var visibleConsumerCount:')
b = audio.index('    private func reevaluateDemand()', a)
c = audio.index('    private func evaluate(')
d = audio.index('    private func stopCaptureAsync()', c)
files += [write('AudioDemandOwner.swift', 'import AppKit\nimport Foundation\nprotocol AudioCaptureLevelsConsumer: AnyObject {}\nfinal class AudioDemandOwner {\nlet levelsConsumerLock = NSLock()\nlet levelsConsumers = NSHashTable<AnyObject>.weakObjects()\nlet lifecycleQueue = DispatchQueue(label: "fake.audio")\nvar starts = 0\nvar stops = 0\nvar capturing = false\nfunc resolvePIDs(displayBundleID: String, captureBundleIDs: [String]) -> [pid_t] { [1] }\nfunc startCaptureOnLifecycleQueue(pids: [pid_t]) { if !capturing { starts += 1; capturing = true } }\nfunc stopCaptureAsync() { lifecycleQueue.async { if self.capturing { self.stops += 1; self.capturing = false } } }\nfunc reevaluateDemand() { evaluate(isPlaying: true, displayBundleID: "fake", captureBundleIDs: [], enabled: true) }\nfunc drain() { lifecycleQueue.sync {} }\n' + audio[a:b] + audio[c:d] + '\n}\n')]
# Existing camera regression slice runs against the production model, with an inert default engine.
camera = source('boringNotchTests/CameraLifecycleTests.swift').replace('@testable import boringNotch', '').replace('import XCTest', '')
files += [write('CameraLifecycleTests.swift', camera)]
names = re.findall(r'    func (test\w+)\(\)', camera)
files += [write('RunCamera.swift', '@MainActor func runCameraRegressions() {\nlet suite = CameraLifecycleTests()\n' + '\n'.join(f'suite.{name}()' for name in names) + f'\nprint("Camera regression slice: {len(names)} tests PASS")\n}}\n')]
subprocess.run(['swiftc', '-parse-as-library', '-o', str(out / 'checks'), *files], check=True, cwd=root)
subprocess.run([str(out / 'checks')], check=True, cwd=root)
