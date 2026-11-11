import SwiftUI

/// Settings card for the optimizer weights, preferred hours and free days.
/// Changes are stored with the rest of the app state and applied to the group ranking immediately.
struct OptimizerPreferencesCard: View {
    @EnvironmentObject var appState: AppState

    private static let dayShort = ["Mo", "Di", "Mi", "Do", "Fr"]
    private static let dayNames = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag"]

    private var allWeightsZero: Bool {
        let p = appState.optimizerPreferences
        return p.weightCompact == 0 && p.weightFreeDays == 0 && p.weightTimeWindow == 0 && p.weightCampusBuffer == 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Optimizer-Gewichtung")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundColor(.primary)
                Spacer()
                Button("Standardwerte") {
                    appState.optimizerPreferences = OptimizerPreferences()
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(AeroTheme.skyBlue)
                .accessibilityHint("Setzt Gewichtungen, Wunschzeiten und freie Tage zurück")
            }

            if allWeightsZero {
                Label("Alle Gewichtungen stehen auf 0 %. Das Ranking bewertet dann jede konfliktfreie Gruppe gleich.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(AeroTheme.solarOrange)
            }

            weightSlider("Kompakte Tage", detail: "Wenig Freistunden", value: $appState.optimizerPreferences.weightCompact)
            weightSlider("Freie Tage schützen", detail: "Ganze Tage frei halten", value: $appState.optimizerPreferences.weightFreeDays)
            weightSlider("Wunschzeiten einhalten", detail: "Nicht zu früh, nicht zu spät", value: $appState.optimizerPreferences.weightTimeWindow)
            weightSlider("Puffer für Raumwechsel", detail: "Knappe Wechsel vermeiden", value: $appState.optimizerPreferences.weightCampusBuffer)

            Divider()

            DatePicker("Frühestens ab", selection: timeBinding(\.earliestTime), displayedComponents: .hourAndMinute)
                .font(.subheadline)
            DatePicker("Spätestens bis", selection: timeBinding(\.latestTime), displayedComponents: .hourAndMinute)
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Wunsch-freie Tage")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { day in
                        let isOn = appState.optimizerPreferences.preferredFreeDays.contains(day)
                        Button {
                            toggleFreeDay(day)
                        } label: {
                            Text(Self.dayShort[day])
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(isOn ? AeroTheme.skyBlue : Color.primary.opacity(0.08))
                                )
                                .foregroundColor(isOn ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Self.dayNames[day])
                        .accessibilityValue(isOn ? "soll frei bleiben" : "nicht ausgewählt")
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
            }
        }
        .padding(18)
        .frutigerGlass(cornerRadius: 18)
    }

    private func weightSlider(_ title: String, detail: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(detail)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(Int(value.wrappedValue)) %")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundColor(AeroTheme.skyBlue)
            }
            .accessibilityHidden(true)
            Slider(value: value, in: 0...100, step: 5)
                .tint(AeroTheme.skyBlue)
                .accessibilityLabel(title)
                .accessibilityValue("\(Int(value.wrappedValue)) Prozent")
        }
    }

    private func toggleFreeDay(_ day: Int) {
        var days = Set(appState.optimizerPreferences.preferredFreeDays)
        if days.contains(day) { days.remove(day) } else { days.insert(day) }
        appState.optimizerPreferences.preferredFreeDays = days.sorted()
    }

    /// Bridges the stored "HH:mm" strings to a DatePicker.
    private func timeBinding(_ keyPath: WritableKeyPath<OptimizerPreferences, String>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = ScheduleEvent.parseMinutes(appState.optimizerPreferences[keyPath: keyPath])
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                appState.optimizerPreferences[keyPath: keyPath] = String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
            }
        )
    }
}
