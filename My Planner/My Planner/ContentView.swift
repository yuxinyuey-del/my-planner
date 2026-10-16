import SwiftUI

// MARK: - SCREEN 1: Goals ─────────────────────────────────────────────

struct Goal: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
}

@Observable
class GoalsStore {
    var goals: [Goal] = []
    private let saveKey = "myplanner_goals"

    init() { load() }

    func add(_ title: String) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        goals.append(Goal(title: title))
        save()
    }

    func delete(at offsets: IndexSet) {
        goals.remove(atOffsets: offsets)
        save()
    }

    func toggle(_ goal: Goal) {
        if let i = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[i].isCompleted.toggle()
            save()
        }
    }

    private func save() {
        if let e = try? JSONEncoder().encode(goals) { UserDefaults.standard.set(e, forKey: saveKey) }
    }
    private func load() {
        if let d = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Goal].self, from: d) { goals = decoded }
    }
}

struct ContentView: View {
    @State private var store = GoalsStore()
    @State private var showingAddGoal = false

    var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting + " 🌸").font(.title2).foregroundStyle(.secondary)
                    Text("Welcome back.").font(.largeTitle.bold())
                    Text("Don't forget your goal.").font(.title3).foregroundStyle(.pink)
                }
                .padding(.horizontal, 24).padding(.top, 48).padding(.bottom, 28)

                HStack {
                    Text("My Goals").font(.headline).foregroundStyle(.secondary)
                        .textCase(.uppercase).tracking(1)
                    Spacer()
                    Text("\(store.goals.filter { $0.isCompleted }.count)/\(store.goals.count) done")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24).padding(.bottom, 12)

                if store.goals.isEmpty {
                    VStack(spacing: 12) {
                        Text("✨").font(.system(size: 40))
                        Text("Add your first goal below").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
                } else {
                    VStack(spacing: 10) {
                        ForEach(store.goals) { goal in
                            GoalRow(goal: goal) { store.toggle(goal) }
                        }
                        .onDelete { store.delete(at: $0) }
                    }
                    .padding(.horizontal, 16)
                }

                Button { showingAddGoal = true } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill").foregroundStyle(.pink)
                        Text("Add a goal").foregroundStyle(.pink)
                        Spacer()
                    }
                    .padding()
                    .background(.pink.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 16).padding(.top, 12)
            }
            .padding(.bottom, 40)
        }
        .background(.gray.opacity(0.1))
        .sheet(isPresented: $showingAddGoal) {
            AddGoalSheet(isPresented: $showingAddGoal) { store.add($0) }
        }
    }
}

struct GoalRow: View {
    let goal: Goal
    let onToggle: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(goal.isCompleted ? .pink : .secondary)
                    .animation(.spring(duration: 0.25), value: goal.isCompleted)
            }
            Text(goal.title).font(.body)
                .strikethrough(goal.isCompleted, color: .secondary)
                .foregroundStyle(goal.isCompleted ? .secondary : .primary)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

struct AddGoalSheet: View {
    @Binding var isPresented: Bool
    @State private var text = ""
    @FocusState private var isFocused: Bool
    let onAdd: (String) -> Void
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("What's your goal?").font(.title2.bold()).padding(.top, 8)
                TextField("e.g. Get into my dream university", text: $text, axis: .vertical)
                    .padding()
                    .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .focused($isFocused).lineLimit(3...6)
                Button {
                    onAdd(text); isPresented = false
                } label: {
                    Text("Add goal").font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(text.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.pink,
                                    in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }
            .padding(.horizontal, 24)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } } }
        }
        .presentationDetents([.medium])
        .onAppear { isFocused = true }
    }
}

// MARK: - SCREEN 2: Today ─────────────────────────────────────────────

struct TodoItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isDone: Bool = false
}

struct Reminder: Identifiable, Codable {
    var id = UUID()
    var title: String
    var type: ReminderType = .event
    enum ReminderType: String, Codable, CaseIterable {
        case event = "calendar"
        case hangout = "person.2"
        case assignment = "doc.text"
        case dayOff = "sun.max"
        var label: String {
            switch self {
            case .event: return "Event"
            case .hangout: return "Hangout"
            case .assignment: return "Assignment"
            case .dayOff: return "Day off"
            }
        }
    }
}

@Observable
class TodayStore {
    var todos: [TodoItem] = []
    var reminders: [Reminder] = []
    var lastPeriodDate: Date? = nil
    private let todosKey = "myplanner_todos"
    private let remindersKey = "myplanner_reminders"
    private let periodKey = "myplanner_period"
    private let todosDateKey = "myplanner_todos_date"

    init() {
        load()
        let today = Calendar.current.startOfDay(for: Date())
        let savedDate = UserDefaults.standard.object(forKey: todosDateKey) as? Date
        if savedDate == nil || !Calendar.current.isDate(today, inSameDayAs: savedDate!) {
            todos = []
            UserDefaults.standard.set(today, forKey: todosDateKey)
            save()
        }
    }

    func addTodo(_ title: String) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        todos.append(TodoItem(title: title))
        UserDefaults.standard.set(Calendar.current.startOfDay(for: Date()), forKey: todosDateKey)
        save()
    }
    func deleteTodo(at offsets: IndexSet) { todos.remove(atOffsets: offsets); save() }
    func deleteTodo(_ item: TodoItem) { todos.removeAll { $0.id == item.id }; save() }
    func toggleTodo(_ item: TodoItem) {
        if let i = todos.firstIndex(where: { $0.id == item.id }) { todos[i].isDone.toggle(); save() }
    }
    func addReminder(_ title: String, type: Reminder.ReminderType) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        reminders.append(Reminder(title: title, type: type)); save()
    }
    func deleteReminder(at offsets: IndexSet) { reminders.remove(atOffsets: offsets); save() }
    func recordPeriod(date: Date) { lastPeriodDate = date; save() }

    var isPinkMode: Bool {
        guard let last = lastPeriodDate else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        let next = Calendar.current.date(byAdding: .day, value: 28, to: last)!
        let diff = Calendar.current.dateComponents([.day], from: today, to: next).day ?? 999
        return diff >= 0 && diff <= 7
    }
    var daysUntilPeriod: Int? {
        guard let last = lastPeriodDate else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let next = Calendar.current.date(byAdding: .day, value: 28, to: last)!
        let diff = Calendar.current.dateComponents([.day], from: today, to: next).day ?? 0
        return max(0, diff)
    }

    private func save() {
        if let t = try? JSONEncoder().encode(todos) { UserDefaults.standard.set(t, forKey: todosKey) }
        if let r = try? JSONEncoder().encode(reminders) { UserDefaults.standard.set(r, forKey: remindersKey) }
        if let p = lastPeriodDate { UserDefaults.standard.set(p, forKey: periodKey) }
    }
    private func load() {
        if let d = UserDefaults.standard.data(forKey: todosKey),
           let v = try? JSONDecoder().decode([TodoItem].self, from: d) { todos = v }
        if let d = UserDefaults.standard.data(forKey: remindersKey),
           let v = try? JSONDecoder().decode([Reminder].self, from: d) { reminders = v }
        if let d = UserDefaults.standard.object(forKey: periodKey) as? Date { lastPeriodDate = d }
    }
}

struct TodayView: View {
    @State private var store = TodayStore()
    let calendarStore: CalendarStore
    let submissionsStore: SubmissionsStore
    let habitStore: HabitStore
    @State private var showAddTodo = false
    @State private var showPeriodPicker = false
    @State private var selectedPeriodDate = Date()

