import SwiftUI

struct AdvancedInfoView: View {
    @EnvironmentObject var ble: DunenBLEManager
    @EnvironmentObject var settings: AppSettings

    // MARK: - Ride estimates

    private var estimatedWhPerKm: Double {
        let speed = max(ble.telemetry.speedKmh, 1.0)
        let powerW = max(ble.telemetry.powerKw * 1000.0, 0.0)

        // Conservative estimate for a heavy-ish 72V e-moto.
        // Around 42–55 Wh/km cruising, higher when fast/hard accelerating.
        let live = speed > 10 && powerW > 350 ? powerW / speed : 52.0
        let speedAdjusted = 40.0 + (speed * 0.45)

        return min(max((live * 0.35) + (speedAdjusted * 0.65), 38.0), 95.0)
    }

    private var estimatedRangeKm: Double {
        // Pack energy from the active profile (AP8F 72V·38.4Ah ≈ 2765Wh,
        // TSE72 Pro 72V·40Ah = 2880Wh). 78% usable is a realistic riding figure.
        let profile = settings.selectedVehicleModel.profile
        let usableWh = profile.nominalVoltage * profile.batteryAh * 0.78
        let remainingWh = usableWh * max(0.0, min(100.0, ble.telemetry.batteryPercent)) / 100.0
        return min(max(remainingWh / max(estimatedWhPerKm, 1.0), 0), 68)
    }

    private var speedValue: Double {
        settings.speedUnit == .kmh ? ble.telemetry.speedKmh : ble.telemetry.speedKmh * 0.621371
    }

    private var modeTitle: String { ble.telemetry.mode.title }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                title("Bike Info", "Live battery, performance and ride data")

                // ── Battery ────────────────────────────────────────────────
                sectionHeader("battery.100percent", "Battery")
                GlassCard(glow: true) {
                    VStack(spacing: 12) {
                        HStack {
                            bigValue(String(format: "%.0f %%", ble.telemetry.batteryPercent), label: "Battery (est.)")
                            bigValue(String(format: "%.2f V", ble.telemetry.voltage), label: "Voltage")
                            bigValue(String(format: "%.2f V", ble.telemetry.voltageSag), label: "Voltage sag")
                        }
                        Text("Battery level is estimated from pack voltage. The bike dashboard may show a slightly different value.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // ── Performance ─────────────────────────────────────────────
                sectionHeader("speedometer", "Performance")
                GlassCard {
                    VStack(spacing: 12) {
                        HStack {
                            bigValue("\(Int(speedValue.rounded()))", label: "Speed \(settings.speedUnit.rawValue)")
                            bigValue(ble.liveFrameCount > 0 ? String(format: "%.1f kW", ble.telemetry.powerKw) : "—", label: "Power (est.)")
                            bigValue(ble.liveFrameCount > 0 ? String(format: "%.1f A", ble.telemetry.currentA) : "—", label: "Motor current (est.)")
                        }
                        row("Mode", modeTitle)
                        row("Throttle", String(format: "%.0f %%", ble.telemetry.throttleOpen * 100))
                        row("Regen", ble.telemetry.regenLevel > 0 ? "Level \(ble.telemetry.regenLevel)" : "Auto")
                        Text(ble.liveFrameCount > 0
                            ? "Power and current are estimates and may differ from the bike display."
                            : "Power and current are not available from this controller firmware.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // ── Temperatures ────────────────────────────────────────────
                sectionHeader("thermometer.medium", "Temperatures")
                GlassCard {
                    VStack(spacing: 12) {
                        row("Controller", ble.telemetry.controllerTemp != 0 ? String(format: "%.1f °C", ble.telemetry.controllerTemp) : "—")
                        row("Motor", ble.telemetry.motorTemp != 0 ? String(format: "%.1f °C", ble.telemetry.motorTemp) : "—")
                        if max(ble.telemetry.controllerTemp, ble.telemetry.motorTemp) != 0 {
                            heatBar(value: max(ble.telemetry.controllerTemp, ble.telemetry.motorTemp))
                        }
                    }
                }

                // ── Ride Estimate ───────────────────────────────────────────
                sectionHeader("point.topleft.down.curvedto.point.bottomright.up", "Ride Estimate")
                GlassCard {
                    VStack(spacing: 12) {
                        row("Consumption (est.)", String(format: "%.1f Wh/km", estimatedWhPerKm))
                        row("Range left (est.)", String(format: "%.0f km", estimatedRangeKm))
                        row("Top speed (calc.)", String(format: "%.0f km/h", ble.telemetry.theoreticalTopSpeedKmh))
                        Text("Estimates use pack size, current speed and assumed gearing — they are a guide, not a guarantee.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // ── Vehicle ─────────────────────────────────────────────────
                VehicleCard()

            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 82)
        }
    }

    // MARK: - Vehicle summary

    private struct VehicleCard: View {
        @EnvironmentObject var settings: AppSettings

        private var profile: ControllerProfile { settings.selectedVehicleModel.profile }
        private var model: VehicleModel { settings.selectedVehicleModel }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "car.2.fill")
                        .font(.headline)
                        .foregroundStyle(.cyan)
                    Text("Vehicle").font(.headline)
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: model.icon)
                            .foregroundStyle(.cyan)
                        Text("ACTIVE PROFILE")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.cyan)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.cyan.opacity(0.14))
                    .clipShape(Capsule())
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: model.icon)
                                .font(.system(size: 30))
                                .foregroundStyle(.cyan)
                                .frame(width: 46, height: 46)
                                .background(Color.cyan.opacity(0.12))
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(model.rawValue)
                                    .font(.title3.weight(.heavy))
                                Text(profile.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        Divider().opacity(0.25)
                        row("Battery pack", String(format: "%.0f V · %.1f Ah", profile.nominalVoltage, profile.batteryAh))
                        row("Motor", String(format: "%.0f W cont. · %.0f W peak", profile.motorContinuousW, profile.motorPeakW))
                        row("Gearing", String(format: "%.0fT front / %.0fT rear", profile.frontSprocketTeeth, profile.rearSprocketTeeth))
                        row("Wheels", String(format: "%.0f\" front / %.0f\" rear", profile.frontWheelInches, profile.rearWheelInches))
                        row("Drive", "Chain")
                        Text(settings.selectedVehicleModel == .tse72Pro
                            ? "TSE72 Pro profile active — choose this for the 72V·40Ah pack. Display only, never writes to the controller."
                            : "Profile only changes how the app estimates speed and range — it never writes to the controller.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        private func row(_ name: String, _ value: String) -> some View {
            HStack {
                Text(name).foregroundStyle(.secondary)
                Spacer()
                Text(value).fontWeight(.semibold)
            }
        }
    }

    // MARK: - Shared helpers

    private func sectionHeader(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.cyan)
            Text(text).font(.headline)
            Spacer()
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

    private func bigValue(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title3.weight(.heavy)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
