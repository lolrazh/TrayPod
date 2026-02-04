import Foundation

// MARK: - Haptic Manager using Private MultitouchSupport Framework

class HapticManager {
    static let shared = HapticManager()

    enum HapticType: Int32 {
        case weak = 3
        case medium = 4
        case strong = 6
    }

    // Function pointers loaded dynamically
    private var mtActuatorCreateFromDeviceID: (@convention(c) (UInt64) -> CFTypeRef?)?
    private var mtActuatorOpen: (@convention(c) (CFTypeRef) -> Int32)?
    private var mtActuatorClose: (@convention(c) (CFTypeRef) -> Int32)?
    private var mtActuatorActuate: (@convention(c) (CFTypeRef, Int32, UInt32, Float, Float) -> Int32)?

    // Known device IDs for different MacBook models
    private let deviceIDs: [UInt64] = [
        0x200000001000000,   // MacBook Pro 2016/2017
        0x300000080500000,   // MacBook Pro 2018/2019
        0x200000000000024,   // MacBook Pro M1 2020
        0x200000000000023,   // MacBook Pro M1 2020 (1TB)
        0x200000000000022,   // MacBook Air M1
        0x200000000000025,   // MacBook Pro 14" M1 Pro/Max
        0x200000000000026,   // MacBook Pro 16" M1 Pro/Max
        0x200000000000027,   // MacBook Air M2
        0x200000000000028,   // MacBook Pro 13" M2
        0x200000000000029,   // MacBook Pro 14" M2
        0x20000000000002A,   // MacBook Pro 16" M2
        0x20000000000002B,   // MacBook Pro M3
        0x20000000000002C,   // MacBook Air M3
    ]

    private var actuator: CFTypeRef?
    private var isAvailable = false

    private init() {
        loadFramework()
        setupActuator()
    }

    private func loadFramework() {
        // Load the private MultitouchSupport framework
        let frameworkPath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"

        guard let handle = dlopen(frameworkPath, RTLD_NOW) else {
            print("HapticManager: Could not load MultitouchSupport framework")
            return
        }

        // Load function pointers
        if let sym = dlsym(handle, "MTActuatorCreateFromDeviceID") {
            mtActuatorCreateFromDeviceID = unsafeBitCast(sym, to: (@convention(c) (UInt64) -> CFTypeRef?).self)
        }
        if let sym = dlsym(handle, "MTActuatorOpen") {
            mtActuatorOpen = unsafeBitCast(sym, to: (@convention(c) (CFTypeRef) -> Int32).self)
        }
        if let sym = dlsym(handle, "MTActuatorClose") {
            mtActuatorClose = unsafeBitCast(sym, to: (@convention(c) (CFTypeRef) -> Int32).self)
        }
        if let sym = dlsym(handle, "MTActuatorActuate") {
            mtActuatorActuate = unsafeBitCast(sym, to: (@convention(c) (CFTypeRef, Int32, UInt32, Float, Float) -> Int32).self)
        }

        isAvailable = mtActuatorCreateFromDeviceID != nil &&
                      mtActuatorOpen != nil &&
                      mtActuatorClose != nil &&
                      mtActuatorActuate != nil

        if !isAvailable {
            print("HapticManager: Could not load all required symbols")
        }
    }

    private func setupActuator() {
        guard isAvailable, let create = mtActuatorCreateFromDeviceID else { return }

        // Try each known device ID until we find one that works
        for deviceID in deviceIDs {
            if let act = create(deviceID) {
                actuator = act
                print("HapticManager: Found trackpad with device ID: \(String(format: "0x%llX", deviceID))")
                return
            }
        }
        print("HapticManager: Could not find compatible trackpad")
    }

    func click() {
        tap(type: .strong)
    }

    func tap(type: HapticType = .strong) {
        guard isAvailable,
              let actuator = actuator,
              let open = mtActuatorOpen,
              let actuate = mtActuatorActuate,
              let close = mtActuatorClose else {
            return
        }

        let openResult = open(actuator)
        guard openResult == 0 else { return } // kIOReturnSuccess = 0

        _ = actuate(actuator, type.rawValue, 0, 0, 0)
        _ = close(actuator)
    }
}