    var bgColor: Color { store.isPinkMode ? Color.pink.opacity(0.07) : Color.gray.opacity(0.07) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Date().formatted(.dateTime.weekday(.wide))).font(.title2).foregroundStyle(.secondary)
                    Text(Date().formatted(.dateTime.day().month(.wide).year())).font(.largeTitle.bold())
                }
                .padding(.horizontal, 24).padding(.top, 48)

                PeriodBannerView(store: store) { showPeriodPicker = true }
                    .padding(.horizontal, 16)

                SectionCard(title: "SCHEDULE", icon: "clock") {
                    let todayEvents = calendarStore.events(for: Date())
                    if todayEvents.isEmpty {
                        EmptyStateText("No events scheduled today")
                    } else {
                        VStack(spacing: 6) {
                            ForEach(todayEvents) { event in
                                HStack(spacing: 0) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(event.eventColor.color)
                                        .frame(width: 4)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.title).font(.subheadline.bold())
                                        Text("\(event.startTime.formatted(date: .omitted, time: .shortened)) – \(event.endTime.formatted(date: .omitted, time: .shortened))")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 8)
                                    Spacer()
                                }
                                .background(event.eventColor.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                SectionCard(title: "TODAY'S TO-DO", icon: "checklist") {
                    if store.todos.isEmpty { EmptyStateText("Nothing planned yet — add something!") }
                    else {
                        VStack(spacing: 8) {
                            ForEach(store.todos) { item in
                                TodoRowView(item: item) { store.toggleTodo(item) }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.deleteTodo(item)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    AddItemButton(label: "Add to-do") { showAddTodo = true }
                }
                .padding(.horizontal, 16)

                if !habitStore.habits.isEmpty {
                    SectionCard(title: "HABITS", icon: "checkmark.seal") {
                        VStack(spacing: 8) {
                            ForEach(habitStore.habits) { habit in
                                let done = habitStore.isCompleted(habit: habit, date: Date())
                                let streak = habitStore.streak(habit: habit)
                                HStack(spacing: 12) {
                                    Button { habitStore.toggle(habit: habit, date: Date()) } label: {
                                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 22))
                                            .foregroundStyle(done ? .pink : .secondary)
                                            .animation(.spring(duration: 0.2), value: done)
                                    }
                                    Text(habit.emoji).font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(habit.title).font(.subheadline)
                                            .foregroundStyle(done ? .secondary : .primary)
                                        if streak > 0 {
                                            HStack(spacing: 3) {
                                                Image(systemName: "flame.fill").font(.caption2).foregroundStyle(.orange)
                                                Text("\(streak)d streak").font(.caption).foregroundStyle(.orange)
                                            }
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .background(done ? Color.pink.opacity(0.06) : Color.gray.opacity(0.06),
                                            in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                let dueSoon = submissionsStore.upcoming.prefix(5)
                if !dueSoon.isEmpty {
                    SectionCard(title: "DUE SOON", icon: "tray.full") {
                        VStack(spacing: 8) {
                            ForEach(dueSoon) { sub in
                                HStack(spacing: 10) {
                                    Image(systemName: sub.type.icon)
                                        .font(.system(size: 14))
                                        .foregroundStyle(sub.status.color)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(sub.title).font(.subheadline.bold()).lineLimit(1)
                                        HStack(spacing: 4) {
                                            if !sub.className.isEmpty {
                                                Text(sub.className).font(.caption).foregroundStyle(.secondary)
                                                Text("·").font(.caption).foregroundStyle(.secondary)
                                            }
                                            Text(sub.dueDate.formatted(.dateTime.month(.abbreviated).day()))
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    let days = Calendar.current.dateComponents([.day],
                                        from: Calendar.current.startOfDay(for: Date()),
                                        to: Calendar.current.startOfDay(for: sub.dueDate)).day ?? 0
                                    Text(days == 0 ? "Today" : days == 1 ? "Tomorrow" : "\(days)d")
                                        .font(.caption.bold())
                                        .foregroundStyle(days <= 1 ? .red : days <= 3 ? .orange : .secondary)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 40)
        }
        .background(bgColor.animation(.easeInOut(duration: 1.0)))
        .sheet(isPresented: $showAddTodo) { AddTodoSheet(isPresented: $showAddTodo) { store.addTodo($0) } }
        .sheet(isPresented: $showPeriodPicker) {
            PeriodPickerSheet(isPresented: $showPeriodPicker, selectedDate: $selectedPeriodDate) {
                store.recordPeriod(date: selectedPeriodDate)
            }
        }
    }
}

struct PeriodBannerView: View {
    let store: TodayStore
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text("🌸").font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    if let days = store.daysUntilPeriod {
                        if days == 0 {
                            Text("Period may start today").font(.subheadline.bold()).foregroundStyle(.pink)
                        } else if store.isPinkMode {
                            Text("Period coming in \(days) day\(days == 1 ? "" : "s")").font(.subheadline.bold()).foregroundStyle(.pink)
                        } else {
                            Text("\(days) days until next period").font(.subheadline.bold()).foregroundStyle(.primary)
                        }
                        Text("Based on 28-day cycle · tap to update").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Track your period").font(.subheadline.bold()).foregroundStyle(.primary)
                        Text("Tap to record your last period date").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .background(store.isPinkMode ? Color.pink.opacity(0.15) : Color.pink.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(store.isPinkMode ? Color.pink.opacity(0.4) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct PeriodPickerSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedDate: Date
    let onSave: () -> Void
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("When did your last period start?").font(.title3.bold()).multilineTextAlignment(.center).padding(.top, 8)
                Text("I'll remind you 7 days before your next one 🌸").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                DatePicker("Last period date", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical).tint(.pink)
                Button { onSave(); isPresented = false } label: {
                    Text("Save").font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(.pink, in: RoundedRectangle(cornerRadius: 14))
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } } }
        }
        .presentationDetents([.large])
    }
}

struct TodoRowView: View {
    let item: TodoItem
    let onToggle: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22)).foregroundStyle(item.isDone ? .pink : .secondary)
                    .animation(.spring(duration: 0.2), value: item.isDone)
            }
            Text(item.title).strikethrough(item.isDone, color: .secondary)
                .foregroundStyle(item.isDone ? .secondary : .primary)
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct ReminderRowView: View {
    let reminder: Reminder
    var iconColor: Color {
        switch reminder.type {
        case .event: return .blue
        case .hangout: return .green
        case .assignment: return .orange
        case .dayOff: return .yellow
        }
    }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: reminder.type.rawValue).font(.system(size: 16))
                .foregroundStyle(iconColor).frame(width: 28)
            Text(reminder.title).font(.body)
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct AddTodoSheet: View {
    @Binding var isPresented: Bool
    @State private var text = ""
    @FocusState private var focused: Bool
    let onAdd: (String) -> Void
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("What do you need to do today?").font(.title2.bold()).padding(.top, 8)
                TextField("e.g. Study for exam", text: $text, axis: .vertical)
                    .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .focused($focused).lineLimit(2...4)
                Button { onAdd(text); isPresented = false } label: {
                    Text("Add").font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(text.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .pink,
                                    in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }
            .padding(.horizontal, 24)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } } }
        }
        .presentationDetents([.medium]).onAppear { focused = true }
    }
}

struct AddReminderSheet: View {
    @Binding var isPresented: Bool
    @State private var text = ""
    @State private var type: Reminder.ReminderType = .event
    @FocusState private var focused: Bool
    let onAdd: (String, Reminder.ReminderType) -> Void
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Add a reminder").font(.title2.bold()).padding(.top, 8)
                TextField("e.g. Hang out with Mika", text: $text)
                    .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .focused($focused)
                Text("TYPE").font(.caption).foregroundStyle(.secondary).tracking(1)
                HStack(spacing: 10) {
                    ForEach(Reminder.ReminderType.allCases, id: \.self) { t in
                        Button { type = t } label: {
                            VStack(spacing: 4) {
                                Image(systemName: t.rawValue).font(.system(size: 18))
                                Text(t.label).font(.caption2)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(type == t ? Color.pink.opacity(0.15) : Color.secondary.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(type == t ? .pink : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button { onAdd(text, type); isPresented = false } label: {
                    Text("Add reminder").font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(text.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .pink,
                                    in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }
            .padding(.horizontal, 24)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } } }
        }
        .presentationDetents([.medium]).onAppear { focused = true }
    }
}

// Reusable helpers
struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption).foregroundStyle(.secondary)
                Text(title).font(.caption).foregroundStyle(.secondary).tracking(1)
            }
            content
        }
        .padding(16).background(.background, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

struct AddItemButton: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "plus.circle.fill").foregroundStyle(.pink)
                Text(label).foregroundStyle(.pink)
                Spacer()
            }
            .padding(.top, 4)
        }
        .buttonStyle(.plain)
    }
}

struct EmptyStateText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 8)
    }
}

// MARK: - SCREEN 3: Habits ────────────────────────────────────────────

struct Habit: Identifiable, Codable {
    var id = UUID()
    var title: String
    var emoji: String
    var logs: [String] = []
}

@Observable
class HabitStore {
    var habits: [Habit] = []
    private let key = "myplanner_habits"

    init() { load() }

    func add(title: String, emoji: String) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        habits.append(Habit(title: title, emoji: emoji)); save()
    }
    func delete(at offsets: IndexSet) { habits.remove(atOffsets: offsets); save() }

    func toggle(habit: Habit, date: Date) {
        guard let i = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        let k = dateKey(date)
        if habits[i].logs.contains(k) { habits[i].logs.removeAll { $0 == k } }
        else { habits[i].logs.append(k) }
        save()
    }
    func isCompleted(habit: Habit, date: Date) -> Bool { habit.logs.contains(dateKey(date)) }

    func streak(habit: Habit) -> Int {
        var count = 0
        var date = Calendar.current.startOfDay(for: Date())
        while habit.logs.contains(dateKey(date)) {
            count += 1
            date = Calendar.current.date(byAdding: .day, value: -1, to: date)!
        }
        return count
    }
    func rate(habit: Habit, dates: [Date]) -> Double {
        guard !dates.isEmpty else { return 0 }
        return Double(dates.filter { habit.logs.contains(dateKey($0)) }.count) / Double(dates.count)
    }
    private func dateKey(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    private func save() {
        if let e = try? JSONEncoder().encode(habits) { UserDefaults.standard.set(e, forKey: key) }
    }
    private func load() {
        if let d = UserDefaults.standard.data(forKey: key),
           let v = try? JSONDecoder().decode([Habit].self, from: d) { habits = v }
    }
}

