import SwiftUI
import UIKit
import CoreLocation
import MapboxMaps

private struct SignalAnnotationKey: Equatable {
    let id: String
    let postType: MapPostType
    let latitudeE6: Int
    let longitudeE6: Int
    let isProjected: Bool

    init(_ dot: SignalDot) {
        self.id = dot.id
        self.postType = dot.postType
        self.latitudeE6 = Int((dot.coordinate.latitude * 1_000_000).rounded())
        self.longitudeE6 = Int((dot.coordinate.longitude * 1_000_000).rounded())
        self.isProjected = dot.isProjected
    }
}

private struct CountryFillAnnotationKey: Equatable {
    let id: String
    let level: CountryActiveLevel
    let vertexCount: Int

    init(_ fill: CountryFillPolygon) {
        self.id = fill.id
        self.level = fill.level
        self.vertexCount = fill.ring.count
    }
}

private struct RouteAnnotationKey: Equatable {
    let id: String
    let color: OutbreakRoute.ColorToken
    let vertexCount: Int

    init(_ route: OutbreakRoute) {
        self.id = route.id
        self.color = route.color
        self.vertexCount = route.polyline.count
    }
}

/// Mapbox port of the map host view. Same constructor signature as
/// `MKMapHostView` so the call site in `WorldMapView` is a drop-in swap.
///
/// **Architecture parity with the MapKit host it replaces**:
///
///   - `SharedMapboxStore` keeps one `MapView` alive across SwiftUI
///     rebuilds, the same way `SharedMKMapStore` did. The map view is
///     created once at first access; subsequent body re-evaluations
///     reuse the same instance, so tab switches and view rebuilds
///     never reset the camera mid-session.
///
///   - `PersistedMapboxCamera` stores the user's last gesture-driven
///     camera in UserDefaults under a Mapbox-specific key
///     (`hantaatlas.mapbox.persistedCamera.v1`). Only user-driven
///     settles are persisted — programmatic moves never touch the
///     snapshot — so drilling into a signal dot doesn't lock the
///     next cold launch to that destination.
///
///   - `CameraCommand` is a UUID-gated struct identical in shape to
///     the MapKit version, so callers writing `cameraCommand = ...`
///     don't need to change.
///
///   - Annotation diff happens through Mapbox's
///     `PointAnnotationManager` / `PolygonAnnotationManager` /
///     `PolylineAnnotationManager`. Each manager owns an
///     `annotations: [Annotation]` array we replace wholesale on
///     update; Mapbox handles the diff internally.
///
/// **Differences from the MapKit host**:
///
///   - Camera state uses Mapbox's `CameraOptions(center:zoom:bearing:pitch:)`
///     instead of `MKMapCamera(lookingAtCenter:fromDistance:pitch:heading:)`.
///     Mapbox zoom is logarithmic (zoom 0 ≈ world, zoom 22 ≈ street). The
///     `MKMapHostView`-style `distance` parameter is converted at the
///     boundary via `zoomLevel(forDistance:)`.
///
///   - Style is `.dark` (Mapbox's built-in dark style). Equivalent of the
///     `MKStandardMapConfiguration(elevationStyle: .realistic,
///     emphasisStyle: .muted)` we used in MapKit.
///
///   - User-location puck is `.puck2D()` configured via
///     `mapView.location.options`. Equivalent of `mapView.showsUserLocation
///     = true`.
///
///   - "Settled gesture" detection is `mapboxMap.onMapIdle.observe { ... }`.
///     Equivalent of MapKit's `mapView(_:regionDidChangeAnimated:)`.
@MainActor
private final class SharedMapboxStore {
    static let shared = SharedMapboxStore()

    let mapView: MapView
    var hasConfiguredMap = false
    var lastCameraCommandID: UUID?
    var pointAnnotationManager: PointAnnotationManager?
    var fillAnnotationManager: PolygonAnnotationManager?
    var lineAnnotationManager: PolylineAnnotationManager?
    var selectedSignalCoordinate: CLLocationCoordinate2D?
    var selectedSignalProjectionHandler: ((CGPoint?) -> Void)?
    private var lastProjectedSignalPoint: CGPoint?
    private var lastProjectionEmission: TimeInterval = 0
    var lastSignalAnnotationKeys: [SignalAnnotationKey] = []
    var lastCountryFillAnnotationKeys: [CountryFillAnnotationKey] = []
    var lastRouteAnnotationKeys: [RouteAnnotationKey] = []

