import SwiftUI

public struct UnivISImportView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var icsContent: String = ""
    @State private var importedCount: Int? = nil
    
    private let sampleICS = """
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//UnivIS//UnivIS 2026w//DE
BEGIN:VEVENT
SUMMARY:VL infEInf-02a/01a [#080058]: Einführung in die Informatik
DTSTART:20261026T140000
DTEND:20261026T160000
RRULE:FREQ=WEEKLY;BYDAY=MO
LOCATION:Online-Veranstaltung
END:VEVENT
BEGIN:VEVENT
SUMMARY:VL MathInfA [#060397]: Mathematik für Informatik A
DTSTART:20261027T121500
DTEND:20261027T134500
RRULE:FREQ=WEEKLY;BYDAY=TU
LOCATION:LMS8 - R.EG.010
END:VEVENT
END:VCALENDAR
"""
    
    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("iCalendar (.ics) Daten einfügen")) {
                    TextEditor(text: $icsContent)
                        .frame(minHeight: 180)
                        .font(.system(.caption, design: .monospaced))
                    
                    Button("Beispiel-UnivIS-Kalender einsetzen") {
                        icsContent = sampleICS
                    }
                    .font(.caption)
                    .foregroundColor(AeroTheme.skyBlue)
                }
                
                if let count = importedCount {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AeroTheme.emerald)
                            Text("\(count) Termine erfolgreich importiert!")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AeroTheme.emerald)
                        }
                    }
                }
            }
            .navigationTitle("UnivIS ICS Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importieren") {
                        let parsed = UnivISParser.parseICS(icsContent)
                        if !parsed.isEmpty {
                            appState.schedule.append(contentsOf: parsed)
                            importedCount = parsed.count
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                dismiss()
                            }
                        }
                    }
                    .disabled(icsContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