enum HabitViewMode: String, CaseIterable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case annual = "Annual"
}

struct HabitView: View {
    let store: HabitStore
    @State private var viewMode: HabitViewMode = .weekly
    @State private var showAddHabit = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("View", selection: $viewMode) {
                        ForEach(HabitViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).padding(.horizontal, 16).padding(.top, 8)

                    if store.habits.isEmpty {
                        VStack(spacing: 16) {
                            Text("🌱").font(.system(size: 50))
                            Text("No habits yet").font(.title3.bold())
                            Text("Start building a habit — even one small thing daily adds up!")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center).padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 60)
                    } else {
                        VStack(spacing: 14) {
                            ForEach(store.habits) { habit in
                                HabitCard(habit: habit, store: store, viewMode: viewMode)
                            }
                            .onDelete { store.delete(at: $0) }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color.gray.opacity(0.07))
            .navigationTitle("Habits")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddHabit = true } label: {
                        Image(systemName: "plus").foregroundStyle(.pink)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddHabit) {
            AddHabitSheet(isPresented: $showAddHabit) { store.add(title: $0, emoji: $1) }
        }
    }
}

struct HabitCard: View {
    let habit: Habit
    let store: HabitStore
    let viewMode: HabitViewMode

    var completionRate: Double {
        switch viewMode {
        case .weekly: return store.rate(habit: habit, dates: last7Days())
        case .monthly: return store.rate(habit: habit, dates: daysInCurrentMonth())
        case .annual: return store.rate(habit: habit, dates: last365Days())
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(habit.emoji).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.title).font(.headline)
                    let s = store.streak(habit: habit)
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill").font(.caption2)
                            .foregroundStyle(s > 0 ? .orange : .secondary)
                        Text(s > 0 ? "\(s) day streak" : "No streak yet")
                            .font(.caption).foregroundStyle(s > 0 ? .orange : .secondary)
                    }
                }
                Spacer()
                Text("\(Int(completionRate * 100))%")
                    .font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(completionRate > 0.7 ? Color.pink.opacity(0.15) : Color.gray.opacity(0.12), in: Capsule())
                    .foregroundStyle(completionRate > 0.7 ? .pink : .secondary)
            }
            switch viewMode {
            case .weekly: WeeklyGrid(habit: habit, store: store)
            case .monthly: MonthlyGrid(habit: habit, store: store)
            case .annual: AnnualGrid(habit: habit, store: store)
            }
        }
        .padding(16).background(.background, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

struct WeeklyGrid: View {
    let habit: Habit
    let store: HabitStore
    var days: [Date] { last7Days() }
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                VStack(spacing: 4) {
                    Text(singleDayLetter(date)).font(.caption2).foregroundStyle(.secondary)
                    let done = store.isCompleted(habit: habit, date: date)
                    let isToday = Calendar.current.isDateInToday(date)
                    Button { store.toggle(habit: habit, date: date) } label: {
                        Circle().fill(done ? Color.pink : Color.gray.opacity(0.15))
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(isToday ? Color.pink : Color.clear, lineWidth: 2))
                            .overlay(Image(systemName: "checkmark").font(.caption.bold())
                                .foregroundStyle(.white).opacity(done ? 1 : 0))
                            .animation(.spring(duration: 0.2), value: done)
                    }
                    .buttonStyle(.plain)
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.caption2)
                        .foregroundStyle(isToday ? .pink : .secondary)
                        .fontWeight(isToday ? .bold : .regular)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    func singleDayLetter(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEEEE"; return f.string(from: date)
    }
}

struct MonthlyGrid: View {
    let habit: Habit
    let store: HabitStore
    var days: [Date] { daysInCurrentMonth() }
    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                ForEach(["M","T","W","T","F","S","S"], id: \.self) { d in
                    Text(d).font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<leadingOffset(), id: \.self) { _ in Color.clear.frame(height: 28) }
                ForEach(days, id: \.self) { date in
                    let done = store.isCompleted(habit: habit, date: date)
                    let isToday = Calendar.current.isDateInToday(date)
                    let isFuture = date > Date()
                    Button { if !isFuture { store.toggle(habit: habit, date: date) } } label: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(done ? Color.pink : isFuture ? Color.clear : Color.gray.opacity(0.12))
                            .frame(height: 28)
                            .overlay(Text("\(Calendar.current.component(.day, from: date))")
                                .font(.caption2)
                                .foregroundStyle(done ? .white : isToday ? .pink : isFuture ? .secondary.opacity(0.4) : .primary)
                                .fontWeight(isToday ? .bold : .regular))
                            .overlay(RoundedRectangle(cornerRadius: 6)
                                .stroke(isToday ? Color.pink : Color.clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain).animation(.spring(duration: 0.15), value: done)
                }
            }
        }
    }
    func leadingOffset() -> Int {
        guard let first = days.first else { return 0 }
        let weekday = Calendar.current.component(.weekday, from: first)
        return (weekday + 5) % 7
    }
}

struct AnnualGrid: View {
    let habit: Habit
    let store: HabitStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Past 365 days").font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 2) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("M").font(.system(size: 9)).foregroundStyle(.secondary).frame(height: 13)
                        Text("").frame(height: 13)
                        Text("W").font(.system(size: 9)).foregroundStyle(.secondary).frame(height: 13)
                        Text("").frame(height: 13)
                        Text("F").font(.system(size: 9)).foregroundStyle(.secondary).frame(height: 13)
                        Text("").frame(height: 13)
                        Text("").frame(height: 13)
                    }

                    let weeks = calendarWeeks()
                    HStack(alignment: .top, spacing: 2) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                            VStack(spacing: 2) {
                                ForEach(Array(week.enumerated()), id: \.offset) { _, optDate in
                                    if let date = optDate {
                                        let done = store.isCompleted(habit: habit, date: date)
                                        let isToday = Calendar.current.isDateInToday(date)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(done ? Color.pink : isToday ? Color.pink.opacity(0.3) : Color.gray.opacity(0.12))
                                            .frame(width: 13, height: 13)
                                    } else {
                                        Color.clear.frame(width: 13, height: 13)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            HStack(spacing: 6) {
                Text("Less").font(.caption2).foregroundStyle(.secondary)
                ForEach([0.0, 0.3, 0.6, 1.0], id: \.self) { o in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(o == 0 ? Color.gray.opacity(0.15) : Color.pink.opacity(o))
                        .frame(width: 12, height: 12)
                }
                Text("More").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    func calendarWeeks() -> [[Date?]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let startDate = cal.date(byAdding: .day, value: -364, to: today) else { return [] }

        var weeks: [[Date?]] = []
        var currentDate = startDate

        let firstWeekday = (cal.component(.weekday, from: startDate) + 5) % 7
        if firstWeekday > 0 {
            var week: [Date?] = Array(repeating: nil, count: firstWeekday)
            while week.count < 7 && currentDate <= today {
                week.append(currentDate)
                currentDate = cal.date(byAdding: .day, value: 1, to: currentDate)!
            }
            while week.count < 7 { week.append(nil) }
            weeks.append(week)
        }

        while currentDate <= today {
            var week: [Date?] = []
            for _ in 0..<7 {
                if currentDate <= today {
                    week.append(currentDate)
                    currentDate = cal.date(byAdding: .day, value: 1, to: currentDate)!
                } else {
                    week.append(nil)
                }
            }
            weeks.append(week)
        }

        return weeks
    }
}

struct AddHabitSheet: View {
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var selectedEmoji = "⭐"
    @FocusState private var focused: Bool
    let onAdd: (String, String) -> Void
    let emojis = ["⭐","💪","📚","🏃","🧘","✍️","🎵","🌿","💧","🍎","😴","🇰🇷","🎨","💻","🙏"]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("New Habit").font(.title2.bold()).padding(.top, 8)
                Text("PICK AN EMOJI").font(.caption).foregroundStyle(.secondary).tracking(1)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button { selectedEmoji = emoji } label: {
                            Text(emoji).font(.title2).frame(width: 48, height: 48)
                                .background(selectedEmoji == emoji ? Color.pink.opacity(0.2) : Color.gray.opacity(0.1),
                                            in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedEmoji == emoji ? Color.pink : Color.clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("HABIT NAME").font(.caption).foregroundStyle(.secondary).tracking(1)
                TextField("e.g. Learn Korean, Go to gym...", text: $title)
                    .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .focused($focused)
                Button { onAdd(title, selectedEmoji); isPresented = false } label: {
                    Text("Add Habit").font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(title.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .pink,
                                    in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }
            .padding(.horizontal, 24)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } } }
        }
        .presentationDetents([.large]).onAppear { focused = true }
    }
}

// MARK: - Date Helpers ────────────────────────────────────────────────

func last7Days() -> [Date] {
    let cal = Calendar.current
    return (0..<7).compactMap { cal.date(byAdding: .day, value: -6 + $0, to: cal.startOfDay(for: Date())) }
}

func daysInCurrentMonth() -> [Date] {
    let cal = Calendar.current
    guard let range = cal.range(of: .day, in: .month, for: Date()),
          let first = cal.date(from: cal.dateComponents([.year, .month], from: Date()))
    else { return [] }
    return range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: first) }
}

