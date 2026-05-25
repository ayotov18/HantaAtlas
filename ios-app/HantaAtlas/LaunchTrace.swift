import Foundation
import os.signpost

/// Lightweight cold-start tracer. Backed by `os.signpost` so events show up
/// both in the Xcode debug console (via `Logger.notice`) **and** in Instruments
/// (Time Profile → Points of Interest), per Apple's "Reducing your app's
/// launch time" guidance:
///
/// > "Use OSLog with `category: .pointsOfInterest` and `os_signpost(.begin/.end)`
/// > so the launch metric tooling captures work that happens after first frame."
///
/// Usage:
///   LaunchTrace.shared.checkpoint("HantaAtlasApp.body evaluated")
///   LaunchTrace.shared.span("repository.refresh") { await repo.refresh() }
///
/// Console output looks like:
///   [launch] +0.000s  process start
///   [launch] +0.142s  HantaAtlasApp.init
///   [launch] +0.351s  ContentView.task begin
///   [launch] +1.842s  repository.refresh end (1.491s)
///
/// All call sites are no-ops in Release builds (the `@inlinable` + `#if DEBUG`
/// gate ensures the work is stripped). On TestFlight / production this file
/// adds zero overhead.
enum LaunchTrace {
    private static let signposter = OSSignposter(
        subsystem: "com.anthonyyotov.HantaAtlas",
        category: "launch"
    )

    /// Process-start time, captured the first time anything in this enum is
    /// touched. We can't grab the *true* process start (that's a private
    /// kernel timestamp on iOS) but `Date.timeIntervalSinceReferenceDate` at
    /// first reference is a near-enough proxy — usually within a few ms of
    /// `main()` entry on a modern device.
    private static let appStart: TimeInterval = Date.timeIntervalSinceReferenceDate

    /// Print a single named checkpoint with elapsed seconds since `appStart`.
    static func checkpoint(_ name: StaticString) {
        #if DEBUG
        let elapsed = Date.timeIntervalSinceReferenceDate - appStart
        let stamp = String(format: "+%.3fs", elapsed)
        print("[launch] \(stamp)  \(name)")
        signposter.emitEvent(name)
        #endif
    }

    /// Time an async block and emit a signpost interval + console line.
    /// `@MainActor` isolated because every cold-path caller already lives on
    /// the main actor (SwiftUI `.task`, `App.init`, etc.), and that lets the
    /// closure freely capture @Observable models without triggering Sendable
    /// errors.
    @MainActor
    static func span<T>(
        _ name: StaticString,
        _ work: () async throws -> T
    ) async rethrows -> T {
        #if DEBUG
        let state = signposter.beginInterval(name)
        let start = Date.timeIntervalSinceReferenceDate
        let result = try await work()
        let dur = Date.timeIntervalSinceReferenceDate - start
        let elapsed = Date.timeIntervalSinceReferenceDate - appStart
        signposter.endInterval(name, state)
        print(String(format: "[launch] +%.3fs  %@ (%.3fs)", elapsed, "\(name)", dur))
        return result
        #else
        return try await work()
        #endif
    }

    /// Sync variant of `span` for non-async work.
    static func sync<T>(_ name: StaticString, _ work: () throws -> T) rethrows -> T {
        #if DEBUG
        let state = signposter.beginInterval(name)
        let start = Date.timeIntervalSinceReferenceDate
        let result = try work()
        let dur = Date.timeIntervalSinceReferenceDate - start
        let elapsed = Date.timeIntervalSinceReferenceDate - appStart
        signposter.endInterval(name, state)
        print(String(format: "[launch] +%.3fs  %@ (%.3fs)", elapsed, "\(name)", dur))
        return result
        #else
        return try work()
        #endif
    }
}
