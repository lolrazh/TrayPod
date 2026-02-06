import Foundation
import IOKit.ps

class BatteryService: ObservableObject {
    static let shared = BatteryService()

    @Published private(set) var batteryLevel: Float = 1.0  // 0.0 – 1.0
    @Published private(set) var isCharging: Bool = false
    @Published private(set) var hasBattery: Bool = false

    private var runLoopSource: CFRunLoopSource?

    private init() {
        updateBatteryInfo()
        startMonitoring()
    }

    // MARK: - Event-driven monitoring (no polling)
    // IOPSNotificationCreateRunLoopSource fires its callback on any
    // power-source change: level tick, charging state, AC connect/disconnect.

    private func startMonitoring() {
        let context = Unmanaged.passUnretained(self).toOpaque()

        guard let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx = ctx else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async {
                service.updateBatteryInfo()
            }
        }, context)?.takeRetainedValue() else { return }

        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    private func updateBatteryInfo() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

        guard !sources.isEmpty else {
            // No battery (iMac, Mac mini, Mac Pro) — always show full
            batteryLevel = 1.0
            isCharging = false
            hasBattery = false
            return
        }

        hasBattery = true

        guard let info = IOPSGetPowerSourceDescription(
            snapshot, sources[0]
        )?.takeUnretainedValue() as? [String: Any] else {
            batteryLevel = 1.0
            return
        }

        let current = info[kIOPSCurrentCapacityKey as String] as? Int ?? 100
        let max = info[kIOPSMaxCapacityKey as String] as? Int ?? 100
        batteryLevel = max > 0 ? Float(current) / Float(max) : 1.0
        isCharging = info[kIOPSIsChargingKey as String] as? Bool ?? false
    }

    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }
}
