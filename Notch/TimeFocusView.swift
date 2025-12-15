
import SwiftUI
import Combine
import EventKit

// MARK: - Models & Logic
struct FocusPreset: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var durationMinutes: Int
    var iconName: String = "timer"
}

struct ReminderItem: Identifiable {
    var id: String
    var title: String
    var isCompleted: Bool
    var dueDate: Date?
}

class TimeFocusManager: ObservableObject {
    @Published var activeTimerRemaining: TimeInterval = 0
    @Published var isTimerRunning: Bool = false
    @Published var activeTimerEndDate: Date? = nil
    @Published var activePresetID: UUID? = nil

    @Published var upcomingEvents: [EKEvent] = []
    @Published var presets: [FocusPreset] = []
    @Published var reminders: [ReminderItem] = []
    @Published var hasReminderAccess: Bool = false

    private var timer: Timer?
    private let eventStore = EKEventStore()
    private let presetsKey = "focusPresets"

    init() {
        loadPresets()
        requestReminderAccess()
    }

    // MARK: - Timer Logic
    func startTimer(minutes: Int, presetID: UUID? = nil) {
        stopTimer(clearPreset: false)
        activeTimerEndDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        isTimerRunning = true
        activePresetID = presetID
        scheduleTimer()
    }

    func pauseTimer() {
        guard isTimerRunning, let end = activeTimerEndDate else { return }
        activeTimerRemaining = end.timeIntervalSinceNow
        isTimerRunning = false
        invalidateTimer()
    }

    func resumeTimer() {
        guard !isTimerRunning, activeTimerRemaining > 0 else { return }
        activeTimerEndDate = Date().addingTimeInterval(activeTimerRemaining)
        isTimerRunning = true
        scheduleTimer()
    }

    func stopTimer(clearPreset: Bool = true) {
        isTimerRunning = false
        activeTimerRemaining = 0
        activeTimerEndDate = nil
        if clearPreset { activePresetID = nil }
        invalidateTimer()
    }

