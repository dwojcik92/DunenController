import Foundation

/// DUNEN controller fault/alarm codes.
///
/// Source: 南京顿恩电气控制器报警码列表V1.7 (Nanjing Dunen Electric
/// Controller Alarm Code List V1.7), translated. Same numbering is shown on
/// the vehicle display with a model prefix, e.g. display `03021` = model
/// `03` + fault `21` (brake fault — seen live by holding brake at boot).
///
/// Codes not in this table are returned as "Unknown fault N" — never crash
/// on a new firmware code.
struct DunenFault {
    let code: Int
    let nameEN: String
    let action: FaultAction
    /// Buzzer pattern from the V1.7 doc, e.g. "1 short", "2 long 1 short".
    let beeps: String
    /// First thing to check, condensed from the doc's troubleshooting column.
    let tip: String

    enum FaultAction: String {
        case stop = "Stop"
        case derate = "Derate"
        case check = "Check"
    }
}

enum FaultCodes {
    static let table: [Int: DunenFault] = [
        1:  .init(code: 1,  nameEN: "Software over-current", action: .stop, beeps: "1 short", tip: "Current limit too low, encoder harness, sudden load/speed change, or restart with key"),
        2:  .init(code: 2,  nameEN: "Motor overspeed", action: .stop, beeps: "2 short", tip: "RPM past limit; check encoder wiring"),
        3:  .init(code: 3,  nameEN: "Battery overvoltage", action: .stop, beeps: "3 short", tip: "Regen current too high or bad parameter; pack disconnects"),
        4:  .init(code: 4,  nameEN: "KEY power abnormal", action: .stop, beeps: "4 short", tip: "Key circuit open/loose or key sense circuit fault"),
        5:  .init(code: 5,  nameEN: "12V power abnormal", action: .stop, beeps: "5 short", tip: "Aux supply fault or short on external 12V port"),
        6:  .init(code: 6,  nameEN: "5V power abnormal", action: .stop, beeps: "6 short", tip: "5V rail fault or short on external 5V wiring"),
        7:  .init(code: 7,  nameEN: "Angle sensor disconnected", action: .stop, beeps: "7 short", tip: "Motor angle sensor wire broken/shorted or bad connector"),
        8:  .init(code: 8,  nameEN: "Hardware over-current", action: .stop, beeps: "8 short", tip: "Motor insulation, phase short, or damaged MOSFETs"),
        9:  .init(code: 9,  nameEN: "Current loop failure", action: .stop, beeps: "9 short", tip: "Motor phase wire open or controller damaged"),
        10: .init(code: 10, nameEN: "Battery undervoltage", action: .derate, beeps: "1 long", tip: "Pack below limit, BMS cut, or loose bus bars"),
        11: .init(code: 11, nameEN: "Controller over-temperature", action: .derate, beeps: "1 long 1 short", tip: "Controller past temp limit — stop and cool down"),
        12: .init(code: 12, nameEN: "Motor over-temperature", action: .derate, beeps: "1 long 2 short", tip: "Motor past temp limit or broken PTC wire"),
        13: .init(code: 13, nameEN: "Current sensor abnormal", action: .stop, beeps: "1 long 3 short", tip: "Current sensor signal interfered"),
        14: .init(code: 14, nameEN: "Angle signal interference", action: .stop, beeps: "1 long 4 short", tip: "Angle sensor signal interfered"),
        15: .init(code: 15, nameEN: "Throttle signal out of range", action: .stop, beeps: "1 long 5 short", tip: "Throttle input over limit or disconnected"),
        16: .init(code: 16, nameEN: "Throttle not reset", action: .stop, beeps: "1 long 6 short", tip: "Throttle not at zero at power-on"),
        17: .init(code: 17, nameEN: "Motor stall", action: .derate, beeps: "1 long 7 short", tip: "Motor stalled past protection time"),
        18: .init(code: 18, nameEN: "BMS fault", action: .stop, beeps: "1 long 8 short", tip: "Abnormal inside battery pack"),
        19: .init(code: 19, nameEN: "Communication disconnected", action: .stop, beeps: "1 long 9 short", tip: "BMS communication not connected"),
        21: .init(code: 21, nameEN: "Brake fault — external short of brake signal line", action: .stop, beeps: "2 long 1 short", tip: "Brake signal wire shorted; also appears on boot with brake held (display 03021)"),
        23: .init(code: 23, nameEN: "User parameters abnormal", action: .stop, beeps: "2 long 3 short", tip: "User parameter table incomplete"),
        24: .init(code: 24, nameEN: "Manufacturer parameters abnormal", action: .stop, beeps: "2 long 4 short", tip: "Factory parameter table incomplete"),
        33: .init(code: 33, nameEN: "Angle learning failed", action: .stop, beeps: "3 long 3 short", tip: "Wrong phase sequence — check motor/angle wiring or encoder disc"),
        34: .init(code: 34, nameEN: "Phase terminal abnormal high temperature", action: .stop, beeps: "3 long 4 short", tip: "Loose phase screws / bad contact"),
        35: .init(code: 35, nameEN: "Torque loop failure", action: .stop, beeps: "3 long 5 short", tip: "Code-disc zero abnormal"),
        36: .init(code: 36, nameEN: "Motor phase short to power", action: .stop, beeps: "3 long 6 short", tip: "U/V/W wiring or shorted internal MOSFETs — replace controller if wiring OK"),
        37: .init(code: 37, nameEN: "Wheelie angle limit exceeded", action: .stop, beeps: "3 long 7 short", tip: "Tilt past set range or controller mounted in wrong orientation"),
        97: .init(code: 97, nameEN: "Phase current coefficient calibration deviation", action: .check, beeps: "9 long 7 short", tip: "FCT phase-current calibration abnormal"),
        98: .init(code: 98, nameEN: "Program verification failed", action: .stop, beeps: "9 long 8 short", tip: "Firmware data incomplete"),
        99: .init(code: 99, nameEN: "Model verification failed", action: .stop, beeps: "9 long 9 short", tip: "Wrong product software model"),
    ]

    /// Vehicle display shows model prefix + fault, e.g. `03021` → 21.
    /// Controller registers carry the bare code. Accepts both.
    static func normalize(_ raw: Int) -> Int {
        raw > 99 ? raw % 1000 : raw
    }

    static func fault(for raw: Int) -> DunenFault? {
        table[normalize(raw)]
    }

    /// Short label for HUD rows, e.g. "21 · Brake fault".
    static func shortLabel(for raw: Int) -> String {
        guard raw != 0 else { return "—" }
        if let f = fault(for: raw) {
            return "\(f.code) · \(f.nameEN)"
        }
        return "\(normalize(raw)) · Unknown fault"
    }
}
