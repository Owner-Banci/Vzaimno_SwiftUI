import MapKit
import SwiftUI

enum RouteMapPolylineKind: String {
    case main
    case previewBranch
    case customerMain
}

struct RouteMapPolyline: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let kind: RouteMapPolylineKind
}

enum RouteMapMarkerKind {
    case currentLocation
    case start
    case end
    case primaryTask
    case acceptedTask
    case previewTask
    case customerTask
}

struct RouteMapMarker: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let coordinate: CLLocationCoordinate2D
    let kind: RouteMapMarkerKind
}

@MainActor
struct RouteAppleMapView: UIViewRepresentable {
    @Binding var focusedCoordinate: CLLocationCoordinate2D?

    let markers: [RouteMapMarker]
    let selectedMarkerID: String?
    let polylines: [RouteMapPolyline]
    let shouldFitContents: Bool
    let onRouteFitted: () -> Void
    let onMarkerTap: (String) -> Void

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
        mapView.showsUserLocation = false
        context.coordinator.onMarkerTap = onMarkerTap
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onMarkerTap = onMarkerTap
        syncAnnotations(on: mapView)
        syncPolylines(on: mapView)
        syncSelection(on: mapView, coordinator: context.coordinator)

        if shouldFitContents {
            fitVisibleContent(on: mapView)
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
                    span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                )
                mapView.setRegion(region, animated: true)
            }
        }
    }

    private func syncAnnotations(on mapView: MKMapView) {
        let existing = mapView.annotations.compactMap { $0 as? RouteMarkerAnnotation }
        mapView.removeAnnotations(existing)
        mapView.addAnnotations(markers.map(RouteMarkerAnnotation.init(marker:)))
    }

    private func syncPolylines(on mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)

        for polyline in polylines where polyline.coordinates.count >= 2 {
            var coordinates = polyline.coordinates
            let overlay = MKPolyline(coordinates: &coordinates, count: coordinates.count)
            overlay.title = polyline.id
            overlay.subtitle = polyline.kind.rawValue
            mapView.addOverlay(overlay)
        }
    }

    private func syncSelection(on mapView: MKMapView, coordinator: Coordinator) {
        guard let selectedMarkerID else {
            coordinator.suppressSelectionCallback = true
            mapView.selectedAnnotations.forEach { mapView.deselectAnnotation($0, animated: true) }
            DispatchQueue.main.async {
                coordinator.suppressSelectionCallback = false
            }
            return
        }

        let matching = mapView.annotations
            .compactMap { $0 as? RouteMarkerAnnotation }
            .first(where: { $0.markerID == selectedMarkerID })

        guard let matching else { return }
        guard mapView.selectedAnnotations.first as? RouteMarkerAnnotation !== matching else { return }

        coordinator.suppressSelectionCallback = true
        mapView.selectAnnotation(matching, animated: true)
        DispatchQueue.main.async {
            coordinator.suppressSelectionCallback = false
        }
    }

    private func fitVisibleContent(on mapView: MKMapView) {
        var rect: MKMapRect?

        for overlay in mapView.overlays {
            rect = rect.map { $0.union(overlay.boundingMapRect) } ?? overlay.boundingMapRect
        }

        for annotation in mapView.annotations where !(annotation is MKUserLocation) {
            let point = MKMapPoint(annotation.coordinate)
            let pointRect = MKMapRect(
                origin: MKMapPoint(x: point.x - 400, y: point.y - 400),
                size: MKMapSize(width: 800, height: 800)
            )
            rect = rect.map { $0.union(pointRect) } ?? pointRect
        }

        guard let rect else { return }
        mapView.setVisibleMapRect(
            rect,
            edgePadding: UIEdgeInsets(top: 44, left: 20, bottom: 44, right: 20),
            animated: true
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onMarkerTap: ((String) -> Void)?
        var lastFocusedKey: String?
        var suppressSelectionCallback = false

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let annotation = annotation as? RouteMarkerAnnotation else { return nil }
            let reuseIdentifier = "RouteMarkerAnnotation"
            let view: MKMarkerAnnotationView

            if let existing = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? MKMarkerAnnotationView {
                view = existing
                view.annotation = annotation
            } else {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
                view.canShowCallout = true
            }

            view.displayPriority = annotation.kind == .previewTask ? .defaultHigh : .required
            view.markerTintColor = annotation.kind.markerColor
            view.glyphImage = UIImage(systemName: annotation.kind.systemImage)
            view.titleVisibility = .visible
            view.subtitleVisibility = .adaptive
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation as? RouteMarkerAnnotation else { return }
            guard !suppressSelectionCallback else { return }
            onMarkerTap?(annotation.markerID)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolylineRenderer(polyline: polyline)
            switch RouteMapPolylineKind(rawValue: polyline.subtitle ?? "") {
            case .some(.previewBranch):
                renderer.strokeColor = UIColor(Theme.ColorToken.peach)
                renderer.lineWidth = 4
                renderer.lineDashPattern = [6, 6]
            case .some(.customerMain):
                renderer.strokeColor = UIColor(Theme.ColorToken.turquoise).withAlphaComponent(0.65)
                renderer.lineWidth = 5
            case .some(.main), .none:
                renderer.strokeColor = UIColor(Theme.ColorToken.turquoise)
                renderer.lineWidth = 6
            }

            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }
    }
}

private final class RouteMarkerAnnotation: NSObject, MKAnnotation {
    let markerID: String
    let kind: RouteMapMarkerKind
    let title: String?
    let subtitle: String?
    dynamic var coordinate: CLLocationCoordinate2D

    init(marker: RouteMapMarker) {
        self.markerID = marker.id
        self.kind = marker.kind
        self.title = marker.title
        self.subtitle = marker.subtitle
        self.coordinate = marker.coordinate
    }
}

private extension RouteMapMarkerKind {
    var markerColor: UIColor {
        switch self {
        case .currentLocation:
            return .systemBlue
        case .start:
            return .systemGray
        case .end:
            return .black
        case .primaryTask:
            return UIColor(Theme.ColorToken.turquoise)
        case .acceptedTask:
            return .systemGreen
        case .previewTask:
            return UIColor(Theme.ColorToken.peach)
        case .customerTask:
            return UIColor(Theme.ColorToken.turquoise).withAlphaComponent(0.75)
        }
    }

    var systemImage: String {
        switch self {
        case .currentLocation:
            return "location.fill"
        case .start:
            return "circle.fill"
        case .end:
            return "flag.fill"
        case .primaryTask:
            return "star.fill"
        case .acceptedTask:
            return "checkmark"
        case .previewTask:
            return "plus"
        case .customerTask:
            return "shippingbox.fill"
        }
    }
}
