import MapKit
import SwiftUI

@MainActor
struct RouteAppleMapView: UIViewRepresentable {
    @Binding var focusedCoordinate: CLLocationCoordinate2D?

    let pins: [RouteMapPin]
    let selectedPinID: String?
    let routeCoordinates: [CLLocationCoordinate2D]
    let shouldFitRoute: Bool
    let onRouteFitted: () -> Void
    let onPinTap: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        context.coordinator.onPinTap = onPinTap
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onPinTap = onPinTap
        syncAnnotations(on: mapView)
        syncRoute(on: mapView)

        if let selectedPinID {
            let annotation = mapView.annotations
                .compactMap { $0 as? RoutePointAnnotation }
                .first(where: { $0.pinID == selectedPinID })
            if let annotation, mapView.selectedAnnotations.first as? RoutePointAnnotation !== annotation {
                context.coordinator.suppressSelectionCallback = true
                mapView.selectAnnotation(annotation, animated: true)
                DispatchQueue.main.async {
                    context.coordinator.suppressSelectionCallback = false
                }
            }
        } else {
            context.coordinator.suppressSelectionCallback = true
            mapView.selectedAnnotations.forEach { mapView.deselectAnnotation($0, animated: true) }
            DispatchQueue.main.async {
                context.coordinator.suppressSelectionCallback = false
            }
        }

        if shouldFitRoute, routeCoordinates.count >= 2 {
            fitRoute(on: mapView)
            DispatchQueue.main.async {
                onRouteFitted()
            }
            return
        }

        if let focusedCoordinate {
            let key = String(format: "%.6f|%.6f", focusedCoordinate.latitude, focusedCoordinate.longitude)
            if context.coordinator.lastFocusedKey != key {
                context.coordinator.lastFocusedKey = key
                let region = MKCoordinateRegion(
                    center: focusedCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
                mapView.setRegion(region, animated: true)
            }
        }
    }

    private func syncAnnotations(on mapView: MKMapView) {
        let existing = mapView.annotations.compactMap { $0 as? RoutePointAnnotation }
        mapView.removeAnnotations(existing)
        mapView.addAnnotations(pins.map(RoutePointAnnotation.init(pin:)))
    }

    private func syncRoute(on mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)
        guard routeCoordinates.count >= 2 else { return }

        var coordinates = routeCoordinates
        let polyline = MKPolyline(coordinates: &coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
    }

    private func fitRoute(on mapView: MKMapView) {
        guard let routePolyline = mapView.overlays.first as? MKPolyline else { return }
        let bottomInset = max(48, min(96, mapView.bounds.height * 0.24))
        mapView.setVisibleMapRect(
            routePolyline.boundingMapRect,
            edgePadding: UIEdgeInsets(top: 40, left: 24, bottom: bottomInset, right: 24),
            animated: true
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onPinTap: ((String) -> Void)?
        var lastFocusedKey: String?
        var suppressSelectionCallback = false

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let annotation = annotation as? RoutePointAnnotation else { return nil }
            let reuseIdentifier = "RoutePointAnnotation"
            let view: MKMarkerAnnotationView

            if let existing = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? MKMarkerAnnotationView {
                view = existing
                view.annotation = annotation
            } else {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
                view.canShowCallout = true
            }

            view.displayPriority = .required
            view.markerTintColor = annotation.kind.markerColor
            view.glyphText = annotation.kind.glyph
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation as? RoutePointAnnotation else { return }
            guard !suppressSelectionCallback else { return }
            onPinTap?(annotation.pinID)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.systemBlue
            renderer.lineWidth = 5
            return renderer
        }
    }
}

private final class RoutePointAnnotation: NSObject, MKAnnotation {
    let pinID: String
    let kind: RouteMapPinKind
    let title: String?
    let subtitle: String?
    dynamic var coordinate: CLLocationCoordinate2D

    init(pin: RouteMapPin) {
        self.pinID = pin.id
        self.kind = pin.kind
        self.title = pin.title
        self.subtitle = pin.subtitle
        self.coordinate = pin.coordinate
    }
}

private extension RouteMapPinKind {
    var markerColor: UIColor {
        switch self {
        case .start:
            return .systemBlue
        case .end:
            return .systemRed
        case .recommendedTask:
            return .systemGreen
        case .debugTask:
            return .systemGray
        }
    }

    var glyph: String {
        switch self {
        case .start:
            return "A"
        case .end:
            return "B"
        case .recommendedTask:
            return "•"
        case .debugTask:
            return "•"
        }
    }
}
