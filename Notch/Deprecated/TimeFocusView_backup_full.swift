// import SwiftUI
// import Combine
// import EventKit

// // MARK: - Models & Logic
// struct FocusPreset: Identifiable, Codable, Equatable {
//     var id: UUID = UUID()
//     var name: String
//     var durationMinutes: Int
//     var iconName: String = "timer"
// }

// struct ReminderItem: Identifiable {
//     var id: String
//     var title: String
//     var isCompleted: Bool
//     var dueDate: Date?
// }

// class TimeFocusManager: ObservableObject {
//     @Published var activeTimerRemaining: TimeInterval = 0
//     @Published var isTimerRunning: Bool = false
//     @Published var activeTimerEndDate: Date? = nil
//     @Published var activePresetID: UUID? = nil

//     @Published var upcomingEvents: [EKEvent] = []
//     @Published var presets: [FocusPreset] = []
//     @Published var reminders: [ReminderItem] = []
//     @Published var hasReminderAccess: Bool = false

//     private var timer: Timer?
//     private let eventStore = EKEventStore()
//     private let presetsKey = "focusPresets"

//     init() {
//         loadPresets()
//         requestReminderAccess()
//     }

//     // MARK: - Timer Logic
//     func startTimer(minutes: Int, presetID: UUID? = nil) {
//         stopTimer(clearPreset: false)
//         activeTimerEndDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
//         isTimerRunning = true
//         activePresetID = presetID
//         scheduleTimer()
//     }

//     func pauseTimer() {
//         guard isTimerRunning, let end = activeTimerEndDate else { return }
//         activeTimerRemaining = end.timeIntervalSinceNow
//         isTimerRunning = false
//         invalidateTimer()
//     }

//     func resumeTimer() {
//         guard !isTimerRunning, activeTimerRemaining > 0 else { return }
//         activeTimerEndDate = Date().addingTimeInterval(activeTimerRemaining)
//         isTimerRunning = true
//         scheduleTimer()
//     }

//     func stopTimer(clearPreset: Bool = true) {
//         isTimerRunning = false
//         activeTimerRemaining = 0
//         activeTimerEndDate = nil
//         if clearPreset { activePresetID = nil }
//         invalidateTimer()
//     }

//     private func scheduleTimer() {
//         invalidateTimer()
//         updateRemaining()
//         timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
//             DispatchQueue.main.async { self?.updateRemaining() }
//         }
//         if let t = timer { RunLoop.main.add(t, forMode: .common) }
//     }

//     private func updateRemaining() {
//         if let end = activeTimerEndDate {
//             let rem = end.timeIntervalSinceNow
//             if rem <= 0 { stopTimer() } else { activeTimerRemaining = rem }
//         } else {
//             activeTimerRemaining = 0
//         }
//     }

//     private func invalidateTimer() {
//         timer?.invalidate()
//         timer = nil
//     }

//     // MARK: - Reminders Access & Data
//     func requestReminderAccess() {
//         if #available(iOS 17.0, *) {
//             eventStore.requestFullAccessToReminders { [weak self] granted, error in
//                 DispatchQueue.main.async {
//                     self?.hasReminderAccess = granted
//                     if granted {
//                         self?.fetchReminders()
//                     }
//                 }
//             }
//         } else {
//             eventStore.requestAccess(to: .reminder) { [weak self] granted, error in
//                 DispatchQueue.main.async {
//                     self?.hasReminderAccess = granted
//                     if granted {
//                         self?.fetchReminders()
//                     }
//                 }
//             }
//         }
//     }
    
//     func fetchReminders() {
//         let calendars = eventStore.calendars(for: .reminder)
//         let predicate = eventStore.predicateForReminders(in: calendars)
        
//         eventStore.fetchReminders(matching: predicate) { [weak self] ekReminders in
//             guard let ekReminders = ekReminders else { return }
            