    private func scheduleTimer() {
        invalidateTimer()
        updateRemaining()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.updateRemaining() }
        }
        if let t = timer { RunLoop.main.add(t, forMode: .common) }
    }

    private func updateRemaining() {
        if let end = activeTimerEndDate {
            let rem = end.timeIntervalSinceNow
            if rem <= 0 { stopTimer() } else { activeTimerRemaining = rem }
        } else {
            activeTimerRemaining = 0
        }
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Reminders Access & Data
    func requestReminderAccess() {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToReminders { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.hasReminderAccess = granted
                    if granted {
                        self?.fetchReminders()
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .reminder) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.hasReminderAccess = granted
                    if granted {
                        self?.fetchReminders()
                    }
                }
            }
        }
    }
    
    func fetchReminders() {
        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForReminders(in: calendars)
        
        eventStore.fetchReminders(matching: predicate) { [weak self] ekReminders in
            guard let ekReminders = ekReminders else { return }
            
            DispatchQueue.main.async {
                self?.reminders = ekReminders.compactMap { reminder in
                    guard let dueDate = reminder.dueDateComponents?.date else { return nil }
                    return ReminderItem(
                        id: reminder.calendarItemIdentifier,
                        title: reminder.title,
                        isCompleted: reminder.isCompleted,
                        dueDate: dueDate
                    )
                }
            }
        }
    }
    
    func addReminder(title: String, date: Date?) {
        // If we don't have reminder access, fallback to a local UI-only reminder
        guard hasReminderAccess else {
            let item = ReminderItem(id: UUID().uuidString, title: title, isCompleted: false, dueDate: date)
            DispatchQueue.main.async {
                self.reminders.insert(item, at: 0)
            }
            print("Warning: No reminder access — saved locally only.")
            return
        }

        // Choose a calendar to save into. defaultCalendarForNewReminders() can be nil
        let targetCalendar = eventStore.defaultCalendarForNewReminders() ?? eventStore.calendars(for: .reminder).first

        guard let calendar = targetCalendar else {
            // No calendars available — fallback to local reminder
            let item = ReminderItem(id: UUID().uuidString, title: title, isCompleted: false, dueDate: date)
            DispatchQueue.main.async {
                self.reminders.insert(item, at: 0)
            }
            print("Error saving reminder: no reminder calendar available — saved locally.")
            return
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = calendar

        if let date = date {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            reminder.dueDateComponents = components
        } else {
            reminder.dueDateComponents = nil
        }

        do {
            try eventStore.save(reminder, commit: true)
            fetchReminders()
        } catch {
            let ns = error as NSError
            print("Error saving reminder: \(error.localizedDescription) (code: \(ns.code))")
            // Fallback: keep a local copy so the UI shows the new task even if system save failed
            let item = ReminderItem(id: UUID().uuidString, title: title, isCompleted: false, dueDate: date)
            DispatchQueue.main.async {
                self.reminders.insert(item, at: 0)
            }
        }
    }
    
    func toggleReminder(itemId: String) {
        if let ekReminder = eventStore.calendarItem(withIdentifier: itemId) as? EKReminder {
            ekReminder.isCompleted = !ekReminder.isCompleted
            do {
                try eventStore.save(ekReminder, commit: true)
                fetchReminders()
                return
            } catch {
                print("Error updating reminder: \(error.localizedDescription)")
            }
        }

        // Fallback: toggle local reminder
        DispatchQueue.main.async {
            if let idx = self.reminders.firstIndex(where: { $0.id == itemId }) {
                self.reminders[idx].isCompleted.toggle()
            }
        }
    }

    func updateReminder(id: String, title: String, date: Date?) {
        // Try updating existing EKReminder
        if let ekItem = eventStore.calendarItem(withIdentifier: id) as? EKReminder {
            ekItem.title = title
            if let date = date {
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                ekItem.dueDateComponents = comps
            } else {
                ekItem.dueDateComponents = nil
            }
            do {
                try eventStore.save(ekItem, commit: true)
                fetchReminders()
                return
            } catch {
                print("Error updating reminder via EventKit: \(error.localizedDescription)")
            }
        }

        // Fallback: update local copy
        DispatchQueue.main.async {
            if let idx = self.reminders.firstIndex(where: { $0.id == id }) {
                self.reminders[idx].title = title
                self.reminders[idx].dueDate = date
            }
        }
    }
    
    func reminders(for date: Date) -> [ReminderItem] {
        let calendar = Calendar.current
        return reminders.filter { reminder in
            if let d = reminder.dueDate {
                return calendar.isDate(d, inSameDayAs: date)
            }
            return false
        }
    }

    func fetchTodayEvents() {
        // Real implementation would go here
    }

    private func loadPresets() {
        self.presets = [
            FocusPreset(name: "Work", durationMinutes: 25, iconName: "briefcase.fill"),
            FocusPreset(name: "Study", durationMinutes: 50, iconName: "graduationcap.fill"),
            FocusPreset(name: "Chill", durationMinutes: 15, iconName: "cup.and.saucer.fill"),
            FocusPreset(name: "Custom", durationMinutes: 0, iconName: "gearshape.fill")
        ]
    }
}

// MARK: - UI Components

struct TimeFocusView: View {
    @StateObject private var manager = TimeFocusManager()
    @State private var selectedTab: Tab = .timer
    @State private var selectedDate = Date()
    @State private var demoRemaining: TimeInterval = 5 * 60 + 10
    @State private var demoTotal: TimeInterval = 5 * 60 + 10
    @State private var demoRunning: Bool = true
    @State private var showingAddTask = false
    @State private var newTaskText = ""
    // Inline editing state
    @State private var editingId: String? = nil
    @State private var editingTitle: String = ""
    @State private var editingDate: Date = Date()
    @State private var editingHasDate: Bool = true

