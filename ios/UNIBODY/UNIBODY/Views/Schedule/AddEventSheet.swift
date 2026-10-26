import SwiftUI

public struct AddEventSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    public let selectedDay: Int
    
    @State private var title: String = ""
    @State private var room: String = ""
    @State private var startTime: String = "10:15"
    @State private var endTime: String = "11:45"
    @State private var eventType: String = "lecture"
    @State private var day: Int = 0
    @State private var weekType: String = "all"
    
    private let dayNames = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag"]
    
    public init(selectedDay: Int = 0) {
        self.selectedDay = selectedDay
        _day = State(initialValue: selectedDay)
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Titel (z. B. VL Analysis I)", text: $title)
                    TextField("Raum (z. B. LMS8 - R.EG.015)", text: $room)
                    
                    Picker("Wochentag", selection: $day) {
                        ForEach(0..<5) { idx in
                            Text(dayNames[idx]).tag(idx)
                        }
                    }
                    
                    Picker("Art", selection: $eventType) {
                        Text("Vorlesung").tag("lecture")
                        Text("Übung").tag("exercise")
                        Text("Sonstiges").tag("manual")
                    }
                    
                    Picker("Turnus", selection: $weekType) {
                        Text("Jede Woche").tag("all")
                        Text("Woche A (gerade)").tag("A")
                        Text("Woche B (ungerade)").tag("B")
                    }
                }
                
                Section(header: Text("Uhrzeit")) {
                    HStack {
                        Text("Beginn")
                        Spacer()
                        TextField("10:15", text: $startTime)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Ende")
                        Spacer()
                        TextField("11:45", text: $endTime)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Neuer Termin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        let newEv = ScheduleEvent(
                            id: UUID().uuidString,
                            title: title.isEmpty ? "Veranstaltung" : title,
                            day: day,
                            dayName: dayNames[day],
                            startTime: startTime,
                            endTime: endTime,
                            room: room,
                            type: eventType,
                            enabled: true,
                            weekType: weekType
                        )
                        appState.schedule.append(newEv)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
