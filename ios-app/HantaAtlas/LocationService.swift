import Foundation
import CoreLocation
import Observation

/// Lightweight wrapper around CLLocationManager that exposes authorization
/// status + last-known coordinate as observable properties. The wrapper is
/// `@Observable` so SwiftUI views update automatically.
///
/// Usage:
///   - On first launch, the startup permission flow calls `requestWhenInUse()`.
///   - The map view reads `current` to render the user dot.
///   - We never request `Always` — App Store rules require background location
///     to be tied to a stated user-visible feature, which we don't have.
@MainActor
@Observable
final class LocationService: NSObject {
    static let shared = LocationService()

    private let manager = CLLocationManager()

    /// Current authorization. Defaults to whatever CLLocationManager reports.
    private(set) var authorization: CLAuthorizationStatus = .notDetermined

    /// Last-known device coordinate. `nil` until the user grants access AND
    /// CoreLocation produces its first fix.
    private(set) var current: CLLocationCoordinate2D? = nil

    /// Last location failure, surfaced by callers that need user-visible
    /// feedback for an explicit location action.
    private(set) var lastErrorDescription: String? = nil

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer  // we only need country-level
        authorization = manager.authorizationStatus

        // If the user already authorised in a prior session, the delegate's
        // didChangeAuthorization callback won't fire on launch — we have to
        // start updating manually so the user-location dot appears immediately.
        // (Bug: the dot "barely appeared" because we waited for an
        // authorization-change event that never came.)
        //
        // Perf: per Apple's "Reducing your app's launch time" doc, location
        // services should not be initialised "on app launch" but "on first
        // use." We can't fully obey that without rewriting the call sites,
        // but we can at least move startUpdatingLocation off the init's
        // synchronous main-thread path so CL warmup doesn't block first frame.
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            Task { @MainActor [weak self] in
                self?.manager.startUpdatingLocation()
            }
        }
    }

    /// Trigger the system permission prompt. Safe to call multiple times —
    /// CoreLocation will only show the prompt the first time.
    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    /// Start receiving location updates. Caller is responsible for stopping.
    func startUpdating() {
        guard authorization == .authorizedWhenInUse || authorization == .authorizedAlways else { return }
        manager.startUpdatingLocation()
    }

    /// Request a one-shot fix for explicit user actions such as "centre on
    /// me". `startUpdatingLocation()` stays active so the map puck can continue
    /// to refine after the first coordinate arrives.
    func requestCurrentLocation() {
        guard authorization == .authorizedWhenInUse || authorization == .authorizedAlways else {
            requestWhenInUse()
            return
        }
        lastErrorDescription = nil
        manager.requestLocation()
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.authorization = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.startUpdating()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in
            self.lastErrorDescription = nil
            self.current = last.coordinate
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.lastErrorDescription = error.localizedDescription
        }
    }
}