func last365Days() -> [Date] {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    return (0..<365).compactMap { cal.date(byAdding: .day, value: -364 + $0, to: today) }
}

func last365DaysGroupedByWeek() -> [[Date]] {
    var weeks: [[Date]] = []; var week: [Date] = []
    for day in last365Days() {
        week.append(day)
        if week.count == 7 { weeks.append(week); week = [] }
    }
    if !week.isEmpty { weeks.append(week) }
    return weeks
}
// MARK: - SCREEN 4: Classes & Grades ─────────────────────────────────

struct GradeComponent: Identifiable, Codable {
    var id = UUID()
    var name: String        // e.g. "Midterm", "Final", "Assignment"
    var weight: Double      // e.g. 30 (means 30%)
    var score: Double?      // e.g. 85 (out of 100), nil if not graded yet
}

struct ClassItem: Identifiable, Codable {
    var id = UUID()
    var name: String        // e.g. "ECON 101"
    var emoji: String       // e.g. "📊"
    var components: [GradeComponent] = []

    // Weighted average of graded components
    var currentGrade: Double? {
        let graded = components.filter { $0.score != nil }
        guard !graded.isEmpty else { return nil }
        let totalWeight = graded.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return nil }
        let weighted = graded.reduce(0.0) { $0 + ($1.score! * $1.weight) }
        return weighted / totalWeight
    }

    var letterGrade: String {
        guard let g = currentGrade else { return "—" }
        switch g {
        case 90...: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }

    var gradeColor: Color {
        guard let g = currentGrade else { return .secondary }
        switch g {
        case 90...: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        default: return .red
        }
    }
}

@Observable
class ClassStore {
    var classes: [ClassItem] = []
    private let key = "myplanner_classes"

    init() { load() }

    func addClass(name: String, emoji: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        classes.append(ClassItem(name: name, emoji: emoji))
        save()
    }

    func deleteClass(at offsets: IndexSet) {
        classes.remove(atOffsets: offsets)
        save()
    }

    func addComponent(to classItem: ClassItem, name: String, weight: Double) {
        guard let i = classes.firstIndex(where: { $0.id == classItem.id }) else { return }
        classes[i].components.append(GradeComponent(name: name, weight: weight))
        save()
    }

    func updateScore(classItem: ClassItem, component: GradeComponent, score: Double?) {
        guard let ci = classes.firstIndex(where: { $0.id == classItem.id }),
              let gi = classes[ci].components.firstIndex(where: { $0.id == component.id })
        else { return }
        classes[ci].components[gi].score = score
        save()
    }

    func deleteComponent(classItem: ClassItem, at offsets: IndexSet) {
        guard let i = classes.firstIndex(where: { $0.id == classItem.id }) else { return }
        classes[i].components.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        if let e = try? JSONEncoder().encode(classes) { UserDefaults.standard.set(e, forKey: key) }
    }
    private func load() {
        if let d = UserDefaults.standard.data(forKey: key),
           let v = try? JSONDecoder().decode([ClassItem].self, from: d) { classes = v }
    }
}

// MARK: - Classes Main View