    /// Flips true the first time the user moves the camera with a gesture.
    /// Resets only on full app relaunch (it's a session flag, not persisted).
    var userHasInteractedWithMap = false

    /// Set true while a programmatic camera move is in flight. The map-idle
    /// observer uses this to distinguish gesture-driven settles (persist)
    /// from programmatic moves (don't persist). Same pattern as the MapKit
    /// host's `isApplyingProgrammaticCamera`.
    var isApplyingProgrammaticCamera = false

    /// Strong reference to the observable cancelables Mapbox returns from
    /// `onMapIdle.observe { }` / `onCameraChanged.observe { }`. Without
    /// holding them the observers are deallocated immediately and the
    /// callbacks never fire.
    var observers: [AnyCancelable] = []

    private init() {
        // Configure the public token before the first MapView exists.
        // The generated Info.plist path can omit custom keys on some Xcode
        // builds, so keep a bundled MapboxAccessToken file as the durable
        // fallback Mapbox v11 also supports.
        MapboxOptions.accessToken = Self.resolveAccessToken()
        //
        // Non-zero starting frame so the first render pass doesn't hit
        // Mapbox's zero-size warning path.
        self.mapView = MapView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    func updateSelectedSignalProjection(
        coordinate: CLLocationCoordinate2D?,
        handler: @escaping (CGPoint?) -> Void,
        mapView: MapView
    ) {
        selectedSignalCoordinate = coordinate
        selectedSignalProjectionHandler = handler
        emitSelectedSignalProjection(from: mapView, force: true)
    }

    func emitSelectedSignalProjection(from mapView: MapView, force: Bool = false) {
        guard let coordinate = selectedSignalCoordinate else {
            if force || lastProjectedSignalPoint != nil {
                lastProjectedSignalPoint = nil
                selectedSignalProjectionHandler?(nil)
            }
            return
        }

        let now = Date.timeIntervalSinceReferenceDate
        if !force && now - lastProjectionEmission < 1.0 / 30.0 {
            return
        }

        let point = mapView.mapboxMap.point(for: coordinate)
        guard point.x.isFinite, point.y.isFinite else {
            if force || lastProjectedSignalPoint != nil {
                lastProjectedSignalPoint = nil
                selectedSignalProjectionHandler?(nil)
            }
            return
        }

        if !force, let last = lastProjectedSignalPoint {
            let dx = point.x - last.x
            let dy = point.y - last.y
            guard hypot(dx, dy) > 0.75 else { return }
        }

        lastProjectedSignalPoint = point
        lastProjectionEmission = now
        selectedSignalProjectionHandler?(point)
    }

    private static func resolveAccessToken() -> String {
        if let plistToken = Bundle.main.object(forInfoDictionaryKey: "MBXAccessToken") as? String,
           !plistToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return plistToken
        }

        if let url = Bundle.main.url(forResource: "MapboxAccessToken", withExtension: nil),
           let fileToken = try? String(contentsOf: url, encoding: .utf8) {
            let trimmed = fileToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        assertionFailure("Missing Mapbox access token. Add MBXAccessToken to Info.plist or bundle Resources/MapboxAccessToken.")
        return ""
    }
}

/// Camera snapshot persisted to UserDefaults across cold launches. Stores
/// Mapbox-shaped fields (center lat/lon, zoom, bearing, pitch) — the v1
/// MapKit snapshots from `PersistedCamera` are invalidated by being under
/// a different storage key, so no migration is needed.
private struct PersistedMapboxCamera: Codable {
    let latitude: Double
    let longitude: Double
    let zoom: Double
    let bearing: Double
    let pitch: Double
    let savedAt: Double

