// Compile after concatenating with PanGesture.swift so these regression tests
// exercise the private production coordinator without exposing it to the app.
import CoreGraphics

@MainActor
extension ScrollMonitor.Coordinator {
    static func runRegressionTests() {
        func event(
            x: Int32 = 0,
            y: Int32 = 0,
            phase: NSEvent.Phase = [],
            momentum: NSEvent.Phase = []
        ) -> NSEvent {
            let cgEvent = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 2,
                wheel1: y,
                wheel2: x,
                wheel3: 0
            )!
            // Core Graphics uses different phase values from NSEvent.Phase.
            let touchValue: Int64 = phase == .began ? 1 : phase == .changed ? 2 : phase == .ended ? 4 : phase == .cancelled ? 8 : 0
            let momentumValue: Int64 = momentum == .began ? 1 : momentum == .changed ? 2 : momentum == .ended ? 3 : 0
            cgEvent.setIntegerValueField(.scrollWheelEventScrollPhase, value: touchValue)
            cgEvent.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentumValue)
            let result = NSEvent(cgEvent: cgEvent)!
            precondition(result.phase == phase && result.momentumPhase == momentum, "Invalid test event phases")
            return result
        }

        var phases: [NSEvent.Phase] = []
        let down = ScrollMonitor.Coordinator(direction: .down, threshold: 4) { _, phase in
            phases.append(phase)
        }
        defer { down.removeMonitor() }

        down.handleScroll(event(y: 10, phase: .began))
        down.handleScroll(event(y: 10, phase: .changed))
        down.handleScroll(event(phase: .ended))
        precondition(phases == [.began, .changed, .ended], "Touch gesture must still work")

        phases.removeAll()
        down.handleScroll(event(y: 100, momentum: .began))
        down.handleScroll(event(y: 100, momentum: .changed))
        precondition(phases.isEmpty, "A flick's momentum must not start another gesture")
        down.handleScroll(event(momentum: .ended))
        precondition(phases.isEmpty, "Momentum completion must not emit a second end callback")

        phases.removeAll()
        down.handleScroll(event(y: 10, phase: .began))
        precondition(phases == [.began], "The next real swipe must remain responsive")
        down.handleScroll(event(phase: .ended))

        phases.removeAll()
        down.handleScroll(event(y: 10, phase: .began))
        down.handleScroll(event(phase: .ended, momentum: .began))
        down.handleScroll(event(y: 100, momentum: .changed))
        down.handleScroll(event(momentum: .ended))
        precondition(phases == [.began, .ended], "A real touch ending with momentum must end exactly once")

        phases.removeAll()
        down.handleScroll(event(y: 10, phase: .began))
        down.handleScroll(event(phase: .cancelled))
        down.handleScroll(event(y: 10, phase: .began))
        precondition(phases == [.began, .ended, .began], "Cancellation must release the active gesture")
        down.handleScroll(event(phase: .ended))

        phases.removeAll()
        down.handleScroll(event(x: 40, y: 10, phase: .began))
        precondition(phases.isEmpty, "Horizontal scrolling must not open the notch")
        down.handleScroll(event(phase: .ended))

        var upwardBegins = 0
        let up = ScrollMonitor.Coordinator(direction: .up, threshold: 4) { _, phase in
            if phase == .began { upwardBegins += 1 }
        }
        defer { up.removeMonitor() }
        up.handleScroll(event(y: -10, phase: .began))
        up.handleScroll(event(phase: .ended))
        up.handleScroll(event(y: -100, momentum: .began))
        up.handleScroll(event(y: -100, momentum: .changed))
        precondition(upwardBegins == 1, "Upward flick must also produce just one gesture")

        print("Pan gesture regression tests passed")
    }
}

@main
struct PanGestureRegressionTests {
    @MainActor static func main() {
        ScrollMonitor.Coordinator.runRegressionTests()
    }
}