    enum Tab { case timer, alarm }
    
    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 16) {
            // Left Card: Timer / Alarm
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    segmentButton(.timer, title: "Timer")
                    segmentButton(.alarm, title: "Alarm")
                    Spacer()
                }

                if selectedTab == .timer {
                    VStack {
                        Spacer()
                        CircularTimerView(remaining: demoRemaining, total: demoTotal)
                            .frame(width: 160, height: 160)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 12) {
                        alarmRow(time: "9:45", enabled: .constant(false))
                        alarmRow(time: "16:05", enabled: .constant(false))
                        alarmRow(time: "22:45", enabled: .constant(false))
                        Spacer()
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 200)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))

            // Right Card: Enhanced Calendar with Scrollable Dates and Reminders
            VStack(spacing: 0) {
                // Calendar section with month label and horizontal week strip on one row
                HStack(spacing: 2) {
                    Text(monthName(for: selectedDate))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.leading, 8)

                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 2) {
                                ForEach(generateDateRange(), id: \.self) { date in
                                    DateRowView(
                                        date: date,
                                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                        isToday: calendar.isDateInToday(date)
                                    )
                                    .id(date)
                                    .frame(width: 52)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedDate = date
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                            .padding(.trailing, 6)
                        }
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                proxy.scrollTo(selectedDate, anchor: .center)
                            }
                        }
                    }
                }
                .frame(height: 72)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.vertical, 8)
                
                // Reminders section - redesigned to match the image style
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(dayName(for: selectedDate))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            Text(fullDateString(for: selectedDate))
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        Spacer()

                        Button(action: {
                            // start inline add
                            editingId = "NEW-\(UUID().uuidString)"
                            editingTitle = ""
                            editingDate = selectedDate
                            editingHasDate = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 28, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    
                    ScrollView {
                        if !manager.hasReminderAccess {
                            VStack(spacing: 16) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.2))
                                
                                Text("Reminders access required")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.4))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            // .padding(.top, 30)
                        } else {
                            let todayReminders = manager.reminders(for: selectedDate)
                            
                            if editingId?.starts(with: "NEW-") == true {
                                // Inline new item row
                                HStack(spacing: 10) {
                                    Circle()
                                        .stroke(Color.gray, lineWidth: 2)
                                        .frame(width: 20, height: 20)

                                    VStack(alignment: .leading) {
                                        TextField("New reminder", text: $editingTitle, onCommit: {
                                            let title = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                            guard !title.isEmpty else { editingId = nil; return }
                                            manager.addReminder(title: title, date: editingHasDate ? editingDate : nil)
                                            editingId = nil
                                            editingTitle = ""
                                        })
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.02)))
                                    }

                                        if editingHasDate {
                                            DatePicker("", selection: $editingDate, displayedComponents: [.date, .hourAndMinute])
                                                .labelsHidden()
                                                .frame(maxWidth: 160)
                                            Button(action: { editingHasDate = false }) { Text("Clear") }
                                                .buttonStyle(PlainButtonStyle())
                                        } else {
                                            Button(action: { editingHasDate = true; editingDate = selectedDate }) { Text("Add date") }
                                                .buttonStyle(PlainButtonStyle())
                                        }

                                        Button(action: {
                                            let title = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if !title.isEmpty {
                                                manager.addReminder(title: title, date: editingHasDate ? editingDate : nil)
                                            }
                                            editingId = nil
                                            editingTitle = ""
                                        }) { Text("Save") }
                                        .buttonStyle(PlainButtonStyle())

                                        Button(action: {
                                            editingId = nil
                                            editingTitle = ""
                                        }) {
                                            Text("Cancel")
                                        }
                                        .buttonStyle(PlainButtonStyle())

                                    Spacer()
                                }
                                .padding(.horizontal, 6)
                            }
                            
                            if todayReminders.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white.opacity(0.15))
                                    
                                    Text("No tasks for today")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.35))
                                }
                                .frame(maxWidth: .infinity)
                                // .padding(.top, 30)
                                } else {
                                VStack(spacing: 10) {
                                    ForEach(todayReminders) { reminder in
                                        if editingId == reminder.id {
                                            // editing existing item
                                            HStack(spacing: 10) {
                                                Circle()
                                                    .stroke(Color.gray, lineWidth: 2)
                                                    .frame(width: 20, height: 20)

                                                VStack(alignment: .leading) {
                                                            TextField("Reminder", text: $editingTitle, onCommit: {
                                                                let title = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                                                guard !title.isEmpty else { editingId = nil; return }
                                                                manager.updateReminder(id: reminder.id, title: title, date: editingHasDate ? editingDate : nil)
                                                                editingId = nil
                                                                editingTitle = ""
                                                            })
                                                    .textFieldStyle(PlainTextFieldStyle())
                                                    .foregroundColor(.white)
                                                    .padding(8)
                                                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.02)))
                                                }

                                                        if editingHasDate {
                                                            DatePicker("", selection: $editingDate, displayedComponents: [.date, .hourAndMinute])
                                                                .labelsHidden()
                                                                .frame(maxWidth: 160)
                                                            Button(action: { editingHasDate = false }) { Text("Clear") }
                                                                .buttonStyle(PlainButtonStyle())
                                                        } else {
                                                            Button(action: { editingHasDate = true; editingDate = reminder.dueDate ?? selectedDate }) { Text("Add date") }
                                                                .buttonStyle(PlainButtonStyle())
                                                        }

                                                        Button(action: {
                                                            let title = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                                            if !title.isEmpty {
                                                                manager.updateReminder(id: reminder.id, title: title, date: editingHasDate ? editingDate : nil)
                                                            }
                                                            editingId = nil
                                                            editingTitle = ""
                                                        }) {
                                                            Text("Save")
                                                        }
                                                        .buttonStyle(PlainButtonStyle())

                                                        Button("Cancel") { editingId = nil; editingTitle = "" }
                                                            .buttonStyle(PlainButtonStyle())

                                                Spacer()
                                            }
                                        } else {
                                            ReminderRowView(
                                                reminder: reminder,
                                                onToggle: {
                                                    manager.toggleReminder(itemId: reminder.id)
                                                },
                                                onEdit: {
                                                    // start editing this item
                                                    editingId = reminder.id
                                                    editingTitle = reminder.title
                                                    editingDate = reminder.dueDate ?? selectedDate
                                                    editingHasDate = reminder.dueDate != nil
                                                }
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal, 6)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.04)))
        }
        .padding(6)
        // .sheet(isPresented: $showingAddTask) {
        //     AddReminderSheet(
        //         date: selectedDate,
        //         newTaskText: $newTaskText,
        //         onSave: { picked in
        //             if !newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        //                 manager.addReminder(title: newTaskText, date: picked)
        //                 newTaskText = ""
        //                 showingAddTask = false
        //             }
        //         },
        //         onCancel: {
        //             newTaskText = ""
        //             showingAddTask = false
        //         }
        //     )
        // }
        
        .sheet(isPresented: $showingAddTask) {
            AddReminderSheet(
                date: selectedDate,
                newTaskText: $newTaskText,
                onSave: { picked in
                    if !newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        manager.addReminder(title: newTaskText, date: picked)
                        newTaskText = ""
                        showingAddTask = false
                    }
                },
                onCancel: {
                    newTaskText = ""
                    showingAddTask = false
                }
            )
        }
        
        .onAppear {
            if demoRunning {
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
                    if demoRemaining > 0 {
                        demoRemaining -= 1
                    } else {
                        demoRunning = false
                        t.invalidate()
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions
    private func generateDateRange() -> [Date] {
        var dates: [Date] = []
        for offset in -3...3 {
            if let date = calendar.date(byAdding: .day, value: offset, to: selectedDate) {
                dates.append(date)
            }
        }
        return dates
    }
    
    private func monthName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    private func dayName(for date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    private func fullDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func segmentButton(_ tab: Tab, title: String) -> some View {
        Button(action: { withAnimation { selectedTab = tab } }) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(selectedTab == tab ? .white : Color.white.opacity(0.6))
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(
                    Capsule().fill(selectedTab == tab ? Color.white.opacity(0.06) : Color.white.opacity(0.02))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func alarmRow(time: String, enabled: Binding<Bool>) -> some View {
        HStack {
            Text(time)
                .font(.subheadline)
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: enabled)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Color.white.opacity(0.2)))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.02)))
    }
}