    /// UserDefaults key. Mapbox-specific so it doesn't collide with the
    /// MapKit `hantaatlas.map.persistedCamera.v2` snapshots that some
    /// users might still have from the previous engine.
    static let storageKey = "hantaatlas.mapbox.persistedCamera.v1"
    /// Discard saves older than 30 days. Same rationale as the MapKit
    /// host: short enough that a long-absent user gets a fresh default,
    /// long enough that a couple-of-weeks gap feels continuous.
    static let staleThreshold: TimeInterval = 60 * 60 * 24 * 30

    @MainActor
    static func load() -> PersistedMapboxCamera? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(PersistedMapboxCamera.self, from: data)
        else { return nil }
        let age = Date().timeIntervalSince1970 - decoded.savedAt
        guard age < staleThreshold else { return nil }
        return decoded
    }

    @MainActor
    static func save(from state: CameraState) {
        let snapshot = PersistedMapboxCamera(
            latitude:  state.center.latitude,
            longitude: state.center.longitude,
            zoom:      state.zoom,
            bearing:   state.bearing,
            pitch:     state.pitch,
            savedAt:   Date().timeIntervalSince1970
        )
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }

    func toCameraOptions() -> CameraOptions {
        CameraOptions(
            center:  CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            zoom:    zoom,
            bearing: bearing,
            pitch:   pitch
        )
    }
}

@MainActor
struct MapboxMapHostView: UIViewRepresentable {
    let signalDots: [SignalDot]
    let countryFillPolygons: [CountryFillPolygon]
    let outbreakRoutes: [OutbreakRoute]
    let showsUserLocation: Bool
    let selectedSignalId: String?
    @Binding var cameraCommand: CameraCommand?
    let initialCenter: CLLocationCoordinate2D
    let initialDistance: CLLocationDistance
    let onSignalTap: (SignalDot) -> Void
    let onSelectedSignalScreenPointChange: (CGPoint?) -> Void

    /// Programmatic camera move request. Same shape as the legacy
    /// `MKMapHostView.CameraCommand`, so call sites in WorldMapView
    /// don't need to change beyond renaming the type.
    struct CameraCommand: Equatable {
        let coordinate: CLLocationCoordinate2D
        let distance: CLLocationDistance
        let id: UUID

        static func == (lhs: CameraCommand, rhs: CameraCommand) -> Bool {
            lhs.id == rhs.id
        }
    }

    // MARK: - Camera-state queries for the SwiftUI host

    /// True if the user has moved the camera with a gesture in this session.
    static var userHasInteractedWithMap: Bool {
        SharedMapboxStore.shared.userHasInteractedWithMap
    }

    /// True if there's a non-stale persisted Mapbox camera snapshot in
    /// UserDefaults from a previous session's user gesture.
    static var hasPersistedUserCamera: Bool {
        PersistedMapboxCamera.load() != nil
    }

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MapView {
        let mapView = SharedMapboxStore.shared.mapView
        configureMapViewIfNeeded(mapView, coordinator: context.coordinator)
        return mapView
    }

    func updateUIView(_ uiView: MapView, context: Context) {
        applyCameraCommand(cameraCommand, on: uiView)
        syncSignalAnnotations(signalDots, on: uiView)
        syncCountryFillOverlays(countryFillPolygons, on: uiView)
        syncOutbreakRoutes(outbreakRoutes, on: uiView)
        syncUserLocationPuck(uiView)
        syncSelectedSignalProjection(uiView)
    }

