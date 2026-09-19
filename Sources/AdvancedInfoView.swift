import SwiftUI

struct AdvancedInfoView: View {
    @EnvironmentObject var ble: DunenBLEManager
    @EnvironmentObject var settings: AppSettings

    private var estimatedWhPerKm: Double {
        let speed = max(ble.telemetry.speedKmh, 1.0)
        let powerW = max(ble.telemetry.powerKw * 1000.0, 0.0)

        // Conservative estimate for heavy-ish 72V e-moto.
        // Around 42-55 Wh/km cruising, higher when fast/hard acceleration.
        let live = speed > 10 && powerW > 350 ? powerW / speed : 52.0
        let speedAdjusted = 40.0 + (speed * 0.45)

        return min(max((live * 0.35) + (speedAdjusted * 0.65), 38.0), 95.0)
    }

    private var estimatedRangeKm: Double {
        // Pack energy from active profile (AP8F 72V38.4Ah ≈ 2765Wh,
        // TSE72 Pro 72V40Ah = 2880Wh). Use 78% usable for realistic riding.
        let profile = settings.selectedVehicleModel.profile
        let usableWh = profile.nominalVoltage * profile.batteryAh * 0.78
        let remainingWh = usableWh * max(0.0, min(100.0, ble.telemetry.batteryPercent)) / 100.0
        return min(max(remainingWh / max(estimatedWhPerKm, 1.0), 0), 68)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                title("Advanced Info", "Live calculated controller data")

                GlassCard(glow: true) {
                    VStack(spacing: 12) {
                        row("RPM", "\(ble.telemetry.rpm)")
                        row("Voltage", String(format: "%.4f V", ble.telemetry.voltage))
                        row("Current (Imag)", String(format: "%.2f A", ble.telemetry.currentA))
                        row("Power", ble.telemetry.powerKw > 0 ? String(format: "%.1f kW", ble.telemetry.powerKw) : "—")
                        row("WarningCode", "\(ble.telemetry.warningCode)")
                        row("ErrCode", "\(ble.telemetry.errorCode)")
                    }
                }

                GlassCard {
                    VStack(spacing: 12) {
                        row("DUNEN Live Output", "")
                        row("BMS SOC", String(format: "%.0f %%", ble.telemetry.bmsSoc > 0 ? ble.telemetry.bmsSoc : ble.telemetry.batteryPercent))
                        row("Gear Input", "\(ble.telemetry.gearInputRaw)")
                        row("Speed Mode", "\(ble.telemetry.speedModeRaw)")
                        row("Throttle", String(format: "%.0f %%", ble.telemetry.throttleOpen * 100))
                        row("Regen Level Est.", ble.telemetry.regenLevel > 0 ? "\(ble.telemetry.regenLevel)" : "Auto")
                        row("Seat Signal", ble.telemetry.seatSignalActive ? "Active" : "Inactive")
                        row("Tip-over", ble.telemetry.tipOverActive ? "Active" : "OK")
                    }
                }

                GlassCard {
                    VStack(spacing: 12) {
                        row("Lean Estimate", String(format: "%.1f°", ble.telemetry.leanAngle))
                        row("G-Force Estimate", String(format: "%.2f g", ble.telemetry.gForce))
                        row("Wheel RPM", String(format: "%.0f rpm", ble.telemetry.wheelRPM))
                        row("Wheel Torque Est.", String(format: "%.1f Nm", ble.telemetry.wheelTorqueNm))
                        row("Theoretical Top", String(format: "%.0f km/h", ble.telemetry.theoreticalTopSpeedKmh))
                    }
                }

                GlassCard {
                    VStack(spacing: 12) {
                        row("Battery % Est.", String(format: "%.0f %%", ble.telemetry.batteryPercent))
                        row("Voltage Sag", String(format: "%.2f V", ble.telemetry.voltageSag))
                        row("Motor Temp", String(format: "%.1f °C", ble.telemetry.motorTemp))
                        row("Controller Temp", String(format: "%.1f °C", ble.telemetry.controllerTemp))
                        row("Wh/km Est.", String(format: "%.1f Wh/km", estimatedWhPerKm))
                        row("Range Est.", String(format: "%.0f km", estimatedRangeKm))
                        row("5V Rail (OVMon5V)", String(format: "%.4f V", ble.telemetry.internal5V))
                        row("15V Rail (OVMon15V)", String(format: "%.4f V", ble.telemetry.internal15V))
                        heatBar(value: ble.telemetry.controllerTemp)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Chain Drive Setup")
                            .font(.headline)
                        row("Battery", String(format: "%.0fV %.1fAh (%@)", settings.selectedVehicleModel.profile.nominalVoltage, settings.selectedVehicleModel.profile.batteryAh, settings.selectedVehicleModel.profile.controllerTypeString))
                        row("Motor", String(format: "%.0fW / %.0fW peak", settings.selectedVehicleModel.profile.motorContinuousW, settings.selectedVehicleModel.profile.motorPeakW))
                        row("Rear sprocket", String(format: "%.0fT", settings.selectedVehicleModel.profile.rearSprocketTeeth))
                        row("Rear wheel", String(format: "%.0f inch", settings.selectedVehicleModel.profile.rearWheelInches))
                        row("Front wheel", String(format: "%.0f inch", settings.selectedVehicleModel.profile.frontWheelInches))
                        row("Drive", "Chain")
                        Text("Wheel torque and top speed are estimates from speed/RPM and assumed gearing.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 82)
        }
    }

    private func title(_ a: String, _ b: String) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(a).font(.largeTitle.weight(.heavy))
                Text(b).font(.caption).foregroundStyle(.cyan)
            }
            Spacer()
            ConnectionPill()
        }
    }

    private func row(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
    }

    private func heatBar(value: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value < 55 ? "Safe" : (value < 75 ? "Warm" : "Hot / Power Reduced"))
                .font(.caption.weight(.bold))
                .foregroundStyle(value < 55 ? .green : (value < 75 ? .orange : .red))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule()
                        .fill(value < 55 ? .green : (value < 75 ? .orange : .red))
                        .frame(width: geo.size.width * min(value / 100.0, 1.0))
                }
            }
            .frame(height: 10)
        }
    }
}
