import SwiftUI

/// Floating timeline scrubber for the world map. Uses iOS 26's native
/// `Slider` (which inherits Liquid Glass styling automatically when its
/// parent applies `.glassEffect()`) instead of a hand-rolled track + thumb.
///
/// Layout (top → bottom):
///   1. Spike markers — one bar per day with events, height = volume
///   2. Native `Slider` — Liquid Glass thumb, terracotta tint past / amber tint future
///   3. Meta row — date label · Now button · × close
///
/// Hosted by `WorldMapView` inside a `GlassEffectContainer`. Morphs between
/// a small circular button (collapsed state) and this strip (expanded state)
/// via `glassEffectID("timeline-hub")`.
struct TimelineScrubber: View {
    @Binding var date: Date
    let rangeStart: Date
    let rangeEnd: Date
    let now: Date
    var dailyEventCounts: [Date: Int] = [:]
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var calendar: Calendar {
        Calendar.current
    }

    private var selectedDay: Date {
        calendar.startOfDay(for: date)
    }

    private var today: Date {
        calendar.startOfDay(for: now)
    }

    private var progress: Double {
        let total = rangeEnd.timeIntervalSince(rangeStart)
        guard total > 0 else { return 1 }
        let current = selectedDay.timeIntervalSince(rangeStart)
        return min(1, max(0, current / total))
    }

    private var nowProgress: Double {
        let total = rangeEnd.timeIntervalSince(rangeStart)
        guard total > 0 else { return 1 }
        let current = today.timeIntervalSince(rangeStart)
        return min(1, max(0, current / total))
    }

    private var isToday: Bool { selectedDay == today }

    /// Throttle the slider's setter to a single update per day-bucket. The
    /// dot-filter granularity is "signals on or before this date" — sub-day
    /// precision changes nothing on screen, so we ignore writes that don't
    /// move the day boundary. This drops the per-frame state-change rate
    /// from ~60Hz (raw slider) to ~once-per-pixel-of-drag, which is what
    /// killed the FPS before.
    private var sliderBinding: Binding<Double> {
        Binding(
            get: { progress },
            set: { newProgress in
                let clamped = min(1.0, max(0.0, newProgress))
                let total = rangeEnd.timeIntervalSince(rangeStart)
                guard total > 0 else { return }
                let candidate = rangeStart.addingTimeInterval(total * clamped)
                let candidateDay = calendar.startOfDay(for: candidate)
                let clampedToToday = min(candidateDay, today)
                if clampedToToday == selectedDay {
                    return
                }
                // Use a transaction with disabled implicit animation so
                // SwiftUI doesn't queue a spring on every step. The map
                // annotations diff cheaply.
                var tx = Transaction()
                tx.disablesAnimations = true
                withTransaction(tx) {
                    date = clampedToToday
                }
            }
        )
    }

    var body: some View {
        // Leading inset clears the floating `leftHandle` ("signals" pill) that
        // sits in the bottom-left rail at the same vertical band as this strip.
        // Without it the pill visually overlapped the slider track and clipped
        // the "Today, MMM d" label (see commit 1).  The strip's glass still
        // extends edge-to-edge — only the *content* is shifted right, so the
        // pill reads as a leading element of the same component (which is what
        // the user asked for: "they should be in the same box").
        let pillInset: CGFloat = 64

        return VStack(spacing: 6) {
            spikeMarkers
                .frame(height: 16)
                .padding(.leading, pillInset)
                .padding(.trailing, 14)

            // Native Slider — gets Liquid Glass thumb on iOS 26 because its
            // parent applies `.glassEffect()`. Tint shifts to amber when the
            // thumb is in future-projection territory.
            Slider(value: sliderBinding, in: 0.0...1.0)
                .tint(Theme.terracotta)
                .padding(.leading, pillInset)
                .padding(.trailing, 14)

            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
                Text(dateLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Spacer()
                Button {
                    if reduceMotion {
                        date = today
                    } else {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                            date = today
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.caption2.weight(.bold))
                        Text("Now")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.white.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reset timeline to now")
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close timeline")
            }
            .padding(.leading, pillInset)
            .padding(.trailing, 14)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .environment(\.colorScheme, .dark)
    }

    /// Per-day event spikes drawn above the slider. Past spikes use terracotta;
    /// future spikes (predictions) use a softer amber. Heights are normalised
    /// to the busiest day in range.
    ///
    /// All math here is defensive: zero-sized layouts (which SwiftUI can hand
    /// us during the first reconciliation pass before GeometryReader settles),
    /// out-of-range dates, and empty event dictionaries must all degrade
    /// silently. Earlier versions of this view force-unwrapped values from
    /// `Calendar.dateComponents` and divided by `rangeDays` without checking
    /// for the rangeStart == rangeEnd case, which surfaced as user reports
    /// of the timeline crashing on first interaction. The guards below cover
    /// each of those paths.
    private var spikeMarkers: some View {
        GeometryReader { geo in
            let cal = Calendar.current
            let rangeDaysRaw = cal.dateComponents([.day], from: rangeStart, to: rangeEnd).day ?? 0
            let rangeDays = max(1, rangeDaysRaw)
            let maxCount = max(1, dailyEventCounts.values.max() ?? 1)
            let availableWidth = max(1, geo.size.width)

            ZStack(alignment: .bottomLeading) {
                ForEach(Array(dailyEventCounts.keys.sorted()), id: \.self) { day in
                    if let count = dailyEventCounts[day],
                       count > 0,
                       day <= now,
                       let rawOffset = cal.dateComponents([.day], from: rangeStart, to: day).day {
                        let dayOffset = min(rangeDays, max(0, rawOffset))
                        let normalisedCount = min(maxCount, max(1, count))
                        let h = max(2, CGFloat(normalisedCount) / CGFloat(maxCount) * 14)
                        let x = (CGFloat(dayOffset) / CGFloat(rangeDays)) * availableWidth
                        Rectangle()
                            .fill(Theme.terracotta.opacity(0.75))
                            .frame(width: 1.5, height: h)
                            .position(x: x, y: 16 - h / 2)
                    }
                }
                // Faint "now" tick under the spike row.
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 1, height: 8)
                    .position(x: availableWidth * nowProgress, y: 12)
            }
        }
    }

    private var dateLabel: String {
        let formatted = selectedDay.formatted(.dateTime.month(.abbreviated).day())
        if isToday { return "Today, \(formatted)" }
        let days = calendar.dateComponents([.day], from: today, to: selectedDay).day ?? 0
        let prefix = days < 0 ? "\(abs(days))d ago" : "now"
        return "\(prefix) · \(formatted)"
    }
}