// MARK: - Date Row View
struct DateRowView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Text(weekday)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isToday ? .blue : .white.opacity(0.4))
                .textCase(.uppercase)

            Text(String(format: "%02d", day))
                .font(.system(size: isSelected ? 22 : 18, weight: .bold))
                .foregroundColor(isSelected ? .blue : .white.opacity(0.5))
                .frame(width: 36, height: 36)
                .background(
                    Group {
                        if isSelected {
                            Circle().fill(Color.blue.opacity(0.15))
                        } else {
                            Color.clear
                        }
                    }
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.white.opacity(0.06) : Color.clear)
        )
        .scaleEffect(isSelected ? 1.0 : 0.95)
        .animation(.spring(response: 0.3), value: isSelected)
    }
    
    private var weekday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private var day: Int {
        calendar.component(.day, from: date)
    }
}

// MARK: - Reminder Row View
struct ReminderRowView: View {
    let reminder: ReminderItem
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(reminder.isCompleted ? Color.green.opacity(0.6) : Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 20, height: 20)

                    if reminder.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green.opacity(0.8))
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            Text(reminder.title)
                .font(.system(size: 13))
                .foregroundColor(reminder.isCompleted ? .white.opacity(0.35) : .white.opacity(0.8))
                .strikethrough(reminder.isCompleted, color: .white.opacity(0.3))
                .lineLimit(2)

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
    }
}

