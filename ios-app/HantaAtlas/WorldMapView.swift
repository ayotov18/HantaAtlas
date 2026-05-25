import SwiftUI
import MapKit
import CoreLocation

/// Full-bleed dark map with native iOS 26 Liquid Glass chrome.
///
/// Chrome stack:
/// - Right-rail: a single stacked Liquid Glass control group. The three rows
///   share one glass union so the surface reads as one iOS 26 control, while
///   each row keeps its own tap target.
/// - Bottom hub: plain Liquid Glass surfaces that expand/collapse without
///   matched geometry. This avoids feeding layout changes back into MapKit.
/// - Layers: presented as a native `.sheet` with detents so it covers the
///   TabView's floating tab bar correctly.
///
/// All chrome respects the system tab bar — the bottom hub is positioned with
/// enough bottom padding to clear the floating tab bar.
struct WorldMapView: View {
    let repository: SurveillanceRepository
    let preferences: LocalPreferences

    // MARK: - Map state
    @State private var selectedSignalId: String? = nil
    @State private var selectedCountryCode: String? = nil
    @State private var selectedSignalScreenPoint: CGPoint? = nil

    /// Gates the heavy first-render content (country polygons, outbreak
    /// routes) so the base map and tab transition can settle before MapKit
    /// starts uploading polygon vertices to the GPU.
    @State private var heavyContentReady: Bool = false
    @State private var countryFillCache: [CountryFillPolygon] = []
    @State private var visibleSignalDots: [SignalDot] = []

    /// Programmatic camera move. Setting this to a fresh value (with a new
    /// id) tells `MapboxMapHostView` to fly the camera to the target. User
    /// pan/pinch/pitch/rotate are owned by `MKMapView` internally and
    /// never touch this state — that's the whole point of switching to
    /// `UIViewRepresentable`. See `MapboxMapHostView` for the full rationale.
    @State private var cameraCommand: MapboxMapHostView.CameraCommand? = nil

    // On-screen widget that appears when a dot is tapped. It is intentionally
    // bottom-anchored instead of coordinate-anchored so Map gestures never have
    // to pass through a full-screen MapReader/proxy overlay.
    @State private var dotWidgetExpanded: Bool = false
    @State private var pushedArtifactSignal: Signal? = nil

    // Timeline state: dots are filtered by full selected day, not by a raw
    // timestamp. The slider owns day buckets; `timelineCutoffDate` expands the
    // selected day to 23:59:59 so scrubbing to "May 10" includes every May 10
    // record instead of only records earlier than the current clock time.
    @State private var timelineDate: Date = Date()
    @State private var timelineNow: Date = Date()
    @State private var timelineRangeStartDate: Date = Calendar.current.date(
        byAdding: .day,
        value: -90,
        to: Calendar.current.startOfDay(for: Date())
    ) ?? Date()
    @State private var timelineExpanded: Bool = false
    /// Per-signal cache of derived `(postType, jitterCoordinate)`.
    ///
    /// Signal.mapPostType runs keyword regex over title + summary on every
    /// access, and SignalDot.jitter does hash+trig math. With 100+ signals
    /// being re-evaluated 60×/sec while the user drags the timeline slider,
    /// that was the main cause of the FPS drop the user reported. We compute
    /// it once when `repository.signals` changes, then `signalDots` becomes a
    /// pure filter — no regex, no math, just a dictionary lookup per signal.
    @State private var dotCache: [String: SignalDotCacheEntry] = [:]
    private struct SignalDotCacheEntry {
        let postType: MapPostType
        let coordinate: CLLocationCoordinate2D
    }

    // MARK: - Layer toggles
    /// Visible post types on the map. Default = all on. The user can toggle
    /// any combination from the layers sheet.
    @State private var visiblePostTypes: Set<MapPostType> = Set(MapPostType.allCases)
    @State private var showCountryFill: Bool = true
    @State private var showOutbreakRoutes: Bool = true
    @State private var showLayersSheet: Bool = false
    @State private var outbreakRoutes = OutbreakRoutes.shared

    /// The single primary "what am I looking at" switch. Drives
    /// `visiblePostTypes` and `showCountryFill` directly. The LayersSheet
    /// remains available beneath this for fine-tuning within the mode.
    /// Persisted to UserDefaults so the user returns to their preferred
    /// mode across launches.
    @AppStorage("hantaatlas.map.displayMode")
    private var displayModeRaw: String = MapDisplayMode.confidence.rawValue
    private var displayMode: MapDisplayMode {
        MapDisplayMode(rawValue: displayModeRaw) ?? .confidence
    }

    /// Collapsed/expanded state of the bottom-left mode picker (the
    /// `modePicker` view below). When false the picker is a single icon
    /// showing the currently-active mode; when true it morphs via
    /// `GlassEffectContainer` into a vertically-stacked rail of all five
    /// modes — same Liquid Glass aesthetic as the right rail.
    @State private var modePickerExpanded: Bool = false
    @State private var lastRenderedDiseaseMode: DiseaseMode = .both

    /// Per-session flag: have we already fired the one-shot "centre the
    /// map on the user's current location" focus? Flips true the moment
    /// we issue the focusOn — subsequent location updates won't re-frame
    /// the camera, and a fresh app launch resets it to false (it's
    /// @State, not @AppStorage). Without this gate, the location service
    /// could deliver a second fix moments after the user pans away and
    /// snap them back to their start point.
    @State private var hasAutoCenteredOnUser: Bool = false

    // MARK: - Bottom hub
    @State private var hubExpanded: Bool = false

    // MARK: - Right-rail union
    @Namespace private var railNamespace

    // MARK: - Location priming
    @State private var locationService = LocationService.shared
    @State private var showLocationPrimer: Bool = false
    @State private var pendingLocationFocus: PendingLocationFocus? = nil
    @State private var locationFeedback: LocationFeedback? = nil

    /// Bottom padding that clears the iOS 26 floating tab bar.
    private let tabBarClearance: CGFloat = 92