//             DispatchQueue.main.async {
//                 self?.reminders = ekReminders.compactMap { reminder in
//                     guard let dueDate = reminder.dueDateComponents?.date else { return nil }
//                     return ReminderItem(
//                         id: reminder.calendarItemIdentifier,
//                         title: reminder.title,
//                         isCompleted: reminder.isCompleted,
//                         dueDate: dueDate
//                     )
//                 }
//             }
//         }
//     }
    
//     func addReminder(title: String, date: Date?) {
//         // If we don't have reminder access, fallback to a local UI-only reminder
//         guard hasReminderAccess else {
//             let item = ReminderItem(id: UUID().uuidString, title: title, isCompleted: false, dueDate: date)
//             DispatchQueue.main.async {
//                 self.reminders.insert(item, at: 0)
//             }
//             print("Warning: No reminder access — saved locally only.")
//             return
//         }

//         // Choose a calendar to save into. defaultCalendarForNewReminders() can be nil
//         let targetCalendar = eventStore.defaultCalendarForNewReminders() ?? eventStore.calendars(for: .reminder).first

//         guard let calendar = targetCalendar else {
//             // No calendars available — fallback to local reminder
//             let item = ReminderItem(id: UUID().uuidString, title: title, isCompleted: false, dueDate: date)
//             DispatchQueue.main.async {
//                 self.reminders.insert(item, at: 0)
//             }
//             print("Error saving reminder: no reminder calendar available — saved locally.")
//             return
//         }

//         let reminder = EKReminder(eventStore: eventStore)
//         reminder.title = title
//         reminder.calendar = calendar

//         if let date = date {
//             let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
//             reminder.dueDateComponents = components
//         } else {
//             reminder.dueDateComponents = nil
//         }

//         do {
//             try eventStore.save(reminder, commit: true)
//             fetchReminders()
//         } catch {
//             let ns = error as NSError
//             print("Error saving reminder: \(error.localizedDescription) (code: \(ns.code))")
//             // Fallback: keep a local copy so the UI shows the new task even if system save failed
//             let item = ReminderItem(id: UUID().uuidString, title: title, isCompleted: false, dueDate: date)
//             DispatchQueue.main.async {
//                 self.reminders.insert(item, at: 0)
//             }
//         }
//     }
    
//     func toggleReminder(itemId: String) {
//         if let ekReminder = eventStore.calendarItem(withIdentifier: itemId) as? EKReminder {
//             ekReminder.isCompleted = !ekReminder.isCompleted
//             do {
//                 try eventStore.save(ekReminder, commit: true)
//                 fetchReminders()
//                 return
//             } catch {
//                 print("Error updating reminder: \(error.localizedDescription)")
//             }
//         }

//         // Fallback: toggle local reminder
//         DispatchQueue.main.async {
//             if let idx = self.reminders.firstIndex(where: { $0.id == itemId }) {
//                 self.reminders[idx].isCompleted.toggle()
//             }
//         }
//     }

//     func updateReminder(id: String, title: String, date: Date?) {
//         // Try updating existing EKReminder
//         if let ekItem = eventStore.calendarItem(withIdentifier: id) as? EKReminder {
//             ekItem.title = title
//             if let date = date {
//                 let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
//                 ekItem.dueDateComponents = comps
//             } else {
//                 ekItem.dueDateComponents = nil
//             }
//             do {
//                 try eventStore.save(ekItem, commit: true)
//                 fetchReminders()
//                 return
//             } catch {
//                 print("Error updating reminder via EventKit: \(error.localizedDescription)")
//             }
//         }

//         // Fallback: update local copy
//         DispatchQueue.main.async {
//             if let idx = self.reminders.firstIndex(where: { $0.id == id }) {
//                 self.reminders[idx].title = title
//                 self.reminders[idx].dueDate = date
//             }
//         }
//     }
    
//     func reminders(for date: Date) -> [ReminderItem] {
//         let calendar = Calendar.current
//         return reminders.filter { reminder in
//             if let d = reminder.dueDate {
//                 return calendar.isDate(d, inSameDayAs: date)
//             }
//             return false
//         }
//     }

//     func fetchTodayEvents() {
//         // Real implementation would go here
//     }