struct ClassesView: View {
    @State private var store = ClassStore()
    @State private var showAddClass = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if store.classes.isEmpty {
                        VStack(spacing: 16) {
                            Text("📚").font(.system(size: 50))
                            Text("No classes yet").font(.title3.bold())
                            Text("Add your classes and track every grade in one place.")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center).padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 60)
                    } else {
                        ForEach(store.classes) { classItem in
                            NavigationLink(destination: ClassDetailView(classItem: classItem, store: store)) {
                                ClassCardView(classItem: classItem)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { store.deleteClass(at: $0) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.gray.opacity(0.07))
            .navigationTitle("Classes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddClass = true } label: {
                        Image(systemName: "plus").foregroundStyle(.pink)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddClass) {
            AddClassSheet(isPresented: $showAddClass) { name, emoji in
                store.addClass(name: name, emoji: emoji)
            }
        }
    }
}

// MARK: - Class Card (summary)

struct ClassCardView: View {
    let classItem: ClassItem

    var body: some View {
        HStack(spacing: 14) {
            // Emoji + grade circle
            ZStack {
                Circle()
                    .fill(classItem.gradeColor.opacity(0.15))
                    .frame(width: 52, height: 52)
                Text(classItem.emoji)
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(classItem.name).font(.headline)
                let graded = classItem.components.filter { $0.score != nil }.count
                let total = classItem.components.count
                Text(total == 0 ? "No components yet" : "\(graded)/\(total) graded")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            // Grade display
            VStack(alignment: .trailing, spacing: 2) {
                Text(classItem.letterGrade)
                    .font(.title2.bold())
                    .foregroundStyle(classItem.gradeColor)
                if let g = classItem.currentGrade {
                    Text(String(format: "%.1f%%", g))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

// MARK: - Class Detail View

struct ClassDetailView: View {
    let classItem: ClassItem
    let store: ClassStore
    @State private var showAddComponent = false
    @State private var editingComponent: GradeComponent? = nil
    @State private var scoreInput = ""

    // Live version from store
    var live: ClassItem { store.classes.first(where: { $0.id == classItem.id }) ?? classItem }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── Grade summary card ────────────────────────
                VStack(spacing: 8) {
                    Text(live.emoji).font(.system(size: 44))
                    if let grade = live.currentGrade {
                        Text(String(format: "%.1f%%", grade))
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(live.gradeColor)
                        Text(live.letterGrade)
                            .font(.title2)
                            .foregroundStyle(live.gradeColor)
                    } else {
                        Text("—").font(.system(size: 48, weight: .bold)).foregroundStyle(.secondary)
                        Text("No grades yet").font(.subheadline).foregroundStyle(.secondary)
                    }

                    // Weight total warning
                    let totalWeight = live.components.reduce(0) { $0 + $1.weight }
                    if !live.components.isEmpty {
                        Text("Total weight: \(Int(totalWeight))%")
                            .font(.caption)
                            .foregroundStyle(abs(totalWeight - 100) < 0.1 ? .green : .orange)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(.background, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                .padding(.horizontal, 16)

                // ── Components list ───────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("GRADE BREAKDOWN")
                            .font(.caption).foregroundStyle(.secondary).tracking(1)
                        Spacer()
                        Button { showAddComponent = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add")
                            }
                            .font(.caption).foregroundStyle(.pink)
                        }
                    }

                    if live.components.isEmpty {
                        Text("Add components like Midterm, Final, Assignment...")
                            .font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(live.components) { comp in
                                ComponentRowView(
                                    component: comp,
                                    onTapScore: {
                                        editingComponent = comp
                                        scoreInput = comp.score.map { String(format: "%.1f", $0) } ?? ""
                                    }
                                )
                            }
                            .onDelete { store.deleteComponent(classItem: live, at: $0) }
                        }
                    }
                }
                .padding(16)
                .background(.background, in: RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 40)
            .padding(.top, 8)
        }
        .background(Color.gray.opacity(0.07))
        .navigationTitle(live.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddComponent) {
            AddComponentSheet(isPresented: $showAddComponent) { name, weight in
                store.addComponent(to: live, name: name, weight: weight)
            }
        }
        .sheet(item: $editingComponent) { comp in
            EnterScoreSheet(
                component: comp,
                scoreInput: $scoreInput
            ) { score in
                store.updateScore(classItem: live, component: comp, score: score)
            }
        }
    }
}

// MARK: - Component Row

struct ComponentRowView: View {
    let component: GradeComponent
    let onTapScore: () -> Void

    var scoreColor: Color {
        guard let s = component.score else { return .secondary }
        switch s {
        case 90...: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(component.name).font(.subheadline.bold())
                Text("Weight: \(Int(component.weight))%")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onTapScore) {
                if let score = component.score {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%.1f", score))
                            .font(.headline).foregroundStyle(scoreColor)
                        Text("/ 100").font(.caption2).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Enter score")
                        .font(.caption).foregroundStyle(.pink)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.pink.opacity(0.1), in: Capsule())
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Add Class Sheet

struct AddClassSheet: View {
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var selectedEmoji = "📚"
    @FocusState private var focused: Bool
    let onAdd: (String, String) -> Void

    let emojis = ["📚","📊","🔬","🎨","🎵","📐","🌍","💻","⚗️","📖","🧠","🏛️","💰","🎭","🔭"]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("Add a Class").font(.title2.bold()).padding(.top, 8)

                Text("PICK AN EMOJI").font(.caption).foregroundStyle(.secondary).tracking(1)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button { selectedEmoji = emoji } label: {
                            Text(emoji).font(.title2).frame(width: 48, height: 48)
                                .background(selectedEmoji == emoji ? Color.pink.opacity(0.2) : Color.gray.opacity(0.1),
                                            in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedEmoji == emoji ? Color.pink : Color.clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("CLASS NAME").font(.caption).foregroundStyle(.secondary).tracking(1)
                TextField("e.g. ECON 101, History, Math...", text: $name)
                    .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .focused($focused)

                Button { onAdd(name, selectedEmoji); isPresented = false } label: {
                    Text("Add Class").font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(name.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .pink,
                                    in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }
            .padding(.horizontal, 24)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } } }
        }
        .presentationDetents([.large]).onAppear { focused = true }
    }
}

// MARK: - Add Component Sheet

struct AddComponentSheet: View {
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var weightText = ""
    @FocusState private var focused: Bool
    let onAdd: (String, Double) -> Void

    let suggestions = ["Midterm","Final","Assignment","Quiz","Project","Participation","Lab","Presentation"]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Add Grade Component").font(.title2.bold()).padding(.top, 8)

                Text("QUICK PICK").font(.caption).foregroundStyle(.secondary).tracking(1)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    ForEach(suggestions, id: \.self) { s in
                        Button { name = s } label: {
                            Text(s).font(.subheadline)
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(name == s ? Color.pink.opacity(0.15) : Color.gray.opacity(0.1),
                                            in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(name == s ? .pink : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("COMPONENT NAME").font(.caption).foregroundStyle(.secondary).tracking(1)
                TextField("e.g. Midterm Exam", text: $name)
                    .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .focused($focused)

                Text("WEIGHT (%)").font(.caption).foregroundStyle(.secondary).tracking(1)
                TextField("e.g. 30", text: $weightText)
                    .keyboardType(.decimalPad)
                    .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                let weight = Double(weightText) ?? 0
                let isValid = !name.trimmingCharacters(in: .whitespaces).isEmpty && weight > 0

                Button {
                    onAdd(name, weight)
                    isPresented = false
                } label: {
                    Text("Add Component").font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(isValid ? Color.pink : Color.gray, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!isValid)
                Spacer()
            }
            .padding(.horizontal, 24)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } } }
        }
        .presentationDetents([.large]).onAppear { focused = true }
    }
}

// MARK: - Enter Score Sheet

struct EnterScoreSheet: View {
    let component: GradeComponent
    @Binding var scoreInput: String
    let onSave: (Double?) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Enter Score").font(.title2.bold()).padding(.top, 8)
                Text(component.name).font(.title3).foregroundStyle(.secondary)

                Text("YOUR SCORE (out of 100)")
                    .font(.caption).foregroundStyle(.secondary).tracking(1)
                TextField("e.g. 87.5", text: $scoreInput)
                    .keyboardType(.decimalPad)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                if let score = Double(scoreInput) {
                    let letter: String = {
                        switch score {
                        case 90...: return "A 🎉"
                        case 80..<90: return "B 👍"
                        case 70..<80: return "C"
                        case 60..<70: return "D"
                        default: return "F"
                        }
                    }()
                    Text("That's a \(letter)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button {
                        onSave(nil)
                        dismiss()
                    } label: {
                        Text("Clear score").font(.subheadline)
                            .frame(maxWidth: .infinity).padding()
                            .background(.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        onSave(Double(scoreInput))
                        dismiss()
                    } label: {
                        Text("Save").font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(Double(scoreInput) != nil ? Color.pink : Color.gray,
                                        in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(Double(scoreInput) == nil)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}
// MARK: - SCREEN 5: Notes ────────────────────────────────────────────

struct Note: Identifiable, Codable {
    var id = UUID()
    var title: String
    var body: String
    var isPinned: Bool = false
    var createdAt: Date = Date()

    var preview: String {
        let lines = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return lines.isEmpty ? "No additional text" : lines
    }
}

@Observable
class NotesStore {
    var notes: [Note] = []
    private let key = "myplanner_notes"

    init() { load() }

    var pinned: [Note] { notes.filter { $0.isPinned }.sorted { $0.createdAt > $1.createdAt } }
    var unpinned: [Note] { notes.filter { !$0.isPinned }.sorted { $0.createdAt > $1.createdAt } }

    func add(title: String, body: String) {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        notes.append(Note(title: t, body: body))
        save()
    }

    func delete(at offsets: IndexSet, pinned: Bool) {
        let list = pinned ? self.pinned : self.unpinned
        for i in offsets {
            let noteId = list[i].id
            notes.removeAll { $0.id == noteId }
        }
        save()
    }

    func togglePin(_ note: Note) {
        if let i = notes.firstIndex(where: { $0.id == note.id }) {
            notes[i].isPinned.toggle()
            save()
        }
    }

    func update(_ note: Note, title: String, body: String) {
        if let i = notes.firstIndex(where: { $0.id == note.id }) {
            notes[i].title = title
            notes[i].body = body
            save()
        }
    }

    private func save() {
        if let e = try? JSONEncoder().encode(notes) { UserDefaults.standard.set(e, forKey: key) }
    }
    private func load() {
        if let d = UserDefaults.standard.data(forKey: key),
           let v = try? JSONDecoder().decode([Note].self, from: d) { notes = v }
    }
}

// MARK: - Notes Main View

struct NotesView: View {
    @State private var store = NotesStore()
    @State private var showAddNote = false
    @State private var searchText = ""
    @State private var selectedNote: Note? = nil

    var filtered: [Note] {
        if searchText.isEmpty { return [] }
        return store.notes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.body.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search notes...", text: $searchText)
                    }
                    .padding(10)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                    if store.notes.isEmpty {
                        VStack(spacing: 16) {
                            Text("💡").font(.system(size: 50))
                            Text("No notes yet").font(.title3.bold())
                            Text("Capture your ideas, thoughts, and anything you don't want to forget.")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center).padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 60)

                    } else if !searchText.isEmpty {
                        // Search results
                        noteSection(title: "Results", notes: filtered, isPinned: false)

                    } else {
                        // Pinned
                        if !store.pinned.isEmpty {
                            noteSection(title: "📌 Pinned", notes: store.pinned, isPinned: true)
                        }
                        // All notes
                        noteSection(title: "Notes", notes: store.unpinned, isPinned: false)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color.gray.opacity(0.07))
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddNote = true } label: {
                        Image(systemName: "square.and.pencil").foregroundStyle(.pink)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddNote) {
            NoteEditorSheet(isPresented: $showAddNote, note: nil) { title, body in
                store.add(title: title, body: body)
            }
        }
        .sheet(item: $selectedNote) { note in
            NoteEditorSheet(isPresented: .constant(true), note: note) { title, body in
                store.update(note, title: title, body: body)
                selectedNote = nil
            }
        }
    }

    @ViewBuilder
    func noteSection(title: String, notes: [Note], isPinned: Bool) -> some View {
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption).foregroundStyle(.secondary).tracking(1)
                    .padding(.horizontal, 24)
                VStack(spacing: 8) {
                    ForEach(notes) { note in
                        NoteCardView(note: note,
                            onTap: { selectedNote = note },
                            onPin: { store.togglePin(note) }
                        )
                    }
                    .onDelete { store.delete(at: $0, pinned: isPinned) }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Note Card

struct NoteCardView: View {
    let note: Note
    let onTap: () -> Void
    let onPin: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(note.title).font(.headline).lineLimit(1)
                    Spacer()
                    if note.isPinned {
                        Image(systemName: "pin.fill").font(.caption).foregroundStyle(.pink)
                    }
                }
                Text(note.preview)
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                Text(note.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.caption2).foregroundStyle(.secondary.opacity(0.7))
            }
            .padding(14)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onPin()
            } label: {
                Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
            }
        }
    }
}

// MARK: - Note Editor Sheet

struct NoteEditorSheet: View {
    @Binding var isPresented: Bool
    let note: Note?
    let onSave: (String, String) -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Title", text: $title)
                    .font(.title2.bold())
                    .focused($titleFocused)

                Divider()

                TextEditor(text: $bodyText)
                    .font(.body)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scrollContentBackground(.hidden)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title, bodyText)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(title.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .pink)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            if let n = note { title = n.title; bodyText = n.body }
            else { titleFocused = true }
        }
    }
}

// MARK: - SCREEN 6: Submissions & Events ─────────────────────────────

enum SubmissionStatus: String, Codable, CaseIterable {
    case pending   = "Pending"
    case submitted = "Submitted"
    case late      = "Late"
    case upcoming  = "Upcoming"