// MARK: - Add Reminder Sheet
struct AddReminderSheet: View {
    let date: Date
    @Binding var newTaskText: String
    let onSave: (Date) -> Void
    let onCancel: () -> Void
    @State private var pickedDate: Date = Date()
    
    var body: some View {
        #if os(iOS)
        NavigationView {
            VStack(spacing: 12) {
                TextField("What do you need to do?", text: $newTaskText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                DatePicker("When", selection: $pickedDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") { onSave(pickedDate) }
                        .disabled(newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        #else
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("New Reminder")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { onCancel() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Title")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("What do you need to do?", text: $newTaskText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Text("When")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                DatePicker("", selection: $pickedDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(FieldDatePickerStyle())
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .buttonStyle(PlainButtonStyle())
                Button(action: { onSave(pickedDate) }) {
                    Text("Add")
                }
                .disabled(newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .onAppear { pickedDate = date }
        #endif
    }
}

// Preview Provider
struct TimeFocusView_Previews: PreviewProvider {
    static var previews: some View {
        TimeFocusView()
            .frame(width: 800, height: 350)
    }
}

// MARK: - Circular Timer View
struct CircularTimerView: View {
    let remaining: TimeInterval
    let total: TimeInterval

    private var progress: Double {
        guard total > 0 else { return 1 }
        return max(0, min(1, (total - remaining) / total))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 12)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(gradient: Gradient(colors: [Color.purple, Color.blue]), center: .center),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text(timeString(from: remaining))
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                Text(totalText())
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }

    private func timeString(from seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        let m = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", m, sec)
    }

    private func totalText() -> String {
        let s = Int(total)
        let m = s / 60
        return "\(m) m"
    }
}

// Small day item (kept for compatibility)
struct DayItem: View {
    let index: Int
    let isHighlighted: Bool
    let dayNumber: Int
    let weekday: String

    var body: some View {
        VStack(spacing: 6) {
            Text(weekday)
                .font(.caption2)
                .foregroundColor(.gray)
            Text(String(format: "%02d", dayNumber))
                .font(.headline)
                .foregroundColor(isHighlighted ? Color.blue : Color.white)
                .padding(8)
                .background(isHighlighted ? AnyView(Circle().fill(Color.blue.opacity(0.12))) : AnyView(Color.clear))
        }
    }
}
