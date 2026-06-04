import Foundation
import CoreLocation

/// Best-effort real location + temperature for the statusline.
/// Reverse-geocodes the city/state and pulls the current temp from Open-Meteo (no API key).
/// Falls back to sensible defaults if permission is denied or the network is unavailable.
final class LocationWeather: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var place: String = "NEW YORK, NY"
    @Published var temp: String = "72°F"
    @Published var isNight: Bool = LocationWeather.computeNight()

    private let mgr = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    static func computeNight() -> Bool {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 6 || h >= 19
    }

    private func isAuthorized(_ s: CLAuthorizationStatus) -> Bool {
        #if os(macOS)
        return s == .authorizedAlways
        #else
        return s == .authorizedWhenInUse || s == .authorizedAlways
        #endif
    }

    func start() {
        set { $0.isNight = LocationWeather.computeNight() }
        let status = mgr.authorizationStatus
        if status == .notDetermined {
            mgr.requestWhenInUseAuthorization()
        } else if isAuthorized(status) {
            mgr.requestLocation()
        }
    }

    private func set(_ change: @escaping (LocationWeather) -> Void) {
        DispatchQueue.main.async { change(self) }
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        if isAuthorized(m.authorizationStatus) { m.requestLocation() }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.last else { return }
        geocoder.reverseGeocodeLocation(loc) { [weak self] marks, _ in
            guard let self, let p = marks?.first else { return }
            let city = p.locality ?? p.subAdministrativeArea ?? ""
            let st = p.administrativeArea ?? ""
            let label = [city, st].filter { !$0.isEmpty }.joined(separator: ", ").uppercased()
            if !label.isEmpty { self.set { $0.place = label } }
        }
        fetchWeather(loc)
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) { /* keep fallback */ }

    private func fetchWeather(_ loc: CLLocation) {
        let lat = loc.coordinate.latitude, lon = loc.coordinate.longitude
        guard let url = URL(string:
            "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m&temperature_unit=fahrenheit"
        ) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let cur = json["current"] as? [String: Any],
                  let t = cur["temperature_2m"] as? Double else { return }
            let str = "\(Int(t.rounded()))°F"
            self.set { $0.temp = str }
        }.resume()
    }
}