    /// The first-launch camera target for a worldwide product. Centered
    /// just north of the equator (15°N) so the visible portion balances
    /// the heavier Northern Hemisphere land mass; longitude 0 so the
    /// Americas (left half) and Eurasia/Africa (right half) share the
    /// frame; a 140° latitude span so the full reachable map (-65°S to
    /// 75°N, the band MapKit's web Mercator can render without clipping)
    /// is visible on an iPhone screen at first paint. Heading and pitch
    /// are 0 — no tilt or rotation — so the user immediately understands
    /// they're looking at a global overview, not a data-driven framing
    /// of any one continent.
    ///
    /// This is the deterministic default the entire camera-priority
    /// system falls back to when there's no user-saved gesture-driven
    /// camera, no tracked-countries fit request, and no explicit
    /// "my location" tap. It must NOT depend on signal data, alert
    /// centroids, or overlay content — those caused the previous
    /// South-America-centred reopen behaviour.
    private static let worldRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 15, longitude: 0),
        span:   MKCoordinateSpan(latitudeDelta: 140, longitudeDelta: 360)
    )

    private static let defaultCamera = MapCamera(
        centerCoordinate: worldRegion.center,
        distance: distance(forSpanDegrees: 110),
        heading: 0,
        pitch: 0
    )
    private static let defaultCameraPosition: MapCameraPosition = .camera(defaultCamera)

    // MARK: - Derived data

    private var signalDots: [SignalDot] {
        visibleSignalDots
    }

    private var timelineRangeStart: Date {
        timelineRangeStartDate
    }

    private var timelineRangeEnd: Date {
        Calendar.current.startOfDay(for: timelineNow)
    }

    private var timelineCutoffDate: Date {
        let cal = Calendar.current
        let selectedDay = cal.startOfDay(for: timelineDate)
        return cal.date(byAdding: DateComponents(day: 1, second: -1), to: selectedDay) ?? timelineDate
    }

    /// Composite signature for the `rebuildCountryFillCache` trigger.
    /// Combines every input that should invalidate the choropleth cache
    /// into a single Equatable value so we can watch it via one
    /// `.onChange` modifier instead of four. SwiftUI's `.onChange(of:)`
    /// triggers on any inequality, so as long as one component of the
    /// signature changes between body evaluations, the rebuild fires.
    private var countryFillCacheSignature: CountryFillSignature {
        CountryFillSignature(
            aggregatesCount: repository.aggregates.count,
            ringsCount: WorldGeometry.shared.rings.count,
            showCountryFill: showCountryFill,
            heavyContentReady: heavyContentReady
        )
    }

    private struct CountryFillSignature: Equatable {
        let aggregatesCount: Int
        let ringsCount: Int
        let showCountryFill: Bool
        let heavyContentReady: Bool
    }

    /// Composite signature for inputs that always rebuild both the
    /// visible-dot cache and the country-fill cache. Combining them into
    /// one `.onChange` instead of three drops the body's modifier count
    /// far enough under the SwiftUI type-checker's ceiling that the
    /// location-fix `.onChange(of: locationService.current)` can coexist.
    private var dotsAndFillsSignature: DotsAndFillsSignature {
        DotsAndFillsSignature(
            visiblePostTypeCount: visiblePostTypes.count,
            visiblePostTypeHash: visiblePostTypes.hashValue,
            savedCountriesCount: preferences.savedCountryCodes.count,
            trackAllCountries: preferences.trackAllCountries,
            diseaseModeRaw: preferences.selectedDiseaseMode.rawValue
        )
    }

    private struct DotsAndFillsSignature: Equatable {
        let visiblePostTypeCount: Int
        let visiblePostTypeHash: Int
        let savedCountriesCount: Int
        let trackAllCountries: Bool
        let diseaseModeRaw: String
    }

    /// `CLLocationCoordinate2D` is not Equatable, so we can't pass
    /// `locationService.current` directly to `.onChange(of:)`. Wrap the
    /// coordinate's latitude+longitude into an Equatable struct that
    /// SwiftUI can diff. Returns nil when there's no fix yet, which
    /// `.onChange(of:)` handles correctly for Optional.
    private var locationCoordinateKey: LocationKey? {
        locationService.current.map { LocationKey(lat: $0.latitude, lon: $0.longitude) }
    }

    private struct LocationKey: Equatable {
        let lat: Double
        let lon: Double
    }

    private struct PendingLocationFocus: Equatable {
        let id: UUID
        let span: CLLocationDegrees

        init(span: CLLocationDegrees) {
            self.id = UUID()
            self.span = span
        }
    }

    private struct LocationFeedback: Equatable, Identifiable {
        let id: UUID
        let symbol: String
        let message: String
        let isWarning: Bool

        init(symbol: String, message: String, isWarning: Bool = false) {
            self.id = UUID()
            self.symbol = symbol
            self.message = message
            self.isWarning = isWarning
        }
    }

    /// Upper bound on visible map dots. Beyond ~1 500 individual
    /// `MKAnnotationView`s the device starts spending more time on
    /// annotation diff/recycling than on actual rendering. On-device
    /// debug sessions (iPhone 15 / iOS 26.5) terminated with code 9
    /// memory-pressure crashes after ~8 minutes of interactive use
    /// when the visible dot count climbed past ~3 000. This cap
    /// keeps MapKit's annotation pipeline within a budget that
    /// stays comfortably under the per-app memory ceiling.
    ///
    /// We render the most recent `MAX_VISIBLE_DOTS` signals (sorted
    /// by `publishedAt` descending) and drop the rest from the map —
    /// older signals are still accessible via the Feed and the
    /// per-country detail screens, just not pinned individually.
    private static let MAX_VISIBLE_DOTS = 1500

    private func rebuildVisibleSignalDots() {
        // Hot path for Map camera gestures: keep camera-position writes from
        // causing regex or jitter work. This cache is rebuilt only when the
        // timeline/filter/source inputs change.
        let cutoff = timelineCutoffDate
        var out: [SignalDot] = []
        out.reserveCapacity(min(repository.signals.count, Self.MAX_VISIBLE_DOTS))

        // Iterate in newest-first order so we naturally fill `out` with
        // the freshest signals up to the cap, then early-exit without
        // touching the long tail. `repository.signals` is already kept
        // sorted descending by publishedAt by the repository layer; if
        // that invariant ever changes, this loop becomes O(N log N)
        // instead of O(N) but the cap still holds.
        for signal in repository.signals {
            if out.count >= Self.MAX_VISIBLE_DOTS { break }
            guard let cached = dotCache[signal.id] else { continue }
            guard preferences.shouldShowCountry(signal.countryISO) else { continue }
            guard visiblePostTypes.contains(cached.postType) else { continue }
            guard signal.publishedAt <= cutoff else { continue }
            out.append(SignalDot(
                signal: signal,
                postType: cached.postType,
                coordinate: cached.coordinate,
                effectiveDate: signal.publishedAt,
                isProjected: false
            ))
        }
        visibleSignalDots = out
    }

    /// Rebuild the dot cache. Called whenever the underlying signals change.
    /// Runs the (relatively expensive) keyword classifier + jitter once per
    /// signal so the per-frame slider drag stays cheap.
    private func rebuildDotCache() {
        var next: [String: SignalDotCacheEntry] = [:]
        next.reserveCapacity(repository.signals.count)
        for s in repository.signals {
            guard let iso = s.countryISO,
                  let centroid = CountryCentroids.coordinate(for: iso) else { continue }
            next[s.id] = SignalDotCacheEntry(
                postType: s.mapPostType,
                coordinate: SignalDot.jitter(around: centroid, seed: s.id)
            )
        }
        dotCache = next
        rebuildVisibleSignalDots()
    }

    private func rebuildCountryFillCache() {
        guard heavyContentReady, showCountryFill else {
            countryFillCache = []
            return
        }

        let cutoff = timelineCutoffDate
        var visibleSignalLevels: [String: CountryActiveLevel] = [:]
        visibleSignalLevels.reserveCapacity(repository.aggregates.count)
        for signal in repository.signals {
            guard signal.publishedAt <= cutoff else { continue }
            guard preferences.shouldShowCountry(signal.countryISO) else { continue }
            guard let iso = signal.countryISO?.uppercased(),
                  let cached = dotCache[signal.id],
                  visiblePostTypes.contains(cached.postType) else { continue }
            visibleSignalLevels[iso] = strongestCountryLevel(
                visibleSignalLevels[iso] ?? .none,
                countryLevel(for: cached.postType)
            )
        }

        let hasSignalLayer = !repository.signals.isEmpty
        var aggMap: [String: CountrySignalAggregate] = [:]
        if !hasSignalLayer {
            for aggregate in repository.aggregates {
                aggMap[aggregate.countryISO.uppercased()] = aggregate
            }
        }

        var out: [CountryFillPolygon] = []
        for (iso, rings) in WorldGeometry.shared.rings {
            guard preferences.shouldShowCountry(iso) else { continue }
            let level: CountryActiveLevel
            if let signalLevel = visibleSignalLevels[iso.uppercased()], signalLevel != .none {
                level = signalLevel
            } else if !hasSignalLayer,
                      let agg = aggMap[iso.uppercased()],
                      agg.activeLevel != .none,
                      aggregateLevelIsVisible(agg.activeLevel) {
                level = agg.activeLevel
            } else if WorldGeometry.endemicCountries.contains(iso) {
                level = .endemic
            } else {
                continue
            }
            for (idx, ring) in rings.enumerated() where ring.count >= 3 {
                out.append(CountryFillPolygon(iso: iso, ringIndex: idx, level: level, ring: ring))
            }
        }
        countryFillCache = out
    }

    private func countryLevel(for postType: MapPostType) -> CountryActiveLevel {
        switch postType {
        case .death, .caseConfirmed, .caseSuspected:
            return .active
        case .caseImported:
            return .imported
        case .officialResponse, .expertVoice, .publicDiscourse:
            return .response
        }
    }

    private func aggregateLevelIsVisible(_ level: CountryActiveLevel) -> Bool {
        switch level {
        case .active:
            return visiblePostTypes.contains(.death)
                || visiblePostTypes.contains(.caseConfirmed)
                || visiblePostTypes.contains(.caseSuspected)
        case .imported:
            return visiblePostTypes.contains(.caseImported)
        case .response:
            return visiblePostTypes.contains(.officialResponse)
                || visiblePostTypes.contains(.expertVoice)
                || visiblePostTypes.contains(.publicDiscourse)
        case .endemic, .none:
            return true
        }
    }

    private func strongestCountryLevel(_ lhs: CountryActiveLevel, _ rhs: CountryActiveLevel) -> CountryActiveLevel {
        countryLevelRank(rhs) > countryLevelRank(lhs) ? rhs : lhs
    }

    private func countryLevelRank(_ level: CountryActiveLevel) -> Int {
        switch level {
        case .none: return 0
        case .response: return 1
        case .imported, .endemic: return 2
        case .active: return 3
        }
    }

    private var selectedCountrySnapshot: CountrySnapshot? {
        guard let code = selectedCountryCode else { return nil }
        return repository.country(isoCode: code)
    }

    private var selectedSignalDot: SignalDot? {
        guard let id = selectedSignalId else { return nil }
        return signalDots.first(where: { $0.id == id })
    }

    /// Per-day event counts — feeds the scrubber's spike markers.
    ///
    /// Was a computed property that re-bucketed `repository.signals` every
    /// time the body re-evaluated. During the timeline morph animation that
    /// turned into a 60Hz allocation of a fresh `[Date: Int]` of size N — the
    /// "memory leak when animating" the user reported. Now cached in @State
    /// and rebuilt only when the underlying signal set actually changes.
    @State private var dailyEventCounts: [Date: Int] = [:]

    private func rebuildDailyEventCounts() {
        let cal = Calendar.current
        var counts: [Date: Int] = [:]
        for s in repository.signals {
            let day = cal.startOfDay(for: s.publishedAt)
            counts[day, default: 0] += 1
        }
        dailyEventCounts = counts
    }

    private func rebuildTimelineBounds(resetToToday: Bool = false) {
        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)
        let fallback = cal.date(byAdding: .day, value: -90, to: today) ?? today
        let earliest = repository.signals.map(\.publishedAt).min().map { cal.startOfDay(for: $0) }

        timelineNow = now
        timelineRangeStartDate = min(earliest ?? fallback, fallback)

        let selectedDay = cal.startOfDay(for: timelineDate)
        if resetToToday || selectedDay < timelineRangeStartDate || selectedDay > today {
            timelineDate = today
        } else if selectedDay != timelineDate {
            timelineDate = selectedDay
        }
    }

    // MARK: - Body
    //
    // Split into three computed properties so each fits under SwiftUI's
    // type-checker complexity ceiling. The previous flat body — ZStack
    // followed by 12+ modifiers — kept hitting "compiler is unable to
    // type-check this expression in reasonable time" as we added the
    // user-location-on-launch hook. Restructuring is cosmetic; nothing
    // about the rendered output changes.
    //
    //   body            → applies modal/destination presenters
    //   decoratedStack  → applies lifecycle modifiers (.onAppear, every
    //                     .onChange, environment)
    //   rawMapStack     → the ZStack of Theme.graphite + mapLayer + chrome

    var body: some View {
        decoratedStack
            .sheet(isPresented: $showLocationPrimer) {
                LocationPrimerSheet(
                    onAllow: {
                        locationService.requestWhenInUse()
                        showLocationFeedback(
                            "Finding your location...",
                            symbol: "location.fill",
                            autoDismissAfter: 3.0
                        )
                        showLocationPrimer = false
                    },
                    onDecline: {
                        pendingLocationFocus = nil
                        showLocationFeedback(
                            "Location skipped",
                            symbol: "location.slash",
                            isWarning: true,
                            autoDismissAfter: 2.4
                        )
                        showLocationPrimer = false
                    }
                )
                .presentationDetents([.height(440)])
                .presentationDragIndicator(.visible)
            }
            .navigationDestination(item: $pushedArtifactSignal) { signal in
                SignalArtifactView(signal: signal)
            }
            .sheet(isPresented: $showLayersSheet) {
                LayersSheet(
                    visiblePostTypes: $visiblePostTypes,
                    showCountryFill: $showCountryFill,
                    showOutbreakRoutes: $showOutbreakRoutes
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
                .presentationCornerRadius(34)
            }
    }

    /// Map stack with all lifecycle modifiers applied. Extracted from `body`
    /// so the sheets/destinations live in a separate type-check unit and
    /// keep the SwiftUI compiler under its complexity ceiling.
    private var decoratedStack: some View {
        rawMapStack
            .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        // Scope dark colorScheme to the ENTIRE Map subtree (Map + chrome).
        //
        // Why: Apple's Liquid Glass renders in either a light or dark variant
        // based on the SwiftUI `\.colorScheme` environment value, NOT on the
        // pixels actually behind the glass. The app forces light at WindowGroup
        // level (`preferredColorScheme(.light)`), so without this override the
        // right rail, timeline scrubber, and bottom-hub strip rendered in the
        // light glass variant on top of the dark map — reading as milky white.
        // Putting `.environment(\.colorScheme, .dark)` here makes all chrome
        // descendants (rightRail, timeline strip, bottom-feed strip) request
        // the dark glass variant, which is what Apple Maps and Find My use over
        // their dark map tiles.
        //
        // We keep the same modifier on the inner Map element too as defence
        // in depth — it's harmless duplication.
        //
        // FPS / memory note: previously had `.animation(.easeOut, value: timelineDate)`
        // here, which fired a 0.3s animation for every value change of the slider —
        // at 60Hz drag, 60 stacked animations/sec held view-graph references that
        // never released. That was the leak. Removed.
        .environment(\.colorScheme, .dark)
        .onAppear {
            // Restore the persisted display mode's post-type subset on first
            // appearance. Without this, the AppStorage-backed mode would
            // visually drift from `visiblePostTypes` (which always defaults
            // to Set(allCases) on a fresh process) until the user manually
            // re-tapped a segment.
            applyDisplayMode(displayMode)
            lastRenderedDiseaseMode = preferences.selectedDiseaseMode
            rebuildTimelineBounds(resetToToday: true)
            rebuildDotCache()
            rebuildDailyEventCounts()
            prepareHeavyMapContent()

            // First-launch location centering. The product expectation is
            // that opening the map drops the user onto their own country,
            // not a global overview — for outbreak surveillance the
            // "what's happening near me" framing is the right first paint.
            //
            // Priority (matches the spec from the previous turn):
            //   1. If the user has already moved the camera in any prior
            //      session, leave it alone (PersistedCamera will have
            //      restored that view in MapboxMapHostView.configureMapViewIfNeeded).
            //   2. If we already have permission AND a fix, focusOn()
            //      immediately.
            //   3. If permission is missing or denied, do nothing — the
            //      startup permission gate is the only automatic prompt.
            //
            // The hasAutoCenteredOnUser flag prevents a second location fix
            // arriving moments later from snapping the camera back after the
            // user has panned away.
            attemptInitialLocationCentre()
        }
        .onChange(of: locationCoordinateKey) { _, _ in
            handleLocationServiceUpdate(locationService.current)
        }
        .onChange(of: repository.signals) { _, _ in
            rebuildTimelineBounds()
            rebuildDotCache()
            rebuildDailyEventCounts()
            rebuildCountryFillCache()
        }
        .onChange(of: timelineDate) { _, _ in
            rebuildVisibleSignalDots()
            rebuildCountryFillCache()
        }
        // Inputs that always rebuild BOTH the visible-dots cache AND the
        // country-fill cache: visiblePostTypes, savedCountryCodes,
        // trackAllCountries. Bundled into one composite signature so we
        // spend one .onChange instead of three. The SwiftUI type-checker
        // gives up somewhere around eleven modifiers on this chain.
        .onChange(of: dotsAndFillsSignature) { _, _ in
            handleDotsAndFillsSignatureChanged()
        }
        // Inputs that only need rebuildCountryFillCache: aggregates,
        // GeoJSON rings, the fill-overlay toggle, the heavy-content gate.
        .onChange(of: countryFillCacheSignature) { _, _ in rebuildCountryFillCache() }
    }

    /// Bare ZStack — the Map plus chrome — with no modifiers. Tiny enough
    /// that the type-checker handles it instantly, even at the worst
    /// case of body re-evaluation cascading through every dependent.
    private var rawMapStack: some View {
        // ── CRITICAL: `mapLayer` MUST live OUTSIDE the GeometryReader's
        // if/else branch ──────────────────────────────────────────────────
        //
        // The previous structure wrapped the Map in:
        //
        //     GeometryReader { geo in
        //         if geo.size.width > 1 { ZStack { ...mapLayer... } }
        //         else { Theme.graphite }
        //     }
        //
        // SwiftUI only instantiates the *taken* branch. The first layout
        // pass produces `geo.size == .zero`, so the view starts in the
        // `else` branch (no Map), then flips to `if` on the next pass.
        // That's a fresh identity for the Map subtree → fresh @State →
        // MapKit re-seeds the camera from `initialPosition` /
        // `cameraPosition`'s default — exactly the snap-back the user
        // reported. Hoisting `mapLayer` keeps its identity stable.
        ZStack {
            // Use `Theme.graphite` (warm-dark, not pure black) as the
            // under-layer. Visible while MapKit's first tile pass
            // streams in — reads as "loading" rather than a void.
            Theme.graphite.ignoresSafeArea()
            mapLayer
            GeometryReader { geo in
                if geo.size.width > 1 && geo.size.height > 1 {
                    ZStack {
                        chrome
                        if let dot = selectedSignalDot {
                            selectedSignalWidget(for: dot)
                        }
                    }
                    .frame(width: max(geo.size.width, 1), height: max(geo.size.height, 1))
                }
            }
        }
    }

    // MARK: - Chrome (Liquid Glass overlay layer)

    private var chrome: some View {
        ZStack {
            VStack {
                HStack {
                    DiseaseModeSwitcher(preferences: preferences, compact: true)
                        .frame(maxWidth: 330)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 58)
                Spacer()
            }

            // Right-rail: native Liquid Glass buttons (top-anchored to bottom-right).
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    rightRail
                        .padding(.trailing, 14)
                        .padding(.bottom, tabBarClearance + rightRailBottomOffset)
                        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: hubExpanded)
                        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: timelineExpanded)
                }
            }

            if let locationFeedback {
                VStack {
                    locationFeedbackToast(locationFeedback)
                        .padding(.top, 58)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .allowsHitTesting(false)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // (Country drawer removed — replaced by the on-screen
            // SignalDotWidget that floats next to the tapped dot.)

            ZStack(alignment: .bottom) {
                // Bottom-anchored expanded surface. The previous implementation
                // used matched Liquid Glass IDs and unions here; over MapKit
                // that produced AttributeGraph cycles. Plain glass keeps the
                // iOS 26 material without feeding layout back into itself.
                VStack {
                    Spacer()
                    if hubExpanded {
                        expandedHub
                            .glassEffect(.regular, in: .rect(cornerRadius: 22))
                            .padding(.horizontal, 14)
                            .padding(.bottom, tabBarClearance)
                    } else if timelineExpanded {
                        TimelineScrubber(
                            date: $timelineDate,
                            rangeStart: timelineRangeStart,
                            rangeEnd: timelineRangeEnd,
                            now: timelineNow,
                            dailyEventCounts: dailyEventCounts,
                            onDismiss: {
                                withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                                    timelineExpanded = false
                                }
                            }
                        )
                        .glassEffect(.regular, in: .rect(cornerRadius: 22))
                        .padding(.horizontal, 14)
                        .padding(.bottom, tabBarClearance + 12)
                    }
                }

                VStack {
                    Spacer()
                    HStack {
                        VStack(spacing: 8) {
                            // Mode picker sits at the TOP of the left-rail
                            // stack (so when it expands, its 5-entry stack
                            // grows UPWARD into free space — the leftHandle
                            // and timelineRailEntry stay glued to the bottom
                            // safe-area edge). Hidden while the signals hub
                            // or timeline are open so we never have three
                            // bottom-anchored surfaces fighting for space.
                            if !hubExpanded && !timelineExpanded {
                                modePicker
                            }
                            if !hubExpanded && !modePickerExpanded {
                                leftHandle
                                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
                            }
                            if !timelineExpanded && !modePickerExpanded {
                                timelineRailEntry
                                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
                            }
                        }
                        .padding(.leading, 14)
                        .padding(.bottom, tabBarClearance + 18)
                        Spacer()
                    }
                }
            }
            .animation(.spring(response: 0.46, dampingFraction: 0.84), value: hubExpanded)
            .animation(.spring(response: 0.46, dampingFraction: 0.84), value: timelineExpanded)
        }
    }

    // MARK: - Display-mode picker (bottom-left, vertically stacked)
    //
    // Replaces the previous horizontal top-bar segmented control. The new
    // component matches the right-rail aesthetic exactly — same iOS 26
    // Liquid Glass surface, same vertical-stack-of-icons rhythm, same
    // `GlassEffectContainer { ... } / glassEffectUnion(id:namespace:)`
    // morph plumbing Apple introduced in WWDC25's Liquid Glass session.
    //
    // Collapsed state (default): a single 44pt rounded-rect icon showing
    // the currently-active mode. Tapping it expands the container into a
    // vertically-stacked rail of all five modes — like an Apple Clock
    // alarm wheel but with Glass fluidity rather than a wheel renderer.
    // Tapping any entry in the expanded state applies that mode and
    // collapses back. Tapping outside the picker (anywhere on the map
    // chrome) also collapses without changing the mode.
    //
    // Mutual exclusivity (same pattern leftHandle ↔ timelineRailEntry use):
    // expanding the picker collapses the signals hub and the timeline
    // strip; opening either of those collapses the picker. One bottom-
    // anchored surface visible at a time.

    private var modePicker: some View {
        GlassEffectContainer(spacing: 0) {
            VStack(spacing: 0) {
                if modePickerExpanded {
                    // Expanded: every mode, current-mode tinted terracotta.
                    // GlassEffectUnion stitches the rectangles into one
                    // continuous glass surface — the icons appear to morph
                    // out of the same blob the collapsed pill came from.
                    ForEach(MapDisplayMode.allCases) { mode in
                        modeEntry(mode: mode, isCurrent: mode == displayMode)
                    }
                } else {
                    // Collapsed: current mode only. Tap expands.
                    modeEntry(mode: displayMode, isCurrent: true)
                }
            }
        }
        .animation(.spring(response: 0.46, dampingFraction: 0.84), value: modePickerExpanded)
    }

    /// One row in the mode picker. Tap handler is context-aware:
    ///   - collapsed → tap expands the picker (no mode change)
    ///   - expanded  → tap applies the tapped mode + collapses
    /// `.onTapGesture` (not `Button`) intentionally — nesting a Button
    /// inside `.interactive()` Liquid Glass produces gesture-recogniser
    /// conflicts (the right rail's `railEntry` made the same choice and
    /// the project's `.claude/skills/swiftui-ios-26` skill documents it).
    private func modeEntry(mode: MapDisplayMode, isCurrent: Bool) -> some View {
        Image(systemName: mode.symbolName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(isCurrent ? Theme.terracotta : .white)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                    if modePickerExpanded {
                        if mode != displayMode {
                            applyDisplayMode(mode)
                        }
                        modePickerExpanded = false
                    } else {
                        // Opening the picker is mutually exclusive with the
                        // hub and timeline surfaces — collapse them so we
                        // never have two bottom-anchored panels expanded at
                        // once (which would overflow the safe area and
                        // overlap the floating tab bar).
                        hubExpanded = false
                        timelineExpanded = false
                        modePickerExpanded = true
                    }
                }
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
            .glassEffectUnion(id: "mode-picker", namespace: railNamespace)
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text(mode.shortTitle))
            .accessibilityHint(Text(mode.accessibilityHint))
    }

    /// Applies a display mode by rewriting `visiblePostTypes` to the mode's
    /// resolved subset. Persists the choice via `displayModeRaw`. Does NOT
    /// touch camera state. Cascades through the existing `.onChange(of:
    /// visiblePostTypes)` handler so the rebuild path stays single-source.
    private func applyDisplayMode(_ mode: MapDisplayMode) {
        displayModeRaw = mode.rawValue
        let resolved = mode.visiblePostTypes
        if visiblePostTypes != resolved {
            visiblePostTypes = resolved
        }
        // Confidence mode emphasises the choropleth, so force the country
        // fill overlay on for that mode and leave the user's toggle alone
        // for every other mode.
        if mode == .confidence && !showCountryFill {
            showCountryFill = true
        }
    }

    // MARK: - Map

    private var mapLayer: some View {
        // ── UIViewRepresentable wrapping MKMapView ────────────────────────
        //
        // Pure SwiftUI `Map(...)` could not reliably preserve user
        // pan/pinch/pitch/rotate state in this view: every documented
        // pattern (`Map(position:)`, `Map(initialPosition:)`,
        // `mapCameraKeyframeAnimator`, `.onMapCameraChange(.onEnd)`
        // write-back, `.continuous` write-back) ended up either snapping
        // the camera back to the default on body re-eval, or locking the
        // gesture entirely. iOS 26 Map's bidirectional binding semantics
        // are not robust enough for a parent view with this much state
        // churn (eight `.onChange` handlers, GeometryReader, frequent
        // .onChange-driven cache rebuilds).
        //
        // `MKMapView` owns its camera as imperative state — there is no
        // SwiftUI binding for the parent to re-apply, so the camera
        // simply stays where the user put it. This is also what unlocks
        // free 360° heading rotation while pitched, which the SwiftUI
        // Map appeared to clamp.
        //
        // See MapboxMapHostView.swift for the bridging details.
        MapboxMapHostView(
            signalDots: visibleSignalDots,
            countryFillPolygons: heavyContentReady ? countryFillCache : [],
            outbreakRoutes: heavyContentReady && showOutbreakRoutes ? outbreakRoutes.routes : [],
            showsUserLocation: hasLocationAuthorization,
            selectedSignalId: selectedSignalId,
            cameraCommand: $cameraCommand,
            initialCenter: WorldMapView.worldRegion.center,
            initialDistance: WorldMapView.distance(
                forSpanDegrees: WorldMapView.worldRegion.span.latitudeDelta
            ),
            onSignalTap: handleDotTap,
            onSelectedSignalScreenPointChange: { point in
                if selectedSignalScreenPoint != point {
                    selectedSignalScreenPoint = point
                }
            }
        )
        .ignoresSafeArea()
    }

    private func prepareHeavyMapContent() {
        guard !heavyContentReady else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1_400))
            guard !heavyContentReady else { return }
            heavyContentReady = true
            rebuildCountryFillCache()
        }
    }

    /// Rough conversion from a span-in-degrees (the legacy `MKCoordinateSpan`
    /// shape used by `focusOn`) to the camera distance the iOS 17+ MapCamera
    /// expects. Empirical: 1° ≈ 110 km of meridian; multiply by ~1.4 to clear
    /// the safe-area / edge falloff so the user can see the surrounding
    /// context. Good enough for editorial framing — not navigation-grade.
    fileprivate static func distance(forSpanDegrees span: CLLocationDegrees) -> CLLocationDistance {
        let metersPerDegree: CLLocationDistance = 111_000
        return span * metersPerDegree * 1.4
    }

    // MARK: - Right-rail (stacked Liquid Glass control group)

    /// Right-rail of three buttons unified into one stacked Liquid Glass
    /// surface. The union is static and local to this rail, so it preserves the
    /// intended iOS 26 control design without driving the map camera state.
    private var rightRail: some View {
        GlassEffectContainer(spacing: 0) {
            VStack(spacing: 0) {
                railEntry(
                    symbol: "location.fill",
                    isActive: hasLocationAuthorization,
                    accessibilityLabel: "Centre tightly on my location",
                    action: handleLocateTap
                )
                railEntry(
                    symbol: "square.stack.3d.up",
                    isActive: !visiblePostTypes.isEmpty,
                    accessibilityLabel: "Map layers",
                    action: { showLayersSheet = true }
                )
                railEntry(
                    symbol: "location.viewfinder",
                    isActive: hasLocationAuthorization,
                    accessibilityLabel: "Zoom to my country",
                    action: handleZoomToCountryTap
                )
            }
        }
    }

    /// One rail button. `.onTapGesture` (not Button) because nesting a Button
    /// inside `.interactive()` glass caused gesture recogniser conflicts here.
    private func railEntry(
        symbol: String,
        isActive: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(isActive ? Theme.terracotta : .white)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
            .glassEffectUnion(id: "right-rail", namespace: railNamespace)
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text(accessibilityLabel))
    }

    private var hasLocationAuthorization: Bool {
        locationService.authorization == .authorizedWhenInUse
            || locationService.authorization == .authorizedAlways
    }

    private func locationFeedbackToast(_ feedback: LocationFeedback) -> some View {
        HStack(spacing: 9) {
            Image(systemName: feedback.symbol)
                .font(.system(size: 14, weight: .bold))
            Text(feedback.message)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(
            .regular.tint((feedback.isWarning ? Theme.terracotta : Theme.olive).opacity(0.32)),
            in: .rect(cornerRadius: 24)
        )
        .accessibilityHidden(true)
    }

    /// Bottom-padding for the right rail. Pushes UP whenever a bottom-
    /// anchored Liquid Glass strip is visible, so the rail doesn't collide.
    /// Values are tuned to match the heights of each strip + its own padding:
    ///   - Feed sheet expanded: 480pt
    ///   - Timeline strip visible: 130pt
    ///   - Both stack additively if somehow both are open at once.
    private var rightRailBottomOffset: CGFloat {
        var offset: CGFloat = 60  // base — clear of the timeline button in the rail
        if hubExpanded { offset += 420 }
        if timelineExpanded { offset += 130 }
        return offset
    }

    /// Collapsed state of the timeline control. The glass effect itself is
    /// applied at the call site, so this view is plain content.
    private var timelineRailEntry: some View {
        let isAtNow = Calendar.current.isDate(timelineDate, inSameDayAs: timelineNow)
        let tint: Color = isAtNow ? .white : Theme.terracotta

        return VStack(spacing: 2) {
            Image(systemName: "clock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
            if !isAtNow {
                Text(compactOffset)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: 48, height: isAtNow ? 44 : 56)
        .contentShape(Rectangle())
        .onTapGesture {
            // Mutual exclusivity: opening the timeline collapses the signals
            // hub if it's open. Both happen in one withAnimation block so the
            // matched-geometry morph runs end-to-end on the same spring.
            withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                hubExpanded = false
                timelineExpanded = true
            }
        }
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("Open timeline"))
    }

    private var compactOffset: String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: timelineNow)
        let selected = cal.startOfDay(for: timelineDate)
        let days = cal.dateComponents([.day], from: today, to: selected).day ?? 0
        if days == 0 { return "" }
        if days < 0 { return "-\(abs(days))d" }
        return "+\(days)d"
    }

    // MARK: - Bottom hub: compact pill ↔ expanded card (native morph)

    /// Signals handle — top entry of the left rail. The glass effect is applied
    /// at the call site so this view is plain content.
    private var leftHandle: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.32))
                    .frame(width: 14, height: 14)
                    .scaleEffect(repository.isRefreshing ? 1.4 : 1.0)
                    .opacity(repository.isRefreshing ? 0.7 : 1.0)
                Circle().fill(Color.red).frame(width: 7, height: 7)
            }
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: repository.isRefreshing)

            Text("\(signalDots.count)")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)
                .monospacedDigit()
                .minimumScaleFactor(0.7)

            Image(systemName: "chevron.up")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(width: 48, height: 92)
        .contentShape(Rectangle())
        .onTapGesture {
            // Mutual exclusivity: opening the signals feed collapses the
            // timeline strip if it's open. See `timelineRailEntry` for the
            // mirror case.
            withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                timelineExpanded = false
                hubExpanded = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text("Open feed: \(summaryLine)"))
    }

    /// Expanded card with time-range chips + signals list. Morphs back to pill
    /// when chevron is tapped or when scrolled past the top.
    private var expandedHub: some View {
        VStack(spacing: 0) {
            // Header bar — entire bar is the collapse target. Same `.onTapGesture`
            // pattern as the left handle, which avoids gesture-recogniser
            // conflicts with the surrounding Liquid Glass.
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.green.opacity(0.30)).frame(width: 16, height: 16)
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                }
                Text("HantaAtlas — \(summaryLine)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 28, height: 28)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                    hubExpanded = false
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text("Collapse signals"))

            rangeRow
                .padding(.horizontal, 16).padding(.bottom, 8)

            Divider().background(Color.white.opacity(0.10))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(signalDots.prefix(40)) { dot in
                        // Each row pushes the full artifact view onto the
                        // map's NavigationStack — the expansion the user
                        // asked for ("each post can be expanded into an
                        // article/artifact").
                        NavigationLink {
                            SignalArtifactView(signal: dot.signal)
                        } label: {
                            SignalSheetRow(signal: dot.signal)
                        }
                        .buttonStyle(.plain)
                        Divider().background(Color.white.opacity(0.08)).padding(.leading, 16)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 480)
    }

    private var rangeRow: some View {
        HStack(spacing: 6) {
            ForEach(SignalTimeRange.allCases) { range in
                let selected = range == repository.timeRange
                Button {
                    Task { await repository.setTimeRange(range) }
                } label: {
                    Text(range.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(selected ? .black : .white.opacity(0.85))
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(selected ? Color.white.opacity(0.92) : Color.white.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Show last \(range.title)"))
            }
            Spacer(minLength: 0)
        }
    }

    /// Timeline-aware summary line. When the user scrubs to a different date,
    /// the counts reflect that point in time — countries with at-or-before-date
    /// signals, dot count, and a relative-to-timeline-date freshness label.
    private var summaryLine: String {
        let dotsNow = signalDots
        let activeCountries = Set(dotsNow.map { $0.signal.countryISO ?? "" }).filter { !$0.isEmpty }.count
        let cal = Calendar.current
        let today = cal.startOfDay(for: timelineNow)
        let selected = cal.startOfDay(for: timelineDate)
        let isFuture = selected > today
        let isToday = selected == today
        let suffix: String
        if isToday {
            suffix = updatedAgo
        } else if isFuture {
            let days = cal.dateComponents([.day], from: today, to: selected).day ?? 0
            suffix = "+\(days)d projected"
        } else {
            let days = cal.dateComponents([.day], from: selected, to: today).day ?? 0
            suffix = "\(days)d ago"
        }
        return "\(activeCountries) active · \(dotsNow.count) signals · \(suffix)"
    }

    // MARK: - Helpers

    private func handleDotsAndFillsSignatureChanged() {
        if lastRenderedDiseaseMode != preferences.selectedDiseaseMode {
            lastRenderedDiseaseMode = preferences.selectedDiseaseMode
            selectedSignalId = nil
            selectedSignalScreenPoint = nil
            Task { await refreshAfterDiseaseModeChange() }
        }
        rebuildVisibleSignalDots()
        rebuildCountryFillCache()
    }

    @MainActor
    private func refreshAfterDiseaseModeChange() async {
        await repository.refresh(preferences: preferences)
        rebuildTimelineBounds(resetToToday: true)
        rebuildDotCache()
        rebuildDailyEventCounts()
        rebuildCountryFillCache()
    }

    /// Reacts to a fresh location fix from `LocationService`. Mirrors the
    /// guards in `attemptInitialLocationCentre` — only fires the auto-
    /// centre if it hasn't already happened this session AND no user
    /// gesture has been recorded AND no v2 PersistedCamera snapshot
    /// exists. Extracted from a `.onChange` closure to keep the SwiftUI
    /// body's expression tree under the type-checker's complexity limit
    /// (the closure with multiple `guard` statements blows past it on
    /// this view's already-deep modifier chain).
    private func handleLocationServiceUpdate(_ newCoord: CLLocationCoordinate2D?) {
        guard let coord = newCoord else { return }
        if let pending = pendingLocationFocus {
            pendingLocationFocus = nil
            hasAutoCenteredOnUser = true
            showLocationFeedback(
                pending.span <= 12 ? "Centered on your location" : "Zoomed to your country",
                symbol: "location.fill",
                autoDismissAfter: 1.8
            )
            focusOn(coord, span: pending.span)
            return
        }
        guard !hasAutoCenteredOnUser else { return }
        guard !MapboxMapHostView.userHasInteractedWithMap else { return }
        guard !MapboxMapHostView.hasPersistedUserCamera else { return }
        hasAutoCenteredOnUser = true
        // Wider zoom (span 35°) — shows the user's country and its
        // neighbours in context, the same camera the right-rail
        // "globe / sphere button" uses via handleZoomToCountryTap.
        focusOn(coord, span: 35)
    }

    /// First-appearance attempt to centre the map on the user's location.
    /// Mirrors the priority spec in `.onAppear`'s comment:
    ///
    ///   - User-saved gesture-driven camera in UserDefaults? Leave alone —
    ///     MapboxMapHostView.configureMapViewIfNeeded already restored it.
    ///   - Otherwise, permission granted + fix in hand? Focus immediately.
    ///   - Otherwise (denied / restricted / no fix)? Do nothing — the
    ///     deterministic world view from worldRegion already painted.
    ///
    /// The hasAutoCenteredOnUser flag ensures this only triggers once per
    /// process; subsequent re-appearances of WorldMapView (e.g. returning
    /// from a different tab) won't re-fire the focus over a user who has
    /// since panned the map.
    private func attemptInitialLocationCentre() {
        guard !hasAutoCenteredOnUser else { return }
        guard !MapboxMapHostView.userHasInteractedWithMap else { return }
        guard !MapboxMapHostView.hasPersistedUserCamera else { return }

        switch locationService.authorization {
        case .notDetermined:
            // StartupPermissionsView owns the first automatic prompt.
            // The map only asks later after an explicit locate tap.
            break
        case .authorizedWhenInUse, .authorizedAlways:
            if let coord = locationService.current {
                hasAutoCenteredOnUser = true
                focusOn(coord, span: 35)
            } else {
                // Permission already granted but no fix yet — kick the
                // updater so didUpdateLocations fires soon. The onChange
                // observer above handles the focus when the fix arrives.
                locationService.startUpdating()
            }
        case .denied, .restricted:
            // No-op — the deterministic world view is the right fallback.
            break
        @unknown default:
            break
        }
    }

    /// Tight zoom on the user's exact GPS coordinate (~city scale).
    private func handleLocateTap() {
        runLocationCamera(span: 12)
    }

    /// Wider zoom centred on the user's location — shows the user's country in
    /// context. The "globe / sphere button" the user wanted: a camera that flies
    /// to your country.
    private func handleZoomToCountryTap() {
        runLocationCamera(span: 35)
    }

    private func runLocationCamera(span: CLLocationDegrees) {
        switch locationService.authorization {
        case .notDetermined:
            pendingLocationFocus = PendingLocationFocus(span: span)
            showLocationFeedback(
                "Allow location to center the map",
                symbol: "location.circle",
                autoDismissAfter: 2.8
            )
            showLocationPrimer = true
        case .authorizedWhenInUse, .authorizedAlways:
            if let here = locationService.current {
                pendingLocationFocus = nil
                showLocationFeedback(
                    span <= 12 ? "Centering on your location" : "Zooming to your country",
                    symbol: "location.fill",
                    autoDismissAfter: 1.6
                )
                focusOn(here, span: span)
            } else {
                let pending = PendingLocationFocus(span: span)
                pendingLocationFocus = pending
                showLocationFeedback(
                    "Finding your location...",
                    symbol: "location.fill",
                    autoDismissAfter: 5.0
                )
                locationService.requestCurrentLocation()
                scheduleLocationTimeout(for: pending)
            }
        case .denied, .restricted:
            pendingLocationFocus = nil
            showLocationFeedback(
                "Turn on Location Services in Settings",
                symbol: "location.slash",
                isWarning: true,
                autoDismissAfter: 3.2
            )
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        @unknown default:
            break
        }
    }

    private func scheduleLocationTimeout(for pending: PendingLocationFocus) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard pendingLocationFocus == pending, locationService.current == nil else { return }
            let error = locationService.lastErrorDescription
            showLocationFeedback(
                error.map { "Location unavailable: \($0)" }
                    ?? "Still waiting for a location fix",
                symbol: "exclamationmark.location.fill",
                isWarning: true,
                autoDismissAfter: 4.0
            )
        }
    }

    private func showLocationFeedback(
        _ message: String,
        symbol: String,
        isWarning: Bool = false,
        autoDismissAfter seconds: Double
    ) {
        let feedback = LocationFeedback(symbol: symbol, message: message, isWarning: isWarning)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            locationFeedback = feedback
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard locationFeedback?.id == feedback.id else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                locationFeedback = nil
            }
        }
    }

    private func focusOn(_ coordinate: CLLocationCoordinate2D, span: CLLocationDegrees) {
        // Programmatic camera move. MapboxMapHostView watches `cameraCommand`
        // and runs `setCamera(animated:)` once per fresh id. Bumping the
        // id (via UUID()) is what makes "fly to the same place again"
        // work — without it, repeat taps to the same location would no-op.
        cameraCommand = MapboxMapHostView.CameraCommand(
            coordinate: coordinate,
            distance: WorldMapView.distance(forSpanDegrees: span),
            id: UUID()
        )
    }

    // MARK: - Dot widget — show / dismiss / build

    private func handleDotTap(_ dot: SignalDot) {
        if selectedSignalId == dot.id {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                dotWidgetExpanded.toggle()
            }
        } else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                selectedSignalId = dot.id
                selectedCountryCode = dot.signal.countryISO
                dotWidgetExpanded = false
            }
            // Soft camera focus — bring the dot into view but don't zoom too tight.
            focusOn(dot.coordinate, span: 22)
        }
    }

    private func dismissDotWidget() {
        withAnimation(.easeOut(duration: 0.22)) {
            selectedSignalId = nil
            selectedCountryCode = nil
            selectedSignalScreenPoint = nil
            dotWidgetExpanded = false
        }
    }

    @ViewBuilder
    private func selectedSignalWidget(for dot: SignalDot) -> some View {
        GeometryReader { geo in
            if let screenPoint = selectedSignalScreenPoint {
                let screenSize = geo.size
                let stackSize = CGSize(width: 318, height: 224)
                let detailSize = CGSize(width: 320, height: 230)
                let stackPosition = spatialStackPosition(
                    dotScreenPoint: screenPoint,
                    screenSize: screenSize,
                    stackSize: stackSize
                )
                let detailPosition = WidgetPosition.smart(
                    dotScreenPoint: screenPoint,
                    screenSize: screenSize,
                    widgetSize: detailSize,
                    topSafeArea: 92,
                    bottomSafeArea: tabBarClearance + 118
                )

                ZStack {
                    Color.black.opacity(dotWidgetExpanded ? 0.14 : 0.08)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { dismissDotWidget() }

                    if dotWidgetExpanded {
                        SignalDotWidgetExpanded(
                            signal: dot.signal,
                            postType: dot.postType,
                            onClose: { dismissDotWidget() },
                            onReadFull: {
                                pushedArtifactSignal = dot.signal
                                dismissDotWidget()
                            },
                            onOpenSource: { UIApplication.shared.open(dot.signal.url) }
                        )
                        .glassEffect(.regular, in: .rect(cornerRadius: 22))
                        .position(detailPosition.point)
                        .transition(.scale(scale: 0.94).combined(with: .opacity))
                    } else {
                        SpatialSourceStackView(
                            items: spatialSourceItems(for: dot),
                            onClose: { dismissDotWidget() },
                            onSelect: selectSpatialSource
                        )
                        .frame(width: stackSize.width, height: stackSize.height)
                        .position(stackPosition)
                        .transition(.scale(scale: 0.86, anchor: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .transition(.opacity)
    }

    private func spatialSourceItems(for dot: SignalDot) -> [SpatialSourceItem] {
        let primary = SpatialSourceItem(id: dot.id, signal: dot.signal, postType: dot.postType, isPrimary: true)
        return [primary]
    }

    private func selectSpatialSource(_ item: SpatialSourceItem) {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            selectedSignalId = item.id
            selectedCountryCode = item.signal.countryISO
            dotWidgetExpanded = true
        }
        if let dot = signalDots.first(where: { $0.id == item.id }) {
            focusOn(dot.coordinate, span: 22)
        }
    }

    private func spatialStackPosition(
        dotScreenPoint: CGPoint,
        screenSize: CGSize,
        stackSize: CGSize
    ) -> CGPoint {
        let anchorInsetFromBottom: CGFloat = 28
        let desiredY = dotScreenPoint.y - (stackSize.height / 2 - anchorInsetFromBottom)
        let minY = stackSize.height / 2 + 76
        let maxY = screenSize.height - stackSize.height / 2 - tabBarClearance - 14
        let clampedY = max(minY, min(maxY, desiredY))

        let halfWidth = stackSize.width / 2
        let clampedX = max(halfWidth + 12, min(screenSize.width - halfWidth - 12, dotScreenPoint.x))
        return CGPoint(x: clampedX, y: clampedY)
    }

    private var updatedAgo: String {
        guard let updated = repository.stats?.updatedAt else { return "—" }
        let mins = max(0, Int(Date().timeIntervalSince(updated) / 60))
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        return "\(mins / 60)h ago"
    }

    private func routeColor(_ route: OutbreakRoute) -> Color {
        switch route.color {
        case .terracotta: return Theme.terracotta
        case .amber:      return Theme.amber
        case .moss:       return Theme.moss
        }
    }
}

// MARK: - Signal dot model + jitter

struct SignalDot: Identifiable {
    let signal: Signal
    let postType: MapPostType
    let coordinate: CLLocationCoordinate2D
    /// Effective date this dot represents on the map timeline. For projected
    /// (future) signals this is `signal.projectedDate`; for normal signals it
    /// equals `signal.publishedAt`.
    let effectiveDate: Date
    /// True when this dot is a projected future event (EXPERT_VOICE forecast).
    /// Renders with reduced opacity + dashed outer ring so the user can tell
    /// it's a prediction, not a fact.
    let isProjected: Bool

    var id: String { isProjected ? "proj-\(signal.id)" : signal.id }

    static func jitter(around centroid: CLLocationCoordinate2D, seed: String) -> CLLocationCoordinate2D {
        let hash = abs(seed.hashValue)
        let angle = Double(hash % 360) * .pi / 180.0
        let radiusKm = Double((hash / 360) % 80) + 5
        let dLat = (radiusKm / 111.0) * cos(angle)
        let dLon = (radiusKm / (111.0 * cos(centroid.latitude * .pi / 180.0))) * sin(angle)
        return CLLocationCoordinate2D(
            latitude: centroid.latitude + dLat,
            longitude: centroid.longitude + dLon
        )
    }
}

// MARK: - Polygon overlay model

struct CountryFillPolygon: Identifiable {
    let iso: String
    let ringIndex: Int
    let level: CountryActiveLevel
    let ring: [CLLocationCoordinate2D]

    var id: String { "\(iso)#\(ringIndex)" }
}

// MARK: - Individual signal dot

struct SignalIndividualDot: View {
    let postType: MapPostType
    let severity: AlertSeverity
    let isSelected: Bool
    let isProjected: Bool

    private var tint: Color { postType.mapColor }

    /// Diameter encodes severity. DEATH dots are bumped up a tier — they
    /// carry more weight visually so the user finds fatalities first.
    private var diameter: CGFloat {
        let bump: CGFloat = (postType == .death) ? 4 : 0
        switch severity {
        case .high:   return 14 + bump
        case .medium: return 11 + bump
        case .low:    return 9  + bump
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(isProjected ? 0.10 : 0.22))
                .frame(width: diameter * 1.9, height: diameter * 1.9)
            if isSelected {
                Circle()
                    .stroke(tint.opacity(0.7), lineWidth: 1.4)
                    .frame(width: diameter * 1.8, height: diameter * 1.8)
            }
            // Projected dots: dashed outer ring + lower-opacity fill so they
            // read as "predicted, not factual".
            if isProjected {
                Circle()
                    .strokeBorder(tint, style: StrokeStyle(lineWidth: 1.4, dash: [3, 2]))
                    .frame(width: diameter * 1.4, height: diameter * 1.4)
                Circle()
                    .fill(tint.opacity(0.55))
                    .frame(width: diameter, height: diameter)
                    .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
            } else {
                Circle()
                    .fill(tint)
                    .frame(width: diameter, height: diameter)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 1.2))
                    .shadow(color: isSelected ? tint.opacity(0.6) : .clear, radius: isSelected ? 4 : 0, y: 0)
            }
            // Death dots get a white × glyph inside so they're unmistakable
            // even when zoomed out and clustered.
            if postType == .death && !isProjected {
                Image(systemName: "xmark")
                    .font(.system(size: diameter * 0.45, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .opacity(isProjected ? 0.85 : 1.0)
        .accessibilityHidden(true)
    }
}

// MARK: - Outbreak route subviews

private struct WaypointDot: View {
    let kind: OutbreakRoute.Waypoint.Kind
    let tint: Color

    /// Dropped the blur for perf — same reason as SignalIndividualDot.
    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.18)).frame(width: 14, height: 14)
            Circle()
                .strokeBorder(tint.opacity(0.95), lineWidth: 1.5)
                .background(Circle().fill(.black.opacity(0.55)))
                .frame(width: kind == .quarantinePort ? 11 : 7, height: kind == .quarantinePort ? 11 : 7)
        }
        .accessibilityHidden(true)
    }
}

private struct ShipGlyph: View {
    let tint: Color
    let pulsing: Bool
    @State private var pulse: CGFloat = 1.0

    /// Dropped the per-frame blur. The pulse animation is throttled to a longer
    /// period and uses scaleEffect on the outer ring only.
    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.22))
                .frame(width: 30, height: 30)
                .scaleEffect(pulse)
            Circle()
                .fill(tint)
                .frame(width: 22, height: 22)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .shadow(color: tint.opacity(0.55), radius: 3, y: 0)
            Image(systemName: "ferry.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
        }
        .onAppear {
            guard pulsing else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                pulse = 1.3
            }
        }
        .accessibilityLabel(Text("Ship at sea"))
    }
}

