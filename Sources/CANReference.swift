import Foundation

/// CAN bus reference for the OFD03 / TC-OFF-ROAD 03 platform
/// (Thumpstar TSE72 Pro, Aptum AP8F, SSR SR-E8/SR-E15 Pro).
///
/// From passive sniffing with Feather RP2040 CAN + MCP25625 (ERR=0):
/// classical CAN 2.0, **500 kbit/s**, 11-bit controller-debug frames plus
/// 29-bit extended BMS/pack frames. This data is informational only —
/// the app talks to the controller over BLE, not CAN.
///
/// Status labels: CONFIRMED = seen + cross-checked (display/bench),
/// STRONG = repeated correlation, HYPOTHESIS = single-session guess.
enum CANReference {
    static let bitrate = "500 kbit/s, classical CAN 2.0"

    struct FrameInfo {
        let id: String
        let kind: String
        let rate: String
        let meaning: String
        let status: String
    }

    static let frames: [FrameInfo] = [
        .init(id: "0x81–0x93", kind: "11-bit debug", rate: "~5 Hz", meaning: "Controller debug (DunenTestV101 DBC, DN_DebugID1V101): Udc, Idc/Imag, KeyVMon, V12Mon, speed, Warn/Err, BMSCur/BMSSoc mirrors. Tool traffic, not the BMS protocol.", status: "CONFIRMED"),
        .init(id: "1802F4EF", kind: "29-bit BMS", rate: "~20 Hz", meaning: "Fast dynamic frame; b1 = current/load candidate (0 at steady speed, rises with throttle), b2:b3 speed-correlated. Scale/unit unknown.", status: "STRONG"),
        .init(id: "1801EFF4", kind: "29-bit BMS", rate: "~10 Hz", meaning: "Drive/status; b4 changes 01→09 on drive activation.", status: "STRONG"),
        .init(id: "1801F4EF", kind: "29-bit BMS", rate: "~5 Hz", meaning: "Voltage/status/counters; b0:b1 ≈ pack voltage (~81.0V seen).", status: "HYPOTHESIS"),
        .init(id: "1803F4EF", kind: "29-bit BMS", rate: "~5 Hz", meaning: "b4 = SOC % (matched cluster 99%), b5 = SOH candidate (100, stable while charging 98→99).", status: "CONFIRMED (b4)"),
        .init(id: "1803F3F4", kind: "29-bit BMS", rate: "~5 Hz", meaning: "Present every session; structure open.", status: "SEEN"),
        .init(id: "1801–1804F3F4", kind: "29-bit BMS", rate: "~3 Hz", meaning: "Pack family frames; 1804F3F4 all zeros.", status: "SEEN"),
        .init(id: "1806E5F4 / 1807E5F4", kind: "29-bit BMS", rate: "~2 Hz", meaning: "Pack auxiliary frames.", status: "SEEN"),
        .init(id: "1808F3F4", kind: "29-bit BMS", rate: "~1 Hz", meaning: "ASCII identifier, e.g. M0046BK8 (model/batch).", status: "CONFIRMED"),
        .init(id: "1809F3F4", kind: "29-bit BMS", rate: "~1 Hz", meaning: "ASCII fragment, bytes 4–7 e.g. L118.", status: "CONFIRMED"),
        .init(id: "0x6D2", kind: "11-bit", rate: "charging only", meaning: "Payload ASCII 1550018 — charger handshake/diagnostics candidate.", status: "HYPOTHESIS"),
    ]

    struct PinInfo {
        let pin: String
        let role: String
        let status: String
    }

    /// Main battery connector: 2+8 housing, populated 2 power + 5 signal.
    /// Charge port is separate: HIGO S526A 2+3.
    static let batteryPins: [PinInfo] = [
        .init(pin: "1", role: "CAN-H or CAN-L (~21 kΩ pair, ~4 Vpp activity after TEST)", status: "STRONG"),
        .init(pin: "2", role: "CAN-L or CAN-H (pair with pin 1)", status: "STRONG"),
        .init(pin: "3", role: "KEY — red ignition wire, 0 Ω confirmed; HV ~72–84 V, not logic level", status: "CONFIRMED"),
        .init(pin: "4", role: "Battery HV+ reference (~75.1 V vs pin 5)", status: "HYPOTHESIS"),
        .init(pin: "5", role: "Battery HV ground / BMS reference", status: "HYPOTHESIS"),
    ]

    static let keyWakeNote = "Bench wake: short pin 3 to pin 4 through 1 kΩ → BMS clicks, large terminals jump to pack voltage. Large HV terminals read ~3.2 V with pack removed (discharge MOS open without KEY)."
}