//     private func loadPresets() {
//         self.presets = [
//             FocusPreset(name: "Work", durationMinutes: 25, iconName: "briefcase.fill"),
//             FocusPreset(name: "Study", durationMinutes: 50, iconName: "graduationcap.fill"),
//             FocusPreset(name: "Chill", durationMinutes: 15, iconName: "cup.and.saucer.fill"),
//             FocusPreset(name: "Custom", durationMinutes: 0, iconName: "gearshape.fill")
//         ]
//     }
// }

// // MARK: - UI Components

// struct TimeFocusView: View {
//     @StateObject private var manager = TimeFocusManager()
//     @State private var selectedTab: Tab = .timer
//     @State private var selectedDate = Date()
//     @State private var demoRemaining: TimeInterval = 5 * 60 + 10
//     @State private var demoTotal: TimeInterval = 5 * 60 + 10
//     @State private var demoRunning: Bool = true
//     @State private var showingAddTask = false
//     @State private var newTaskText = ""
//     @State private var showingAlarmPicker = false
//     @State private var selectedHour = 9
//     @State private var selectedMinute = 0
//     @State private var alarmLabel = ""
//     
//     // Inline editing state
//     @State private var editingId: String? = nil
//     @State private var editingTitle: String = ""
//     @State private var editingDate: Date = Date()
//     @State private var editingHasDate: Bool = true

//     enum Tab { case timer, alarm }
    
//     private let calendar = Calendar.current

//     var body: some View {
//         HStack(spacing: 16) {
//             // Left Card: Timer / Alarm
//             VStack(alignment: .leading, spacing: 12) {
//                 HStack(spacing: 8) {
//                     segmentButton(.timer, title: "Timer")
//                     segmentButton(.alarm, title: "Alarm")
//                     Spacer()
//                 }

//                 if selectedTab == .timer {
//                     VStack {
//                         Spacer()
//                         CircularTimerView(remaining: demoRemaining, total: demoTotal)
//                             .frame(width: 160, height: 160)
//                         Spacer()
//                     }
//                     .frame(maxWidth: .infinity)
//                 } else {
//                     AlarmListView(
//                         alarms: manager.alarms,
//                         notificationPermissionGranted: manager.notificationPermissionGranted,
//                         onToggle: { alarm in
//                             manager.toggleAlarm(alarm)
//                         },
//                         onDelete: { alarm in
//                             manager.deleteAlarm(alarm)
//                         },
//                         onAdd: {
//                             showingAlarmPicker = true
//                         },
//                         onRequestPermission: {
//                             manager.requestNotificationPermission()
//                         }
//                     )
//                 }
//             }
//             .padding(16)
//             .frame(maxWidth: .infinity, minHeight: 200)
//             .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))

//             // Right Card: Enhanced Calendar with Scrollable Dates and Reminders
//             VStack(spacing: 0) {
//                 // Calendar section with month label and horizontal week strip on one row
//                 HStack(spacing: 2) {
//                     Text(monthName(for: selectedDate))
//                         .font(.system(size: 22, weight: .bold))
//                         .foregroundColor(.white)
//                         .padding(.leading, 8)

//                     ScrollViewReader { proxy in
//                         ScrollView(.horizontal, showsIndicators: false) {
//                             LazyHStack(spacing: 2) {
//                                 ForEach(generateDateRange(), id: \.self) { date in
//                                     DateRowView(
//                                         date: date,
//                                         isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
//                                         isToday: calendar.isDateInToday(date)
//                                     )
//                                     .id(date)
//                                     .frame(width: 52)
//                                     .onTapGesture {
//                                         withAnimation(.spring(response: 0.3)) {
//                                             selectedDate = date
//                                         }
//                                     }
//                                 }
//                             }
//                             .padding(.vertical, 2)
//                             .padding(.trailing, 6)
//                         }
//                         .onAppear {
//                             DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                                 proxy.scrollTo(selectedDate, anchor: .center)
//                             }
//                         }
//                     }
//                 }
//                 .frame(height: 72)
                // }