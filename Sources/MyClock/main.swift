import AppKit
import Combine
import SwiftUI

private enum PomodoroMode: String {
    case work = "Work"
    case rest = "Rest"
}

private enum TimerPhase {
    case idle
    case running
    case paused
}

private struct CodexTaskStatus: Codable, Equatable {
    var status: String
    var task: String
    var updatedAt: String

    static let missing = CodexTaskStatus(
        status: "unknown",
        task: "No Codex status published",
        updatedAt: ""
    )
}

private final class ClockViewModel: ObservableObject {
    @Published var goal = ""
    @Published var mode: PomodoroMode = .work
    @Published var phase: TimerPhase = .idle
    @Published var remainingSeconds = 25 * 60
    @Published var validationMessage = ""
    @Published var alwaysOnTop = true
    @Published var codexStatus = CodexTaskStatus.missing

    private let workSeconds = 25 * 60
    private let restSeconds = 5 * 60
    private var tickCancellable: AnyCancellable?
    private var statusCancellable: AnyCancellable?

    private var statusURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex-clock", isDirectory: true)
            .appendingPathComponent("status.json")
    }

    init() {
        loadCodexStatus()
        statusCancellable = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.loadCodexStatus() }
    }

    var primaryActionTitle: String {
        switch phase {
        case .idle:
            return mode == .work ? "Start" : "Start break"
        case .running:
            return "Pause"
        case .paused:
            return "Resume"
        }
    }

    var primaryActionIcon: String {
        switch phase {
        case .idle, .paused:
            return "play.fill"
        case .running:
            return "pause.fill"
        }
    }

    var timeText: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var progress: Double {
        let total = mode == .work ? workSeconds : restSeconds
        guard total > 0 else { return 0 }
        return 1 - (Double(remainingSeconds) / Double(total))
    }

    var statusColor: Color {
        switch codexStatus.status.lowercased() {
        case "running":
            return .blue
        case "waiting", "waiting_for_user", "blocked":
            return .orange
        case "completed", "complete", "done":
            return .green
        default:
            return .secondary
        }
    }

    var normalizedStatusText: String {
        switch codexStatus.status.lowercased() {
        case "running":
            return "Running"
        case "waiting", "waiting_for_user":
            return "Waiting"
        case "blocked":
            return "Blocked"
        case "completed", "complete", "done":
            return "Completed"
        default:
            return "Unknown"
        }
    }

    var goals: [String] {
        goal
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var compactGoalText: String {
        guard let firstGoal = goals.first else { return "No goal" }
        if goals.count == 1 {
            return firstGoal
        }
        return "\(firstGoal)  +\(goals.count - 1)"
    }

    func performPrimaryAction() {
        switch phase {
        case .idle:
            start()
        case .running:
            pause()
        case .paused:
            resume()
        }
    }

    func reset() {
        stopTicker()
        mode = .work
        phase = .idle
        remainingSeconds = workSeconds
        validationMessage = ""
    }

    func skip() {
        stopTicker()
        if mode == .work {
            mode = .rest
            remainingSeconds = restSeconds
        } else {
            mode = .work
            remainingSeconds = workSeconds
            goal = ""
        }
        phase = .idle
        validationMessage = ""
    }

    private func start() {
        if mode == .work && goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationMessage = "Enter a work goal before starting."
            return
        }

        validationMessage = ""
        phase = .running
        startTicker()
    }

    private func pause() {
        phase = .paused
        stopTicker()
    }

    private func resume() {
        phase = .running
        startTicker()
    }

    private func startTicker() {
        stopTicker()
        tickCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func stopTicker() {
        tickCancellable?.cancel()
        tickCancellable = nil
    }

    private func tick() {
        guard phase == .running else { return }

        if remainingSeconds > 0 {
            remainingSeconds -= 1
            return
        }

        completeCurrentPeriod()
    }

    private func completeCurrentPeriod() {
        stopTicker()
        NSSound.beep()

        if mode == .work {
            mode = .rest
            remainingSeconds = restSeconds
            phase = .running
            startTicker()
        } else {
            mode = .work
            remainingSeconds = workSeconds
            phase = .idle
            goal = ""
        }
    }

    private func loadCodexStatus() {
        do {
            let data = try Data(contentsOf: statusURL)
            codexStatus = try JSONDecoder().decode(CodexTaskStatus.self, from: data)
        } catch {
            codexStatus = .missing
        }
    }
}