    var color: Color {
        switch self {
        case .pending:   return .orange
        case .submitted: return .green
        case .late:      return .red
        case .upcoming:  return .blue
        }
    }
    var icon: String {
        switch self {
        case .pending:   return "clock"
        case .submitted: return "checkmark.circle.fill"
        case .late:      return "exclamationmark.circle.fill"
        case .upcoming:  return "calendar.badge.clock"
        }
    }
}

enum SubmissionType: String, Codable, CaseIterable {
    case assignment = "Assignment"
    case exam       = "Exam"
    case project    = "Project"
    case event      = "Event"
    case other      = "Other"

    var icon: String {
        switch self {
        case .assignment: return "doc.text"
        case .exam:       return "pencil.and.list.clipboard"
        case .project:    return "folder"
        case .event:      return "calendar"
        case .other:      return "tray"
        }
    }
}

struct Submission: Identifiable, Codable {
    var id = UUID()
    var title: String
    var className: String   // which class it's for
    var type: SubmissionType = .assignment
    var dueDate: Date
    var status: SubmissionStatus = .pending
    var notes: String = ""
}

@Observable
class SubmissionsStore {
    var submissions: [Submission] = []
    private let key = "myplanner_submissions"

    init() { load() }

    var upcoming: [Submission] {
        submissions.filter { $0.dueDate >= Calendar.current.startOfDay(for: Date()) && $0.status != .submitted }
            .sorted { $0.dueDate < $1.dueDate }
    }
    var past: [Submission] {
        submissions.filter { $0.dueDate < Calendar.current.startOfDay(for: Date()) || $0.status == .submitted }
            .sorted { $0.dueDate > $1.dueDate }
    }

    func add(title: String, className: String, type: SubmissionType, dueDate: Date, notes: String) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        submissions.append(Submission(title: title, className: className, type: type, dueDate: dueDate, notes: notes))
        save()
    }

    func updateStatus(_ submission: Submission, status: SubmissionStatus) {
        if let i = submissions.firstIndex(where: { $0.id == submission.id }) {
            submissions[i].status = status
            save()
        }
    }

    func delete(at offsets: IndexSet, from list: [Submission]) {
        for i in offsets {
            let id = list[i].id
            submissions.removeAll { $0.id == id }
        }
        save()
    }

    private func save() {
        if let e = try? JSONEncoder().encode(submissions) { UserDefaults.standard.set(e, forKey: key) }
    }
    private func load() {
        if let d = UserDefaults.standard.data(forKey: key),
           let v = try? JSONDecoder().decode([Submission].self, from: d) { submissions = v }
    }
}

// MARK: - Submissions Main View

struct SubmissionsView: View {
    let store: SubmissionsStore
    @State private var showAdd = false
    @State private var showPast = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Upcoming ──────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Text("UPCOMING")
                            .font(.caption).foregroundStyle(.secondary).tracking(1)
                            .padding(.horizontal, 24)

                        if store.upcoming.isEmpty {
                            VStack(spacing: 10) {
                                Text("🎉").font(.system(size: 36))
                                Text("All clear! Nothing due soon.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 30)
                            .background(.background, in: RoundedRectangle(cornerRadius: 18))
                            .padding(.horizontal, 16)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(store.upcoming) { sub in
                                    SubmissionCardView(submission: sub) { newStatus in
                                        store.updateStatus(sub, status: newStatus)
                                    }
                                }
                                .onDelete { store.delete(at: $0, from: store.upcoming) }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    // ── Past / Done ───────────────────────────────
                    if !store.past.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                withAnimation { showPast.toggle() }
                            } label: {
                                HStack {
                                    Text("PAST & SUBMITTED")
                                        .font(.caption).foregroundStyle(.secondary).tracking(1)
                                    Spacer()
                                    Image(systemName: showPast ? "chevron.up" : "chevron.down")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 24)
                            }
                            .buttonStyle(.plain)

                            if showPast {
                                VStack(spacing: 8) {
                                    ForEach(store.past) { sub in
                                        SubmissionCardView(submission: sub) { newStatus in
                                            store.updateStatus(sub, status: newStatus)
                                        }
                                    }
                                    .onDelete { store.delete(at: $0, from: store.past) }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
                .padding(.top, 8)
            }
            .background(Color.gray.opacity(0.07))
            .navigationTitle("Submissions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus").foregroundStyle(.pink)
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddSubmissionSheet(isPresented: $showAdd) { title, className, type, date, notes in
                store.add(title: title, className: className, type: type, dueDate: date, notes: notes)
            }
        }
    }
}

// MARK: - Submission Card

struct SubmissionCardView: View {
    let submission: Submission
    let onStatusChange: (SubmissionStatus) -> Void

    var daysUntil: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                        to: Calendar.current.startOfDay(for: submission.dueDate)).day ?? 0
    }

    var dueLabel: String {
        if submission.status == .submitted { return "Submitted ✓" }
        switch daysUntil {
        case 0: return "Due today!"
        case 1: return "Due tomorrow"
        case let d where d < 0: return "\(-d) days ago"
        default: return "Due in \(daysUntil) days"
        }
    }

    var dueLabelColor: Color {
        if submission.status == .submitted { return .green }
        switch daysUntil {
        case ...0: return .red
        case 1...3: return .orange
        default: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                // Type icon
                Image(systemName: submission.type.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(submission.status.color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(submission.title).font(.subheadline.bold()).lineLimit(1)
                    if !submission.className.isEmpty {
                        Text(submission.className).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Status badge
                Text(submission.status.rawValue)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(submission.status.color.opacity(0.15), in: Capsule())
                    .foregroundStyle(submission.status.color)
            }

            HStack {
                Image(systemName: "calendar").font(.caption2).foregroundStyle(.secondary)
                Text(submission.dueDate.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(dueLabel).font(.caption.bold()).foregroundStyle(dueLabelColor)
            }

            if !submission.notes.isEmpty {
                Text(submission.notes).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }

            // Quick status buttons
            HStack(spacing: 8) {
                if submission.status == .submitted {
                    Button {
                        onStatusChange(.pending)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward").font(.caption2)
                            Text("Undo submitted").font(.caption2)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.orange.opacity(0.1), in: Capsule())
                        .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                } else {
                    ForEach([SubmissionStatus.submitted, .late], id: \.self) { s in
                        Button {
                            onStatusChange(s)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: s.icon).font(.caption2)
                                Text(s == .submitted ? "Mark submitted" : "Mark late")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(s.color.opacity(0.1), in: Capsule())
                            .foregroundStyle(s.color)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

// MARK: - Add Submission Sheet

struct AddSubmissionSheet: View {
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var className = ""
    @State private var type: SubmissionType = .assignment
    @State private var dueDate = Date()
    @State private var notes = ""
    @FocusState private var focused: Bool
    let onAdd: (String, String, SubmissionType, Date, String) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("New Submission / Event").font(.title2.bold()).padding(.top, 8)

                    // Type picker
                    Text("TYPE").font(.caption).foregroundStyle(.secondary).tracking(1)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SubmissionType.allCases, id: \.self) { t in
                                Button { type = t } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: t.icon).font(.caption)
                                        Text(t.rawValue).font(.subheadline)
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(type == t ? Color.pink.opacity(0.15) : Color.gray.opacity(0.1),
                                                in: Capsule())
                                    .foregroundStyle(type == t ? .pink : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 1)
                    }

                    // Title
                    Text("TITLE").font(.caption).foregroundStyle(.secondary).tracking(1)
                    TextField("e.g. Essay on WWII, Chemistry Exam...", text: $title)
                        .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .focused($focused)

                    // Class
                    Text("CLASS (optional)").font(.caption).foregroundStyle(.secondary).tracking(1)
                    TextField("e.g. History 101", text: $className)
                        .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                    // Due date
                    Text("DUE DATE").font(.caption).foregroundStyle(.secondary).tracking(1)
                    DatePicker("Due date", selection: $dueDate, displayedComponents: [.date])
                        .datePickerStyle(.compact).tint(.pink)
                        .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .labelsHidden()

                    // Notes
                    Text("NOTES (optional)").font(.caption).foregroundStyle(.secondary).tracking(1)
                    TextField("Any extra info...", text: $notes, axis: .vertical)
                        .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .lineLimit(2...4)

                    Button {
                        onAdd(title, className, type, dueDate, notes)
                        isPresented = false
                    } label: {
                        Text("Add").font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(title.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .pink,
                                        in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 24).padding(.bottom, 40)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } } }
        }
        .presentationDetents([.large]).onAppear { focused = true }
    }
}
// MARK: - SCREEN 7: Projects ─────────────────────────────────────────

struct ProjectTask: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isDone: Bool = false
    var notes: String = ""
}

struct Project: Identifiable, Codable {
    var id = UUID()
    var name: String
    var emoji: String
    var description: String = ""
    var tasks: [ProjectTask] = []

    var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(tasks.filter { $0.isDone }.count) / Double(tasks.count)
    }
    var completedCount: Int { tasks.filter { $0.isDone }.count }
    var nextStep: ProjectTask? { tasks.first { !$0.isDone } }
}

