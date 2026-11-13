import Foundation
import IOKit.pwr_mgt
import Observation
import HerdrToolsCore

/// Keeps the Mac awake until the chosen time runs out.
/// The power assertion is released by macOS when the process exits.
@MainActor @Observable final class SleepBlocker {
    static let minuteChoices = [30, 60, 120, 180, 240, 480, 960, 1440]
    private static let displayKey = "keepDisplayAwake"

    /// Countdown text such as "2h 12m"; nil while the Mac may sleep.
    private(set) var label: String?
    var message: String?
    var keepsDisplayAwake: Bool {
        didSet {
            defaults.set(keepsDisplayAwake, forKey: Self.displayKey)
            if end != nil { holdAssertion() }
        }
    }
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var assertion: IOPMAssertionID?
    @ObservationIgnored private var end: Date?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        keepsDisplayAwake = defaults.object(forKey: Self.displayKey) as? Bool ?? true
    }

    func start(minutes: Int) {
        end = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        holdAssertion()
        guard assertion != nil else { return }
        refresh()
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.refresh()
            }
        }
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
        end = nil
        releaseAssertion()
        label = nil
    }

    private func refresh() {
        guard let end else { return }
        let remaining = end.timeIntervalSinceNow
        guard remaining > 0 else { stop(); return }
        let text = AwakeText.remaining(remaining)
        // Observation fires on every set, so skip writes that would not change the text.
        if text != label { label = text }
    }

    private func holdAssertion() {
        releaseAssertion()
        let type = keepsDisplayAwake ? kIOPMAssertionTypePreventUserIdleDisplaySleep
                                     : kIOPMAssertionTypePreventUserIdleSystemSleep
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                 "Herdr Tools keep awake" as CFString, &id)
        if result == kIOReturnSuccess {
            assertion = id
        } else {
            stop()
            message = "Could not keep the Mac awake (IOKit error \(result))."
        }
    }

    private func releaseAssertion() {
        if let assertion { IOPMAssertionRelease(assertion) }
        assertion = nil
    }
}
