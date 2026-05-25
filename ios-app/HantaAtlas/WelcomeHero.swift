import SwiftUI
import CoreLocation

/// Editorial welcome-screen hero. Replaces the rainbow-gradient SF Symbol +
/// random particle field with something that means something specific to
/// HantaAtlas: a stylised world-map outline (drawn from the same GeoJSON the
/// real map view uses) with real-data pulse rings at hantavirus-endemic
/// country centroids.
///
/// Why this looks hand-crafted:
///  - Uses actual geographic data — every line is a real country boundary
///  - Pulses originate at real endemic locations (AR/US/KR/FI/BR), not random
///  - Single-colour stroke on paper = editorial cartography, not stock vector
///  - Asymmetric, scientifically-sourced layout — no AI symmetry tells
///
/// **Perf note (cold-start fix).** The previous implementation drew the entire
/// 177-country outline inside the same `TimelineView`+`Canvas` that animates
/// the pulses, which re-projected and re-stroked ~530 k path points per second
/// on a screen the user only sees once. Apple's `Canvas` documentation does
/// not promise any static-content cache, so we now split the layers:
///
///  - `WorldOutlineShape` is a `Shape` whose `path(in:)` is invoked when SwiftUI
///    rebuilds the view (i.e. once on appear, again when `WorldGeometry.shared`
///    finishes parsing). Core Animation rasterises that path once.
///  - The animated `Canvas` only draws the 5 pulse rings, which is the work
///    that actually has to happen at 30 fps.
///  - The `TimelineView` is paused on disappear so we don't burn frames behind
///    the next screen during the welcome→content transition.
struct WelcomeHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Live reference forces the view to re-evaluate (and `WorldOutlineShape`
    /// to re-compute its path) when the GeoJSON parse completes off-main.
    @State private var geometry = WorldGeometry.shared

    /// Controls whether the pulse `TimelineView` ticks. Flipped via
    /// `onAppear`/`onDisappear` so we don't redraw behind ContentView.
    @State private var isVisible: Bool = false

    /// Real hantavirus-endemic locations whose centroids drive the pulses.
    /// Source: WHO Disease Outbreak News + CDC Sin Nombre / Andean / Seoul
    /// virus distribution maps.
    private let pulseSites: [PulseSite] = [
        PulseSite(name: "AR", lat: -38.4, lon:  -63.6, phase: 0.00),
        PulseSite(name: "US", lat:  39.5, lon:  -98.5, phase: 0.18),
        PulseSite(name: "KR", lat:  35.9, lon:  127.8, phase: 0.42),
        PulseSite(name: "FI", lat:  64.5, lon:   26.0, phase: 0.65),
        PulseSite(name: "BR", lat: -10.0, lon:  -52.0, phase: 0.83)
    ]

    /// Shared bounds — outline + pulses must use the same projection so the
    /// dots land on land.
    private static let mapBounds = MapBounds(latRange: -60...80, lonRange: -180...180)

    var body: some View {
        VStack(spacing: 14) {
            heroLayer
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("HantaAtlas")
                    .font(Theme.Fonts.heroWordmark)
                    .tracking(-0.8)
                    .foregroundStyle(Theme.graphite)
                Text("Where, when, and by whom.")
                    .font(.system(size: 13, weight: .semibold).smallCaps())
                    .tracking(2.5)
                    .foregroundStyle(Theme.graphiteSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("HantaAtlas. Where, when, and by whom.")
        }
    }

    // MARK: - Layered hero

    private var heroLayer: some View {
        ZStack {
            // Static layer — world-map outline rasterised once by Core Animation.
            WorldOutlineShape(rings: geometry.rings, bounds: Self.mapBounds)
                .stroke(
                    Theme.terracotta.opacity(0.55),
                    style: StrokeStyle(lineWidth: 0.9, lineCap: .round, lineJoin: .round)
                )

            // Animated layer — pulses only. TimelineView paused when invisible
            // and when Reduce Motion is on (per Apple HIG).
            TimelineView(.animation(
                minimumInterval: 1/30,
                paused: reduceMotion || !isVisible
            )) { context in
                Canvas { ctx, size in
                    let now = context.date.timeIntervalSinceReferenceDate
                    let cycle: Double = 2.6
                    for site in pulseSites {
                        let p = projectedPoint(
                            lat: site.lat,
                            lon: site.lon,
                            in: size,
                            bounds: Self.mapBounds
                        )
                        let progress: Double = {
                            if reduceMotion { return 0.0 }
                            let raw = (now / cycle + site.phase).truncatingRemainder(dividingBy: 1.0)
                            return raw < 0 ? raw + 1 : raw
                        }()
                        drawPulse(ctx: ctx, at: p, progress: progress)
                    }
                }
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }

    // MARK: - Pulse drawing

    private func drawPulse(ctx: GraphicsContext, at point: CGPoint, progress: Double) {
        let dotRadius: CGFloat = 3.5
        ctx.fill(
            Path(ellipseIn: CGRect(
                x: point.x - dotRadius, y: point.y - dotRadius,
                width: dotRadius * 2, height: dotRadius * 2
            )),
            with: .color(Theme.terracotta)
        )
        let minR: CGFloat = 4
        let maxR: CGFloat = 28
        let radius = minR + CGFloat(progress) * (maxR - minR)
        let alpha = max(0, 0.65 - 0.65 * progress)
        let rect = CGRect(
            x: point.x - radius, y: point.y - radius,
            width: radius * 2, height: radius * 2
        )
        ctx.stroke(
            Path(ellipseIn: rect),
            with: .color(Theme.terracotta.opacity(alpha)),
            lineWidth: 1.5
        )
    }

    // MARK: - Projection (shared with the shape)

    fileprivate struct MapBounds: Equatable {
        let latRange: ClosedRange<Double>
        let lonRange: ClosedRange<Double>
    }

    private struct PulseSite {
        let name: String
        let lat: Double
        let lon: Double
        let phase: Double
    }

    /// Pure math — explicitly nonisolated so `Shape.path(in:)` (which runs in
    /// a Sendable / nonisolated context) can call it without crossing actor
    /// boundaries. Swift 6 surfaces a warning otherwise.
    fileprivate nonisolated static func projectedPoint(
        lat: Double, lon: Double, in size: CGSize, bounds: MapBounds
    ) -> CGPoint {
        let lonSpan = bounds.lonRange.upperBound - bounds.lonRange.lowerBound
        let latSpan = bounds.latRange.upperBound - bounds.latRange.lowerBound
        let x = (lon - bounds.lonRange.lowerBound) / lonSpan * Double(size.width)
        let y = (bounds.latRange.upperBound - lat) / latSpan * Double(size.height)
        return CGPoint(x: x, y: y)
    }

    private func projectedPoint(
        lat: Double, lon: Double, in size: CGSize, bounds: MapBounds
    ) -> CGPoint {
        Self.projectedPoint(lat: lat, lon: lon, in: size, bounds: bounds)
    }
}

// MARK: - Static outline shape

/// Shape that draws every country outline once. SwiftUI calls `path(in:)`
/// when the view is reconciled, and Core Animation rasterises the result —
/// it is **not** re-encoded per frame (unlike a `Canvas` body, which is
/// immediate-mode per Apple's `Canvas` docs). Re-renders only when `rings`
/// changes, which happens once at boot when `WorldGeometry` finishes its
/// background parse.
private struct WorldOutlineShape: Shape {
    let rings: [String: [[CLLocationCoordinate2D]]]
    let bounds: WelcomeHero.MapBounds

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !rings.isEmpty else { return path }
        let size = rect.size
        for (_, polygons) in rings {
            for ring in polygons where ring.count > 2 {
                var first = true
                for coord in ring {
                    let pt = WelcomeHero.projectedPoint(
                        lat: coord.latitude,
                        lon: coord.longitude,
                        in: size,
                        bounds: bounds
                    )
                    if first {
                        path.move(to: CGPoint(x: rect.minX + pt.x, y: rect.minY + pt.y))
                        first = false
                    } else {
                        path.addLine(to: CGPoint(x: rect.minX + pt.x, y: rect.minY + pt.y))
                    }
                }
                path.closeSubpath()
            }
        }
        return path
    }
}