// MARK: - Signal row inside the expanded hub

/// Compact signal row used inside the expanded hub. The whole row is the
/// label of a `NavigationLink` (wrapping happens in `WorldMapView`), so the
/// row itself is just the visual layout — no Button.
private struct SignalSheetRow: View {
    let signal: Signal

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(severityTint)
                .frame(width: 9, height: 9)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(signal.sourceBucket)
                        .font(.caption2.weight(.heavy))
                        .tracking(0.4)
                        .foregroundStyle(.white.opacity(0.55))
                    Text("·").foregroundStyle(.white.opacity(0.30))
                    Text(timeAgo(signal.publishedAt))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                    if let iso = signal.countryISO {
                        Text(iso)
                            .font(.caption2.weight(.heavy))
                            .padding(.horizontal, 6).padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.10), in: Capsule())
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer(minLength: 0)
                    if signal.isInForeignLanguage, let lang = signal.detectedLanguage {
                        Text("\(lang.uppercased()) → EN")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.4)
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.35))
                }
                // Title is auto-translated to English on-device when the source
                // language differs. Falls back to the original silently if the
                // pair isn't downloaded yet.
                TranslatedSignalText(
                    signal.title,
                    sourceLanguage: signal.detectedLanguage,
                    font: .callout.weight(.semibold),
                    lineLimit: 2
                )
                .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var severityTint: Color {
        switch signal.severity {
        case .high: return Theme.terracotta
        case .medium: return Theme.amber
        case .low: return Theme.olive
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let mins = max(0, Int(Date().timeIntervalSince(date) / 60))
        if mins < 1 { return "now" }
        if mins < 60 { return "\(mins)m ago" }
        if mins < 60 * 24 { return "\(mins / 60)h ago" }
        return "\(mins / 1440)d ago"
    }
}