@Observable
class ProjectStore {
    var projects: [Project] = []
    private let key = "myplanner_projects"

    init() { load() }

    func addProject(name: String, emoji: String, description: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        projects.append(Project(name: name, emoji: emoji, description: description))
        save()
    }

    func deleteProject(at offsets: IndexSet) { projects.remove(atOffsets: offsets); save() }

    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        save()
    }

    func updateProject(_ project: Project, name: String, emoji: String, description: String) {
        guard let i = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[i].name = name
        projects[i].emoji = emoji
        projects[i].description = description
        save()
    }

    func updateTask(project: Project, task: ProjectTask, title: String, notes: String) {
        guard let pi = projects.firstIndex(where: { $0.id == project.id }),
              let ti = projects[pi].tasks.firstIndex(where: { $0.id == task.id })
        else { return }
        projects[pi].tasks[ti].title = title
        projects[pi].tasks[ti].notes = notes
        save()
    }

    func deleteTask(project: Project, task: ProjectTask) {
        guard let i = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[i].tasks.removeAll { $0.id == task.id }
        save()
    }

    func addTask(to project: Project, title: String, notes: String) {
        guard let i = projects.firstIndex(where: { $0.id == project.id }) else { return }
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        projects[i].tasks.append(ProjectTask(title: title, notes: notes))
        save()
    }

    func toggleTask(project: Project, task: ProjectTask) {
        guard let pi = projects.firstIndex(where: { $0.id == project.id }),
              let ti = projects[pi].tasks.firstIndex(where: { $0.id == task.id })
        else { return }
        projects[pi].tasks[ti].isDone.toggle()
        save()
    }

    func deleteTask(project: Project, at offsets: IndexSet) {
        guard let i = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[i].tasks.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        if let e = try? JSONEncoder().encode(projects) { UserDefaults.standard.set(e, forKey: key) }
    }
    private func load() {
        if let d = UserDefaults.standard.data(forKey: key),
           let v = try? JSONDecoder().decode([Project].self, from: d) { projects = v }
    }
}

struct ProjectsView: View {
    @State private var store = ProjectStore()
    @State private var showAddProject = false
    @State private var editingProject: Project? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if store.projects.isEmpty {
                        VStack(spacing: 16) {
                            Text("🚀").font(.system(size: 50))
                            Text("No projects yet").font(.title3.bold())
                            Text("Plan your business, side project, or any big goal step by step.")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center).padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 60)
                    } else {
                        ForEach(store.projects) { project in
                            NavigationLink(destination: ProjectDetailView(project: project, store: store)) {
                                ProjectCardView(project: project)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button { editingProject = project } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) { store.deleteProject(project) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 40)
            }
            .background(Color.gray.opacity(0.07))
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddProject = true } label: {
                        Image(systemName: "plus").foregroundStyle(.pink)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddProject) {
            AddProjectSheet(isPresented: $showAddProject) { name, emoji, desc in
                store.addProject(name: name, emoji: emoji, description: desc)
            }
        }
        .sheet(item: $editingProject) { project in
            EditProjectSheet(project: project) { name, emoji, desc in
                store.updateProject(project, name: name, emoji: emoji, description: desc)
                editingProject = nil
            }
        }
    }
}

struct ProjectCardView: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(project.emoji).font(.title)
                    .frame(width: 48, height: 48)
                    .background(Color.pink.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name).font(.headline)
                    if !project.description.isEmpty {
                        Text(project.description).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                Text("\(Int(project.progress * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(project.progress >= 1.0 ? .green : .pink)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.15)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(project.progress >= 1.0 ? Color.green : Color.pink)
                        .frame(width: geo.size.width * project.progress, height: 6)
                        .animation(.spring(duration: 0.3), value: project.progress)
                }
            }
            .frame(height: 6)

            if let next = project.nextStep {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle").font(.caption2).foregroundStyle(.pink)
                    Text("Next: \(next.title)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            } else if !project.tasks.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").font(.caption2).foregroundStyle(.green)
                    Text("All steps complete!").font(.caption).foregroundStyle(.green)
                }
            }

            Text("\(project.completedCount)/\(project.tasks.count) steps done")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

struct ProjectDetailView: View {
    let project: Project
    let store: ProjectStore
    @State private var showAddTask = false
    @State private var showEditProject = false
    @State private var editingTask: ProjectTask? = nil

    var live: Project { store.projects.first(where: { $0.id == project.id }) ?? project }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Text(live.emoji).font(.system(size: 48))
                    if !live.description.isEmpty {
                        Text(live.description).font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    VStack(spacing: 6) {
                        Text("\(Int(live.progress * 100))%")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(live.progress >= 1.0 ? .green : .pink)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.15)).frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(live.progress >= 1.0 ? Color.green : Color.pink)
                                    .frame(width: geo.size.width * live.progress, height: 8)
                                    .animation(.spring(duration: 0.3), value: live.progress)
                            }
                        }
                        .frame(height: 8).padding(.horizontal, 40)
                        Text("\(live.completedCount)/\(live.tasks.count) steps complete")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity).padding(24)
                .background(.background, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("STEPS").font(.caption).foregroundStyle(.secondary).tracking(1)
                        Spacer()
                        Button { showAddTask = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Step")
                            }
                            .font(.caption).foregroundStyle(.pink)
                        }
                    }

                    if live.tasks.isEmpty {
                        Text("Break your project into steps to track progress.")
                            .font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(Array(live.tasks.enumerated()), id: \.element.id) { index, task in
                                ProjectTaskRow(task: task, index: index + 1) {
                                    store.toggleTask(project: live, task: task)
                                }
                                .contextMenu {
                                    Button { editingTask = task } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        store.deleteTask(project: live, task: task)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .background(.background, in: RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 40).padding(.top, 8)
        }
        .background(Color.gray.opacity(0.07))
        .navigationTitle(live.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEditProject = true } label: {
                    Image(systemName: "pencil").foregroundStyle(.pink)
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddProjectTaskSheet(isPresented: $showAddTask) { title, notes in
                store.addTask(to: live, title: title, notes: notes)
            }
        }
        .sheet(isPresented: $showEditProject) {
            EditProjectSheet(project: live) { name, emoji, desc in
                store.updateProject(live, name: name, emoji: emoji, description: desc)
                showEditProject = false
            }
        }
        .sheet(item: $editingTask) { task in
            EditTaskSheet(task: task) { title, notes in
                store.updateTask(project: live, task: task, title: title, notes: notes)
                editingTask = nil
            }
        }
    }
}

struct ProjectTaskRow: View {
    let task: ProjectTask
    let index: Int
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(task.isDone ? .green : .secondary)
                    .animation(.spring(duration: 0.2), value: task.isDone)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Step \(index)").font(.caption2).foregroundStyle(.secondary)
                Text(task.title)
                    .font(.subheadline.bold())
                    .strikethrough(task.isDone, color: .secondary)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                if !task.notes.isEmpty {
                    Text(task.notes).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct AddProjectSheet: View {
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var selectedEmoji = "🚀"
    @State private var description = ""
    @FocusState private var focused: Bool
    let onAdd: (String, String, String) -> Void

    let emojis = ["🚀","💼","🏪","🎯","💡","🛠️","📱","🎨","📈","🌟","🏗️","💰","🧪","🎬","✈️"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("New Project").font(.title2.bold()).padding(.top, 8)

                    Text("PICK AN EMOJI").font(.caption).foregroundStyle(.secondary).tracking(1)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                        ForEach(emojis, id: \.self) { emoji in
                            Button { selectedEmoji = emoji } label: {
                                Text(emoji).font(.title2).frame(width: 48, height: 48)
                                    .background(selectedEmoji == emoji ? Color.pink.opacity(0.2) : Color.gray.opacity(0.1),
                                                in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedEmoji == emoji ? Color.pink : Color.clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("PROJECT NAME").font(.caption).foregroundStyle(.secondary).tracking(1)
                    TextField("e.g. My Online Shop, YouTube Channel...", text: $name)
                        .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .focused($focused)

                    Text("DESCRIPTION (optional)").font(.caption).foregroundStyle(.secondary).tracking(1)
                    TextField("What's this project about?", text: $description, axis: .vertical)
                        .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .lineLimit(2...4)

                    Button { onAdd(name, selectedEmoji, description); isPresented = false } label: {
                        Text("Create Project").font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(name.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .pink,
                                        in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 24).padding(.bottom, 40)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } } }
        }
        .presentationDetents([.large]).onAppear { focused = true }
    }
}

struct AddProjectTaskSheet: View {
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var notes = ""
    @FocusState private var focused: Bool
    let onAdd: (String, String) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Add a Step").font(.title2.bold()).padding(.top, 8)

                Text("WHAT NEEDS TO BE DONE?").font(.caption).foregroundStyle(.secondary).tracking(1)
                TextField("e.g. Set up website, Register business...", text: $title)
                    .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .focused($focused)

                Text("NOTES (optional)").font(.caption).foregroundStyle(.secondary).tracking(1)
                TextField("Any details or links...", text: $notes, axis: .vertical)
                    .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .lineLimit(2...4)

                Button { onAdd(title, notes); isPresented = false } label: {
                    Text("Add Step").font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(title.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .pink,
                                    in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }
            .padding(.horizontal, 24)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } } }
        }
        .presentationDetents([.medium]).onAppear { focused = true }
    }
}

