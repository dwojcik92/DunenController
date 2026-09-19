import Foundation

/// Vehicle/controller profile. The app was hardcoded to a single AP8F bike
/// (DEMCC2416QS035ZFS01, 4000/6000/8000 rpm, 38.4Ah, 15T/48T).
/// TSE72 Pro (DEMCC2429QS06ZFS01) is the second profile, contributed from
/// real-bike measurements + CAN reverse engineering.
///
/// Sources for TSE72 Pro values: TSE72_PRO.md (canonical), battery label
/// TC-OFF-ROAD3PRO / NE Technology 72V40Ah, controller nameplate photo,
/// 500 kbit/s CAN captures (SOC = 1803F3F4.b4), display SW/HW 1.2.0.
/// Fields marked hypothesis in docs (20S8P, Samsung 50S, CAN-H/L assignment)
/// are NOT encoded here — only confirmed values.
struct ControllerProfile: Equatable {
    let id: String
    let displayName: String
    let detail: String
    let controllerTypeString: String
    /// Alternate model string seen in the wild (app-read vs nameplate).
    let alternateTypeString: String?
    let controllerShortName: String
    let ecoRPM: Int
    let xcRPM: Int
    let sportRPM: Int
    let reverseRPM: Int
    let batteryAh: Double
    let nominalVoltage: Double
    let fullVoltage: Double
    let emptyVoltage: Double
    let frontSprocketTeeth: Double
    let rearSprocketTeeth: Double
    let rearWheelInches: Double
    let frontWheelInches: Double
    let motorContinuousW: Double
    let motorPeakW: Double
    let theoreticalTopSpeedKmh: Double
    let maxBatteryA: Double
    let maxPhaseA: Double
    /// Whether this controller is known to use the public/default parameter
    /// table. OEM tables must remain read-only even when one response happens
    /// to have the expected byte count.
    let supportsParameterWrites: Bool
    /// Top anchor actually observed at full charge (differs per pack/BMS).
    let socTopVoltage: Double

    var finalDriveRatio: Double { rearSprocketTeeth / frontSprocketTeeth }
    var rearWheelCircumferenceM: Double { Double.pi * rearWheelInches * 0.0254 }
    /// km/h per 1 motor RPM — used to convert OVechSpd/ActualSpeed RPM → km/h.
    var kmhPerMotorRPM: Double { rearWheelCircumferenceM * 60.0 / 1000.0 / finalDriveRatio }

    func rpmLimit(for mode: RideMode) -> Int {
        switch mode {
        case .eco: return ecoRPM
        case .xc: return xcRPM
        case .sports: return sportRPM
        case .reverse: return reverseRPM
        case .park: return 0
        }
    }

    static let ap8f = ControllerProfile(
        id: "ap8f",
        displayName: "AP8F",
        detail: "8 kW · 72 V",
        controllerTypeString: "DEMCC2416QS035ZFS01",
        alternateTypeString: nil,
        controllerShortName: "DUNEN312",
        ecoRPM: 4000,
        xcRPM: 6000,
        sportRPM: 8000,
        reverseRPM: 260,
        batteryAh: 38.4,
        nominalVoltage: 72.0,
        fullVoltage: 82.0,
        emptyVoltage: 60.0,
        frontSprocketTeeth: 15.0,
        rearSprocketTeeth: 48.0,
        rearWheelInches: 18.0,
        frontWheelInches: 19.0,
        motorContinuousW: 4000,
        motorPeakW: 8000,
        theoreticalTopSpeedKmh: 136.0,
        maxBatteryA: 0, // unknown on AP8F — 0 = don't display
        maxPhaseA: 0,
        supportsParameterWrites: true,
        socTopVoltage: 82.0
    )

    static let tse72Pro = ControllerProfile(
        id: "tse72pro",
        displayName: "TSE72 Pro",
        detail: "15 kW peak · 72 V · 40 Ah",
        // The physical label reads DEMCC2429, but the controller itself and
        // official app both report DEMCC2431. Use the reported identity for
        // the BLE protocol; retain the nameplate value as an alternate.
        controllerTypeString: "DEMCC2431QS06ZFS01",
        alternateTypeString: "DEMCC2429QS06ZFS01",
        controllerShortName: "DUNEN-C24",
        ecoRPM: 4500,
        xcRPM: 6500,
        sportRPM: 8500,
        reverseRPM: 300,
        batteryAh: 40.0,
        nominalVoltage: 72.0,
        fullVoltage: 84.0,
        emptyVoltage: 60.0,
        frontSprocketTeeth: 14.0,
        rearSprocketTeeth: 48.0,
        rearWheelInches: 18.0,
        frontWheelInches: 19.0,
        motorContinuousW: 6000,
        motorPeakW: 15000,
        theoreticalTopSpeedKmh: 100.0,
        maxBatteryA: 200,
        maxPhaseA: 530,
        supportsParameterWrites: false,
        socTopVoltage: 84.0
    )

    static let all: [ControllerProfile] = [.ap8f, .tse72Pro]

    static func profile(for id: String) -> ControllerProfile {
        all.first(where: { $0.id == id }) ?? .ap8f
    }
}