// MARK: - Layers sheet (native iOS 26 Liquid Glass)

private struct LayersSheet: View {
    @Binding var visiblePostTypes: Set<MapPostType>
    @Binding var showCountryFill: Bool
    @Binding var showOutbreakRoutes: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.graphite.opacity(0.94)
                    .ignoresSafeArea()
                ScrollView {
                    GlassEffectContainer(spacing: 16) {
                        VStack(spacing: 16) {
                            ForEach(MapPostType.Group.allCases) { group in
                                groupPanel(group)
                            }
                            overlaysPanel
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                        .padding(.bottom, 30)
                    }
                }
            }
            .environment(\.colorScheme, .dark)
            .navigationTitle("Map layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .buttonStyle(.glassProminent)
                }
            }
        }
    }

    private func groupPanel(_ group: MapPostType.Group) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: group.title, subtitle: group.blurb, tint: tint(for: group))
            masterToggleRow(group)
            layerDivider
            ForEach(MapPostType.allCases.filter { $0.group == group }) { type in
                layerToggleRow(type)
            }
            if group == .discourse {
                Text("Dot size scales with severity. The white inner ring marks death dots.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(15)
        .glassEffect(.regular.tint(tint(for: group).opacity(0.18)), in: .rect(cornerRadius: 28))
    }

    private var overlaysPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Overlays", subtitle: "Country context and routes", tint: Theme.amber)
            overlayToggle(
                title: "Country fill",
                subtitle: "Endemic and active countries",
                systemName: "map.fill",
                tint: Theme.olive,
                isOn: $showCountryFill
            )
            layerDivider
            overlayToggle(
                title: "Outbreak routes",
                subtitle: "Cruise and ground movement",
                systemName: "point.topleft.down.curvedto.point.bottomright.up",
                tint: Theme.terracotta,
                isOn: $showOutbreakRoutes
            )
        }
        .padding(15)
        .glassEffect(.regular.tint(Theme.amber.opacity(0.16)), in: .rect(cornerRadius: 28))
    }

    private func sectionHeader(title: String, subtitle: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.56))
            }
        }
    }

    private func masterToggleRow(_ group: MapPostType.Group) -> some View {
        Toggle(isOn: groupMasterBinding(group)) {
            HStack(spacing: 11) {
                Image(systemName: groupMasterAllOn(group) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(groupMasterAllOn(group) ? tint(for: group) : .white.opacity(0.55))
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group == .groundTruth ? "All ground-truth dots" : "All discourse dots")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(group.blurb)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .tint(tint(for: group))
    }

    private func layerToggleRow(_ type: MapPostType) -> some View {
        Toggle(isOn: bindingFor(type)) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(type.mapColor)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 1))
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(type.blurb)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(type.mapColor)
    }

    private func overlayToggle(
        title: String,
        subtitle: String,
        systemName: String,
        tint: Color,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .tint(tint)
    }

    private var layerDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.12))
            .frame(height: 0.5)
    }

    private func tint(for group: MapPostType.Group) -> Color {
        group == .groundTruth ? Theme.terracotta : Theme.moss
    }

    private func bindingFor(_ type: MapPostType) -> Binding<Bool> {
        Binding(
            get: { visiblePostTypes.contains(type) },
            set: { on in
                if on { visiblePostTypes.insert(type) } else { visiblePostTypes.remove(type) }
            }
        )
    }

    private func groupMasterBinding(_ group: MapPostType.Group) -> Binding<Bool> {
        Binding(
            get: { groupMasterAllOn(group) },
            set: { on in
                let typesInGroup = MapPostType.allCases.filter { $0.group == group }
                if on {
                    visiblePostTypes.formUnion(typesInGroup)
                } else {
                    typesInGroup.forEach { visiblePostTypes.remove($0) }
                }
            }
        )
    }

    private func groupMasterAllOn(_ group: MapPostType.Group) -> Bool {
        let typesInGroup = MapPostType.allCases.filter { $0.group == group }
        return typesInGroup.allSatisfy { visiblePostTypes.contains($0) }
    }
}