private struct ContentView: View {
    @StateObject private var model = ClockViewModel()
    @State private var isCompact = false

    var body: some View {
        Group {
            if isCompact {
                compactBody
            } else {
                expandedBody
            }
        }
        .background(.regularMaterial)
        .onAppear {
            AppDelegate.configureWindows(alwaysOnTop: model.alwaysOnTop, compact: isCompact)
        }
        .onChange(of: model.alwaysOnTop) { newValue in
            AppDelegate.configureWindows(alwaysOnTop: newValue, compact: isCompact)
        }
        .onChange(of: isCompact) { newValue in
            AppDelegate.configureWindows(alwaysOnTop: model.alwaysOnTop, compact: newValue)
        }
        .onChange(of: model.phase) { newValue in
            if newValue == .running {
                isCompact = true
            } else if newValue == .idle {
                isCompact = false
            }
        }
    }

    private var expandedBody: some View {
        VStack(spacing: 18) {
            header
            timerFace
            goalEditor
            controls
            codexPanel
        }
        .padding(22)
        .frame(width: 390)
    }

    private var compactBody: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.timeText)
                    .font(.system(size: 30, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .lineLimit(1)
                Text(model.compactGoalText)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Circle()
                        .fill(model.statusColor)
                        .frame(width: 7, height: 7)
                    Text(model.mode.rawValue)
                        .font(.caption)
                    Text(model.normalizedStatusText)
                        .font(.caption)
                        .foregroundStyle(model.statusColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Button {
                model.performPrimaryAction()
            } label: {
                Image(systemName: model.primaryActionIcon)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help(model.primaryActionTitle)

            Button {
                isCompact = false
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Expand")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 300)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MyClock")
                    .font(.system(size: 18, weight: .semibold))
                Text(model.mode == .work ? "25 min focus" : "5 min break")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle(isOn: $model.alwaysOnTop) {
                Image(systemName: model.alwaysOnTop ? "pin.fill" : "pin")
            }
            .toggleStyle(.button)
            .help("Keep window above other apps")

            Button {
                isCompact = true
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
            }
            .help("Compact mode")
        }
    }

    private var timerFace: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 12)
            Circle()
                .trim(from: 0, to: model.progress)
                .stroke(model.mode == .work ? Color.accentColor : Color.green, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.2), value: model.progress)

            VStack(spacing: 4) {
                Text(model.timeText)
                    .font(.system(size: 54, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                Text(model.mode.rawValue)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 220, height: 220)
    }

    private var goalEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.goal)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.secondary.opacity(0.24), lineWidth: 1)
                    )
                    .disabled(model.mode == .work && model.phase == .running)

                if model.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Work goals, one per line")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 86)

            Text("One line per goal.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if !model.validationMessage.isEmpty {
                Text(model.validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                model.performPrimaryAction()
            } label: {
                Label(model.primaryActionTitle, systemImage: model.primaryActionIcon)
                    .frame(maxWidth: .infinity)
            }
            .keyboardShortcut(.return, modifiers: [])
            .controlSize(.large)

            Button {
                model.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 34)
            }
            .controlSize(.large)
            .help("Reset")

            Button {
                model.skip()
            } label: {
                Image(systemName: "forward.end.fill")
                    .frame(width: 34)
            }
            .controlSize(.large)
            .help("Skip")
        }
    }

    private var codexPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(model.statusColor)
                    .frame(width: 9, height: 9)
                Text("Codex")
                    .font(.headline)
                Spacer()
                Text(model.normalizedStatusText)
                    .font(.caption)
                    .foregroundStyle(model.statusColor)
            }

            Text(model.codexStatus.task)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !model.codexStatus.updatedAt.isEmpty {
                Text(model.codexStatus.updatedAt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            Self.configureWindows(alwaysOnTop: true, compact: false)
        }
    }

    static func configureWindows(alwaysOnTop: Bool, compact: Bool) {
        for window in NSApplication.shared.windows {
            let size = compact ? NSSize(width: 300, height: 92) : NSSize(width: 390, height: 620)
            window.level = alwaysOnTop ? .floating : .normal
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.isMovableByWindowBackground = true
            window.title = "MyClock"
            window.minSize = size
            window.setContentSize(size)
        }
    }
}

@main
private struct MyClockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
