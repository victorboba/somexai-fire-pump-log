import Foundation

/// What the technician looks at while the pump is churning.
///
/// The list is driver-aware on purpose. An electric motor has no exhaust, no jacket water and no
/// fuel, and asking about them wastes the two minutes the no-flow test is supposed to take. A
/// diesel, on the other hand, is most of the reason the no-flow test exists at all.
///
/// These are field prompts. NFPA 25 is the authority.
enum ObservationItem: String, CaseIterable, Identifiable {
    // Pump room
    case pumpRoomConditions, valvePositions
    // Pump and piping
    case packingGland, noiseAndVibration, casingAndBearings, reliefValve
    // Electric driver
    case controllerPilotLight, motorRunningSmoothly
    // Diesel driver
    case coolingWaterFlow, exhaustSystem, fuelSystemLeaks

    var id: String { rawValue }

    var name: String {
        switch self {
        case .pumpRoomConditions: return "Pump room heat, ventilation and lighting"
        case .valvePositions: return "Suction and discharge valves fully open"
        case .packingGland: return "Packing gland dripping at the right rate"
        case .noiseAndVibration: return "No unusual noise or vibration"
        case .casingAndBearings: return "Pump casing and bearing temperature normal"
        case .reliefValve: return "Circulation relief valve flowing and reseating"
        case .controllerPilotLight: return "Controller pilot light on and switch in automatic"
        case .motorRunningSmoothly: return "Motor running smoothly, no overheating"
        case .coolingWaterFlow: return "Cooling water flowing from the heat exchanger return"
        case .exhaustSystem: return "Exhaust system free of leaks, condensate drained"
        case .fuelSystemLeaks: return "Fuel tank and lines free of leaks and water"
        }
    }

    var group: ObservationGroup {
        switch self {
        case .pumpRoomConditions, .valvePositions: return .pumpRoom
        case .packingGland, .noiseAndVibration, .casingAndBearings, .reliefValve: return .pump
        case .controllerPilotLight, .motorRunningSmoothly, .coolingWaterFlow,
             .exhaustSystem, .fuelSystemLeaks: return .driver
        }
    }

    static func items(for driver: DriverType) -> [ObservationItem] {
        let common: [ObservationItem] = [.pumpRoomConditions, .valvePositions, .packingGland,
                                         .noiseAndVibration, .casingAndBearings, .reliefValve]
        switch driver {
        case .electric:
            return common + [.controllerPilotLight, .motorRunningSmoothly]
        case .diesel:
            return common + [.coolingWaterFlow, .exhaustSystem, .fuelSystemLeaks]
        }
    }

    static func items(for driver: DriverType, in group: ObservationGroup) -> [ObservationItem] {
        items(for: driver).filter { $0.group == group }
    }
}

enum ObservationGroup: String, CaseIterable, Identifiable {
    case pumpRoom, pump, driver
    var id: String { rawValue }

    var name: String {
        switch self {
        case .pumpRoom: return "Pump room"
        case .pump: return "Pump and piping"
        case .driver: return "Driver"
        }
    }
}

/// The alarm and supervisory signals the controller is supposed to transmit, which are only
/// worth anything if somebody has actually made each one happen and watched it arrive.
///
/// A diesel controller carries roughly twice the list an electric one does, because everything
/// that can go wrong with an engine is its own signal.
enum AlarmSignal: String, CaseIterable, Identifiable {
    // Both drivers
    case pumpRunning, controllerNotAutomatic, lowPumpRoomTemperature
    // Electric
    case lossOfPhase, phaseReversal, powerFailure
    // Diesel
    case engineTrouble, failureToStart, lowOilPressure, highCoolantTemperature
    case overspeedShutdown, batteryOneFailure, batteryTwoFailure, chargerFailure, lowFuelLevel

    var id: String { rawValue }

    var name: String {
        switch self {
        case .pumpRunning: return "Fire pump running"
        case .controllerNotAutomatic: return "Controller main switch not in automatic"
        case .lowPumpRoomTemperature: return "Low pump room temperature"
        case .lossOfPhase: return "Loss of phase"
        case .phaseReversal: return "Phase reversal"
        case .powerFailure: return "Fire pump power failure"
        case .engineTrouble: return "Engine trouble, common signal"
        case .failureToStart: return "Failure to start"
        case .lowOilPressure: return "Low engine oil pressure"
        case .highCoolantTemperature: return "High engine coolant temperature"
        case .overspeedShutdown: return "Engine overspeed shutdown"
        case .batteryOneFailure: return "Battery 1 failure"
        case .batteryTwoFailure: return "Battery 2 failure"
        case .chargerFailure: return "Battery charger failure"
        case .lowFuelLevel: return "Low fuel level"
        }
    }

    static func items(for driver: DriverType) -> [AlarmSignal] {
        let common: [AlarmSignal] = [.pumpRunning, .controllerNotAutomatic, .lowPumpRoomTemperature]
        switch driver {
        case .electric:
            return common + [.lossOfPhase, .phaseReversal, .powerFailure]
        case .diesel:
            return common + [.engineTrouble, .failureToStart, .lowOilPressure,
                             .highCoolantTemperature, .overspeedShutdown,
                             .batteryOneFailure, .batteryTwoFailure, .chargerFailure, .lowFuelLevel]
        }
    }
}
