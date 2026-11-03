import AppKit
import SwiftUI

struct TaskView: View {
    @Environment(Store.self) private var store
    @State var task: ClaudeTask
    let onBack: () -> Void
    @State private var pendingSave: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button(action: back) {
                    Image(systemName: "chevron.left").frame(width: 16, height: 16).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                TextField("Name", text: $task.name).textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            Separator()
            SchedulePicker(task: $task)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            Separator()
            InstructionsEditor(text: $task.instructions)
            Separator()
            Row(icon: "folder", action: chooseFolder) { _ in
                Text((task.folder as NSString).abbreviatingWithTildeInPath).lineLimit(1).truncationMode(.middle)
                Spacer()
            }
            ToolsRow(folder: task.folder)
            Row(icon: "play", action: { store.runNow(task) }) { _ in
                Text("Run now")
                Spacer()
                if store.running.contains(task.id) { Hint(text: "Running") }
            }
            .disabled(task.isEmpty || store.paused || store.running.contains(task.id))
            if let run = store.runs[task.id], !store.running.contains(task.id) {
                Row(icon: "clock.arrow.circlepath", action: { store.openRun(task) }) { _ in
                    Text(run.succeeded ? "Last run" : "Last run didn't finish").lineLimit(1)
                    Spacer()
                    Hint(text: run.started.formatted(.relative(presentation: .named)))
                }
            }
            Separator()
            Row(icon: "trash", action: moveToBin) { _ in
                Text("Move to Bin")
                Spacer()
            }
            .disabled(!store.tasks.contains { $0.id == task.id })
        }
        .onChange(of: task) {
            pendingSave?.cancel()
            pendingSave = Task {
                try? await Task.sleep(for: .milliseconds(600))
                if !Task.isCancelled { save() }
            }
        }
        .onDisappear(perform: save)
    }

    private func back() {
        save()
        onBack()
    }

    private func moveToBin() {
        pendingSave?.cancel()
        store.delete(task)
        onBack()
    }

    private func save() {
        pendingSave?.cancel()
        let saved = store.tasks.first { $0.id == task.id }
        guard saved != task, saved != nil || !task.isEmpty else { return }
        store.save(task)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.directoryURL = URL(filePath: task.folder)
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        task.folder = url.path
    }
}

struct InstructionsEditor: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 15))
            .scrollContentBackground(.hidden)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Instructions")
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 6)
    }
}

struct ToolsRow: View {
    @Environment(Store.self) private var store
    let folder: String

    var body: some View {
        let health = store.health[folder]
        let busy = store.checking.contains(folder)
        let issue = health.map { !$0.signedIn || !$0.needsSignIn.isEmpty || !$0.failing.isEmpty } ?? false
        Row(icon: health == nil ? "arrow.triangle.2.circlepath" : issue ? "exclamationmark.circle" : "checkmark.circle", action: { act(health) }) { _ in
            Text(busy ? "Checking tools…" : title(health)).lineLimit(1)
            Spacer()
            if let health, !busy { Hint(text: !health.signedIn || !health.needsSignIn.isEmpty ? "Sign in" : "Check again") }
        }
        .disabled(busy)
    }

    private func title(_ health: Health?) -> String {
        guard let health else { return "Check tools" }
        if !health.signedIn { return "Signed out of Claude" }
        if !health.needsSignIn.isEmpty { return "\(health.needsSignIn.joined(separator: ", ")) needs sign-in" }
        if !health.failing.isEmpty { return "\(health.failing.joined(separator: ", ")) isn't connecting" }
        return "Tools connected"
    }

    private func act(_ health: Health?) {
        guard let health else { return store.check(folder, force: true) }
        if !health.signedIn { return Shell.openTerminal(Claude.login, in: folder) }
        if !health.needsSignIn.isEmpty { return Shell.openTerminal(Claude.mcp, in: folder) }
        store.check(folder, force: true)
    }
}

struct SchedulePicker: View {
    @Binding var task: ClaudeTask

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 2) {
                ForEach(Repeat.allCases, id: \.self) { option in
                    Chip(title: option.label, on: task.repeats == option) {
                        task.repeats = option
                        if option == .weekly, task.weekdays.isEmpty { task.weekdays = [1, 2, 3, 4, 5] }
                    }
                }
                Spacer()
                if task.repeats == .monthly {
                    Picker("Day", selection: $task.day) {
                        ForEach(1...28, id: \.self) { Text(ordinal($0)).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .controlSize(.small)
                }
            }
            if task.repeats == .weekly {
                HStack(spacing: 4) {
                    ForEach(ClaudeTask.weekdayOrder, id: \.self) { day in
                        DayToggle(letter: Calendar.current.veryShortWeekdaySymbols[day], on: task.weekdays.contains(day)) {
                            if task.weekdays.contains(day) { task.weekdays.removeAll { $0 == day } } else { task.weekdays.append(day) }
                        }
                    }
                }
            }
            if task.repeats != .off {
                HStack(spacing: 12) {
                    Slider(value: minute, in: 0...1425).controlSize(.small)
                    Text(task.time).monospacedDigit().foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
                }
            }
        }
    }

    private var minute: Binding<Double> {
        Binding(
            get: { Double(task.minute) },
            set: { task.minute = min(1425, max(0, Int(($0 / 15).rounded()) * 15)) }
        )
    }
}