// MARK: - Location priming sheet

private struct LocationPrimerSheet: View {
    let onAllow: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "location.viewfinder")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.terracotta)
                .padding(.top, 24)

            Text("See signals near you")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.graphite)
                .multilineTextAlignment(.center)

            Text("HantaAtlas will use your location to centre the map on your country and tell you whether there are recent signals nearby. Your location stays on your device — it is never sent to our servers.")
                .font(.callout)
                .foregroundStyle(Theme.graphiteSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 8) {
                Label("On-device only", systemImage: "iphone")
                Label("Never sent to our servers", systemImage: "lock.shield")
                Label("Not for emergency use", systemImage: "exclamationmark.triangle")
            }
            .font(.footnote)
            .foregroundStyle(Theme.graphiteSecondary)
            .padding(.horizontal, 36)

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Button(action: onAllow) {
                    Text("Allow location access")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Theme.terracotta, in: RoundedRectangle(cornerRadius: 14))
                }
                Button(action: onDecline) {
                    Text("Not now")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.graphiteSecondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper.ignoresSafeArea())
    }
}

#Preview("Map — dark") {
    NavigationStack {
        WorldMapView(
            repository: SurveillanceRepository(),
            preferences: LocalPreferences()
        )
    }
    .preferredColorScheme(.dark)
}