struct EditProjectSheet: View {
    let project: Project
    let onSave: (String, String, String) -> Void
    @State private var name = ""
    @State private var selectedEmoji = ""
    @State private var description = ""
    @Environment(\.dismiss) var dismiss

    let emojis = ["🚀","💼","🏪","🎯","💡","🛠️","📱","🎨","📈","🌟","🏗️","💰","🧪","🎬","✈️"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Edit Project").font(.title2.bold()).padding(.top, 8)

                    Text("EMOJI").font(.caption).foregroundStyle(.secondary).tracking(1)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                        ForEach(emojis, id: \.self) { emoji in
                            Button { selectedEmoji = emoji } label: {
                                Text(emoji).font(.title2).frame(width: 48, height: 48)
                                    .background(selectedEmoji == emoji ? Color.pink.opacity(0.2) : Color.gray.opacity(0.1),
                                                in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedEmoji == emoji ? Color.pink : Color.clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("PROJECT NAME").font(.caption).foregroundStyle(.secondary).tracking(1)
                    TextField("Project name", text: $name)
                        .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                    Text("DESCRIPTION").font(.caption).foregroundStyle(.secondary).tracking(1)
                    TextField("Description", text: $description, axis: .vertical)
                        .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .lineLimit(2...4)

                    Button {
                        onSave(name, selectedEmoji, description)
                        dismiss()
                    } label: {
                        Text("Save").font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(name.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .pink,
                                        in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 24).padding(.bottom, 40)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.large])
        .onAppear {
            name = project.name
            selectedEmoji = project.emoji
            description = project.description
        }
    }
}

struct EditTaskSheet: View {
    let task: ProjectTask
    let onSave: (String, String) -> Void
    @State private var title = ""
    @State private var notes = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Edit Step").font(.title2.bold()).padding(.top, 8)

                Text("TITLE").font(.caption).foregroundStyle(.secondary).tracking(1)
                TextField("Step title", text: $title)
                    .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                Text("NOTES").font(.caption).foregroundStyle(.secondary).tracking(1)
                TextField("Notes", text: $notes, axis: .vertical)
                    .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .lineLimit(2...4)

                Button {
                    onSave(title, notes)
                    dismiss()
                } label: {
                    Text("Save").font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(title.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .pink,
                                    in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }
            .padding(.horizontal, 24)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium])
        .onAppear {
            title = task.title
            notes = task.notes
        }
    }
}

// MARK: - SCREEN 8: Calendar ─────────────────────────────────────────

enum EventColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, pink

    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        }
    }
}

struct CalendarEvent: Identifiable, Codable {
    var id = UUID()
    var title: String
    var startTime: Date
    var endTime: Date
    var eventColor: EventColor = .blue
}

@Observable
class CalendarStore {
    var events: [CalendarEvent] = []
    private let key = "myplanner_calendar_events"

    init() { load() }

    func add(title: String, startTime: Date, endTime: Date, color: EventColor) {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        events.append(CalendarEvent(title: title, startTime: startTime, endTime: endTime, eventColor: color))
        save()
    }

    func delete(_ event: CalendarEvent) {
        events.removeAll { $0.id == event.id }
        save()
    }

    func events(for date: Date) -> [CalendarEvent] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        return events.filter { $0.startTime >= start && $0.startTime < end }
            .sorted { $0.startTime < $1.startTime }
    }

    private func save() {
        if let e = try? JSONEncoder().encode(events) { UserDefaults.standard.set(e, forKey: key) }
    }
    private func load() {
        if let d = UserDefaults.standard.data(forKey: key),
           let v = try? JSONDecoder().decode([CalendarEvent].self, from: d) { events = v }
    }
}

struct CalendarView: View {
    let calendarStore: CalendarStore
    @State private var selectedDate = Date()
    @State private var showAddEvent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(.pink)
                        .padding(.horizontal, 8)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                                .font(.caption).foregroundStyle(.secondary).textCase(.uppercase).tracking(1)
                            Text(selectedDate.formatted(.dateTime.month(.wide).day()))
                                .font(.title3.bold())
                        }
                        Spacer()
                        Button { showAddEvent = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Event")
                            }
                            .font(.subheadline).foregroundStyle(.pink)
                        }
                    }
                    .padding(.horizontal, 20)

                    let dayEvents = calendarStore.events(for: selectedDate)
                    if dayEvents.isEmpty {
                        VStack(spacing: 12) {
                            Text("No events").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 30)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(dayEvents) { event in
                                EventBlockView(event: event) {
                                    calendarStore.delete(event)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color.gray.opacity(0.07))
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showAddEvent) {
            AddEventSheet(isPresented: $showAddEvent, selectedDate: selectedDate) { title, start, end, color in
                calendarStore.add(title: title, startTime: start, endTime: end, color: color)
            }
        }
    }
}

struct EventBlockView: View {
    let event: CalendarEvent
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.eventColor.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title).font(.subheadline.bold())
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.caption2)
                    Text("\(event.startTime.formatted(date: .omitted, time: .shortened)) – \(event.endTime.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)

            Spacer()
        }
        .background(event.eventColor.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .contextMenu {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct AddEventSheet: View {
    @Binding var isPresented: Bool
    let selectedDate: Date
    @State private var title = ""
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var eventColor: EventColor = .blue
    @FocusState private var focused: Bool
    let onAdd: (String, Date, Date, EventColor) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("New Event").font(.title2.bold()).padding(.top, 8)

                    Text("TITLE").font(.caption).foregroundStyle(.secondary).tracking(1)
                    TextField("e.g. Doctor appointment", text: $title)
                        .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .focused($focused)

                    Text("START").font(.caption).foregroundStyle(.secondary).tracking(1)
                    DatePicker("Start", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                        .tint(.pink).labelsHidden()
                        .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                    Text("END").font(.caption).foregroundStyle(.secondary).tracking(1)
                    DatePicker("End", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                        .tint(.pink).labelsHidden()
                        .padding().background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                    Text("COLOR").font(.caption).foregroundStyle(.secondary).tracking(1)
                    HStack(spacing: 12) {
                        ForEach(EventColor.allCases, id: \.self) { c in
                            Button { eventColor = c } label: {
                                Circle().fill(c.color).frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold()).foregroundStyle(.white)
                                            .opacity(eventColor == c ? 1 : 0)
                                    )
                                    .overlay(Circle().stroke(Color.primary.opacity(eventColor == c ? 0.3 : 0), lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        onAdd(title, startTime, endTime, eventColor)
                        isPresented = false
                    } label: {
                        Text("Add Event").font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(title.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .pink,
                                        in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 24).padding(.bottom, 40)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } } }
        }
        .presentationDetents([.large])
        .onAppear {
            let cal = Calendar.current
            var components = cal.dateComponents([.year, .month, .day], from: selectedDate)
            let hour = max(8, min(20, cal.component(.hour, from: Date()) + 1))
            components.hour = hour
            components.minute = 0
            startTime = cal.date(from: components) ?? selectedDate
            components.hour = hour + 1
            endTime = cal.date(from: components) ?? selectedDate
            focused = true
        }
    }
}

// MARK: - Tab View ────────────────────────────────────────────────────

struct MainTabView: View {
    @State private var calendarStore = CalendarStore()
    @State private var submissionsStore = SubmissionsStore()
    @State private var habitStore = HabitStore()

    var body: some View {
        TabView {
            ContentView()
                .tabItem { Label("Goals", systemImage: "star.fill") }
            TodayView(calendarStore: calendarStore, submissionsStore: submissionsStore, habitStore: habitStore)
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            CalendarView(calendarStore: calendarStore)
                .tabItem { Label("Calendar", systemImage: "calendar") }
            ProjectsView()
                .tabItem { Label("Projects", systemImage: "briefcase.fill") }
            HabitView(store: habitStore)
                .tabItem { Label("Habits", systemImage: "checkmark.seal.fill") }
            ClassesView()
                .tabItem { Label("Classes", systemImage: "book.fill") }
            NotesView()
                .tabItem { Label("Notes", systemImage: "note.text") }
            SubmissionsView(store: submissionsStore)
                .tabItem { Label("Submit", systemImage: "tray.fill") }
        }
        .tint(.pink)
    }
}

#Preview {
    MainTabView()
}

