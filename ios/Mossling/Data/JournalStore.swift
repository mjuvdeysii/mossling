import SwiftUI
import Observation
import WidgetKit

/// The journal as the app sees it: the shared file, reloaded when the app comes back (a Live Activity or the widget may
/// have changed it), saved after every change, with the Live Activities and widgets kept in step.
@Observable
final class JournalStore {
    private(set) var logs: [LogEntry] = []
    private(set) var timers: [RunningTimer] = []
    private(set) var measures: [Measure] = []

    init(preview: JournalFile.Body? = nil) { apply(preview ?? JournalFile.read()) }

    func reload() { apply(JournalFile.read()) }
    private func apply(_ b: JournalFile.Body) {
        logs = b.logs.sorted { $0.start > $1.start }; timers = b.timers; measures = b.measures.sorted { $0.at < $1.at }
    }
    private func changed(_ b: JournalFile.Body) {
        apply(b)
        Task { await LiveTimers.sync() }
        WidgetCenter.shared.reloadAllTimelines()
    }
    private func edit(_ f: (inout JournalFile.Body) -> Void) { var b = JournalFile.read(); f(&b); JournalFile.write(b); changed(b) }

    func start(_ type: String, side: String? = nil, at: Date = Date()) { changed(JournalFile.start(type, side: side, at: at.timeIntervalSince1970 * 1000)) }
    func togglePause(_ type: String) { changed(JournalFile.togglePause(type)) }
    func switchSide(_ type: String) { changed(JournalFile.switchSide(type)) }
    func shift(_ type: String, to: Date) { changed(JournalFile.shift(type, to: to.timeIntervalSince1970 * 1000)) }
    func stop(_ type: String) { changed(JournalFile.stop(type)) }
    func discard(_ type: String) { changed(JournalFile.discard(type)) }

    func add(_ e: LogEntry) { edit { $0.logs.append(e) } }
    func update(_ e: LogEntry) { edit { b in if let i = b.logs.firstIndex(where: { $0.id == e.id }) { b.logs[i] = e } } }
    func delete(_ e: LogEntry) { edit { $0.logs.removeAll { $0.id == e.id } } }
    func saveMeasure(_ m: Measure) { edit { b in if let i = b.measures.firstIndex(where: { $0.id == m.id }) { b.measures[i] = m } else { b.measures.append(m) } } }
    func deleteMeasure(_ m: Measure) { edit { $0.measures.removeAll { $0.id == m.id } } }
    func replaceAll(_ body: JournalFile.Body) { JournalFile.write(body); changed(body) }

    func last(_ type: String) -> Date? { logs.first { $0.type == type }.map { $0.endDate ?? $0.startDate } }
    func logs(on day: Day) -> [LogEntry] {
        let a = day.date.timeIntervalSince1970 * 1000, b = day.plus(days: 1).date.timeIntervalSince1970 * 1000
        return logs.filter { $0.start >= a && $0.start < b }
    }
}