    static func dismantleUIView(_ uiView: MapView, coordinator: Coordinator) {
        // Keep the shared MapView alive — the singleton outlives any one
        // SwiftUI mount. Just drop the observers so the coordinator can
        // be deallocated cleanly.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Configuration

    private func configureMapViewIfNeeded(_ mapView: MapView, coordinator: Coordinator) {
        let store = SharedMapboxStore.shared
        guard !store.hasConfiguredMap else { return }
        store.hasConfiguredMap = true

        // Dark editorial style — same visual register as the previous
        // MapKit `.muted` emphasis with `.realistic` elevation.
        mapView.mapboxMap.styleURI = .dark
        try? mapView.mapboxMap.setProjection(StyleProjection(name: .globe))

        // Set the initial camera. First-launch camera priority:
        //   1. Restore the last persisted user-gesture camera if it exists
        //      and is fresh (< 30 days).
        //   2. Otherwise apply `initialCenter` / `initialDistance` (the host
        //      computes those — typically a deterministic world view at
        //      (15°N, 0°E) or a fit on tracked countries).
        let initialOptions: CameraOptions
        if let persisted = PersistedMapboxCamera.load() {
            initialOptions = persisted.toCameraOptions()
        } else {
            initialOptions = CameraOptions(
                center: initialCenter,
                zoom:   Self.zoomLevel(forDistance: initialDistance),
                bearing: 0,
                pitch:   0
            )
        }
        mapView.mapboxMap.setCamera(to: initialOptions)

        // Make every gesture available — Mapbox's defaults are correct
        // (pan/zoom/rotate/pitch all on); this is defensive in case a
        // future SDK ships with a different default.
        mapView.gestures.options.panEnabled = true
        mapView.gestures.options.pinchEnabled = true
        mapView.gestures.options.pinchZoomEnabled = true
        mapView.gestures.options.rotateEnabled = true
        mapView.gestures.options.pitchEnabled = true
        mapView.gestures.options.doubleTapToZoomInEnabled = true
        mapView.gestures.options.doubleTouchToZoomOutEnabled = true

        // Ornaments off — we render our own Liquid Glass chrome on top.
        mapView.ornaments.options.scaleBar.visibility = .hidden
        mapView.ornaments.options.compass.visibility = .hidden
        mapView.ornaments.options.attributionButton.position = .bottomLeft
        mapView.ornaments.options.logo.position = .bottomLeft

        // Create the annotation managers. Each has a unique id so they
        // don't collide and so updates target the right manager.
        store.pointAnnotationManager = mapView.annotations.makePointAnnotationManager(id: "hantaatlas.signals")
        store.fillAnnotationManager  = mapView.annotations.makePolygonAnnotationManager(id: "hantaatlas.country-fills")
        store.lineAnnotationManager  = mapView.annotations.makePolylineAnnotationManager(id: "hantaatlas.outbreak-routes")

        // Apple Maps-style space framing: stars belong to Mapbox's globe
        // atmosphere, not to a SwiftUI overlay. That keeps them tied to the
        // camera/projection as the user rotates, pitches, or spins the globe.
        let atmosphereCancelable = mapView.mapboxMap.onStyleLoaded.observeNext { [weak mapView] _ in
            guard let mapView else { return }
            var atmosphere = Atmosphere()
            atmosphere.starIntensity = .constant(0.82)
            try? mapView.mapboxMap.setAtmosphere(atmosphere)
        }
        store.observers.append(atmosphereCancelable)

        // Tap handling lives on each individual PointAnnotation in v11
        // (the per-annotation `tapHandler` closure on PointAnnotation),
        // wired inside `syncSignalAnnotations` below. The manager itself
        // doesn't expose a top-level `tapHandler` property in v11+.

        // Map-idle observer (Mapbox's equivalent of MapKit's
        // regionDidChangeAnimated). Persists the camera only when the
        // change is user-driven, never when programmatic.
        let idleCancelable = mapView.mapboxMap.onMapIdle.observe { [weak mapView] _ in
            guard let mapView else { return }
            let wasProgrammatic = store.isApplyingProgrammaticCamera
            store.isApplyingProgrammaticCamera = false
            guard !wasProgrammatic else { return }
            store.userHasInteractedWithMap = true
            PersistedMapboxCamera.save(from: mapView.mapboxMap.cameraState)
        }
        store.observers.append(idleCancelable)

        let cameraCancelable = mapView.mapboxMap.onCameraChanged.observe { [weak mapView] _ in
            guard let mapView else { return }
            Task { @MainActor in
                store.emitSelectedSignalProjection(from: mapView)
            }
        }
        store.observers.append(cameraCancelable)
    }

    /// Apply or refresh the user-location puck. Toggled by the
    /// `showsUserLocation` prop on every update so granting permission
    /// in a settings sheet immediately surfaces the dot without
    /// re-mounting the map.
    private func syncUserLocationPuck(_ mapView: MapView) {
        if showsUserLocation {
            mapView.location.options.puckType = .puck2D()
        } else {
            mapView.location.options.puckType = nil
        }
    }

    private func syncSelectedSignalProjection(_ mapView: MapView) {
        let coordinate = signalDots.first(where: { $0.id == selectedSignalId })?.coordinate
        SharedMapboxStore.shared.updateSelectedSignalProjection(
            coordinate: coordinate,
            handler: onSelectedSignalScreenPointChange,
            mapView: mapView
        )
    }

    // MARK: - Programmatic camera

    private func applyCameraCommand(_ command: CameraCommand?, on mapView: MapView) {
        guard let command else { return }
        let store = SharedMapboxStore.shared
        guard command.id != store.lastCameraCommandID else { return }
        store.lastCameraCommandID = command.id

        let target = CameraOptions(
            center:  command.coordinate,
            zoom:    Self.zoomLevel(forDistance: command.distance),
            bearing: mapView.mapboxMap.cameraState.bearing,
            pitch:   mapView.mapboxMap.cameraState.pitch
        )
        store.isApplyingProgrammaticCamera = true
        mapView.camera.ease(to: target, duration: 0.6)

        // Clear the binding so a repeat tap on the same coordinate
        // still works — the next focusOn() generates a fresh UUID and
        // the equality gate above lets it through.
        Task { @MainActor in
            self.cameraCommand = nil
        }
    }

    /// Convert a "distance from camera to center" in metres (the units
    /// MapKit's `MKMapCamera.centerCoordinateDistance` uses) into a
    /// Mapbox zoom level (logarithmic, 0 = whole world, 22 = street).
    ///
    /// Approximation: at zoom z, one pixel maps to roughly
    /// `40 075 017 / (256 * 2^z)` metres at the equator. We pick a zoom
    /// that produces a similar visible span for the given camera
    /// distance on an iPhone-sized viewport. The constants are tuned to
    /// match the existing call sites' "feel" — a 22° span gives roughly
    /// the same framing as it did in MapKit.
    static func zoomLevel(forDistance distance: CLLocationDistance) -> Double {
        let earthCircumference = 40_075_017.0
        // Higher distance → lower zoom. Clamp to Mapbox's valid range.
        let raw = log2(earthCircumference / max(distance, 1))
        return max(0, min(22, raw))
    }

    // MARK: - Annotation diff (signal dots)

    private func syncSignalAnnotations(_ dots: [SignalDot], on mapView: MapView) {
        let store = SharedMapboxStore.shared
        guard let manager = store.pointAnnotationManager else { return }
        let keys = dots.map(SignalAnnotationKey.init)
        guard keys != store.lastSignalAnnotationKeys else { return }
        store.lastSignalAnnotationKeys = keys

        // Capture the host's tap callback so the per-annotation closures
        // don't have to retain the SwiftUI view itself.
        let tapCallback = self.onSignalTap
        manager.annotations = dots.map { dot in
            var annotation = PointAnnotation(
                id: dot.id,
                coordinate: dot.coordinate
            )
            annotation.image = .init(
                image: Self.signalDotImage(for: dot.postType),
                name: "signal-dot-\(dot.postType.rawValue)"
            )
            annotation.iconAnchor = .center
            annotation.iconSize = dot.isProjected ? 0.85 : 1.0
            annotation.iconOpacity = dot.isProjected ? 0.7 : 1.0
            annotation.tapHandler = { _ in
                tapCallback(dot)
                return true
            }
            return annotation
        }
    }

    /// Cache of pre-rendered dot images keyed by post type. Each is a
    /// small UIImage drawn once and reused for every annotation of that
    /// type — Mapbox internally references the same image asset by name
    /// so this scales to thousands of annotations without per-pin cost.
    nonisolated(unsafe) private static var dotImageCache: [String: UIImage] = [:]

    static func signalDotImage(for postType: MapPostType) -> UIImage {
        if let cached = dotImageCache[postType.rawValue] { return cached }
        let size = CGSize(width: 22, height: 22)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let context = ctx.cgContext
            let tint = UIColor(postType.mapColor)

            // Halo
            context.setFillColor(tint.withAlphaComponent(0.22).cgColor)
            context.fillEllipse(in: CGRect(x: 0, y: 0, width: 22, height: 22))

            // Solid core
            context.setFillColor(tint.cgColor)
            context.fillEllipse(in: CGRect(x: 6, y: 6, width: 10, height: 10))

            // White rim for legibility on the dark style
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.85).cgColor)
            context.setLineWidth(1.0)
            context.strokeEllipse(in: CGRect(x: 6, y: 6, width: 10, height: 10))
        }
        dotImageCache[postType.rawValue] = img
        return img
    }

    // MARK: - Overlay diff (country fills)

    private func syncCountryFillOverlays(_ fills: [CountryFillPolygon], on mapView: MapView) {
        let store = SharedMapboxStore.shared
        guard let manager = store.fillAnnotationManager else { return }
        let keys = fills.map(CountryFillAnnotationKey.init)
        guard keys != store.lastCountryFillAnnotationKeys else { return }
        store.lastCountryFillAnnotationKeys = keys

        manager.annotations = fills.compactMap { fill in
            guard fill.ring.count >= 3 else { return nil }
            let polygon = Polygon([fill.ring])
            var annotation = PolygonAnnotation(id: fill.id, polygon: polygon)
            if let swiftUIColor = fill.level.mapFill {
                annotation.fillColor = StyleColor(UIColor(swiftUIColor))
            }
            annotation.fillOpacity = 0.45
            if let strokeColor = fill.level.mapStroke {
                annotation.fillOutlineColor = StyleColor(UIColor(strokeColor))
            }
            return annotation
        }
    }

    // MARK: - Overlay diff (outbreak routes)

    private func syncOutbreakRoutes(_ routes: [OutbreakRoute], on mapView: MapView) {
        let store = SharedMapboxStore.shared
        guard let manager = store.lineAnnotationManager else { return }
        let keys = routes.map(RouteAnnotationKey.init)
        guard keys != store.lastRouteAnnotationKeys else { return }
        store.lastRouteAnnotationKeys = keys

        // Dash pattern lives on the AnnotationManager in v11, not per
        // annotation — Mapbox compiles it into the layer style once and
        // applies to every line the manager renders.
        manager.lineDasharray = [2, 1.5]
        var built: [PolylineAnnotation] = []
        built.reserveCapacity(routes.count)
        for route in routes {
            guard route.polyline.count >= 2 else { continue }
            let lineString = LineString(route.polyline)
            var annotation = PolylineAnnotation(id: route.id, lineString: lineString)
            annotation.lineColor = StyleColor(UIColor(Self.uiColor(for: route.color)).withAlphaComponent(0.78))
            annotation.lineWidth = 4
            built.append(annotation)
        }
        manager.annotations = built
    }

    /// Maps the design-token route colour to the Theme palette. Three
    /// variants today; new tokens should land both here and in the legend.
    static func uiColor(for token: OutbreakRoute.ColorToken) -> Color {
        switch token {
        case .terracotta: Theme.terracotta
        case .amber:      Theme.amber
        case .moss:       Theme.moss
        }
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator {
        var parent: MapboxMapHostView
        /// Map of annotation id → SignalDot, populated on every sync so
        /// the tap handler can look up the source dot in O(1). Rebuilt
        /// on each sync (cheap).
        private var dotsById: [String: SignalDot] = [:]

        init(parent: MapboxMapHostView) {
            self.parent = parent
        }

        /// Called from `PointAnnotationManager.tapHandler`. Maps the
        /// Mapbox annotation id back to the SignalDot the host knows
        /// about, then forwards to the host's `onSignalTap` callback.
        func handleAnnotationTap(annotationId: String) {
            if let dot = parent.signalDots.first(where: { $0.id == annotationId }) {
                parent.onSignalTap(dot)
            }
        }
    }
}
