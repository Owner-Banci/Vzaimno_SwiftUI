import MapKit
import SwiftUI

struct AppleTaskMapCameraCommand {
    enum Kind {
        case zoomIn
        case zoomOut
        case center(CLLocationCoordinate2D)
    }

    let id: UUID = UUID()
    let kind: Kind
}

@MainActor
struct AppleTaskMapView: UIViewRepresentable {
    @Binding var visibleCenterCoordinate: CLLocationCoordinate2D?

    let tasks: [MapTaskPresentation]
    let selectedAnnouncementID: String?
    let routeCoordinates: [CLLocationCoordinate2D]
    let shouldFitRoute: Bool
    let cameraCommand: AppleTaskMapCameraCommand?
    let onRouteFitted: () -> Void
    let onCameraCommandHandled: (UUID) -> Void
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
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        context.coordinator.onPinTap = onPinTap
        let centerBinding = _visibleCenterCoordinate
        context.coordinator.onVisibleCenterChange = { coordinate in
            centerBinding.wrappedValue = coordinate
        }

        if let center = visibleCenterCoordinate {
            mapView.setRegion(
                MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
                ),
                animated: false
            )
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onPinTap = onPinTap
        let centerBinding = _visibleCenterCoordinate
        context.coordinator.onVisibleCenterChange = { coordinate in
            centerBinding.wrappedValue = coordinate
        }

        syncAnnotations(on: mapView, coordinator: context.coordinator)
        syncRoute(on: mapView)
        syncSelection(on: mapView, coordinator: context.coordinator)

        if shouldFitRoute, routeCoordinates.count >= 2 {
            fitRoute(on: mapView)
            DispatchQueue.main.async {
                onRouteFitted()
            }
            return
        }

        if let cameraCommand, context.coordinator.lastCommandID != cameraCommand.id {
            context.coordinator.lastCommandID = cameraCommand.id
            apply(cameraCommand: cameraCommand, on: mapView)
            DispatchQueue.main.async {
                onCameraCommandHandled(cameraCommand.id)
            }
        }
    }

    private func syncAnnotations(on mapView: MKMapView, coordinator: Coordinator) {
        let existing = mapView.annotations.compactMap { $0 as? TaskPointAnnotation }
        mapView.removeAnnotations(existing)

        let annotations = tasks.compactMap { task -> TaskPointAnnotation? in
            guard let coordinate = task.coordinate else { return nil }
            let kind: MapTaskMarkerKind = selectedAnnouncementID == task.id ? .selected : task.markerKind
            return TaskPointAnnotation(
                pinID: task.id,
                coordinate: coordinate,
                title: task.title,
                subtitle: task.subtitle,
                markerText: task.markerText,
                kind: kind
            )
        }
        mapView.addAnnotations(annotations)
    }

    private func syncRoute(on mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)
        guard routeCoordinates.count >= 2 else { return }

        var coordinates = routeCoordinates
        let polyline = MKPolyline(coordinates: &coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
    }

    private func syncSelection(on mapView: MKMapView, coordinator: Coordinator) {
        guard let selectedAnnouncementID else {
            coordinator.suppressSelectionCallback = true
            mapView.selectedAnnotations.forEach { mapView.deselectAnnotation($0, animated: true) }
            DispatchQueue.main.async {
                coordinator.suppressSelectionCallback = false
            }
            return
        }

        let matching = mapView.annotations
            .compactMap { $0 as? TaskPointAnnotation }
            .first(where: { $0.pinID == selectedAnnouncementID })

        guard let matching else { return }
        guard mapView.selectedAnnotations.first as? TaskPointAnnotation !== matching else { return }

        coordinator.suppressSelectionCallback = true
        mapView.selectAnnotation(matching, animated: true)
        DispatchQueue.main.async {
            coordinator.suppressSelectionCallback = false
        }
    }

    private func apply(cameraCommand: AppleTaskMapCameraCommand, on mapView: MKMapView) {
        switch cameraCommand.kind {
        case .zoomIn:
            var region = mapView.region
            region.span.latitudeDelta = max(0.005, region.span.latitudeDelta * 0.7)
            region.span.longitudeDelta = max(0.005, region.span.longitudeDelta * 0.7)
            mapView.setRegion(region, animated: true)

        case .zoomOut:
            var region = mapView.region
            region.span.latitudeDelta = min(90, region.span.latitudeDelta * 1.35)
            region.span.longitudeDelta = min(90, region.span.longitudeDelta * 1.35)
            mapView.setRegion(region, animated: true)

        case .center(let coordinate):
            let region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )
            mapView.setRegion(region, animated: true)
        }
    }

    private func fitRoute(on mapView: MKMapView) {
        guard let polyline = mapView.overlays.first as? MKPolyline else { return }
        mapView.setVisibleMapRect(
            polyline.boundingMapRect,
            edgePadding: UIEdgeInsets(top: 72, left: 28, bottom: 180, right: 28),
            animated: true
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onPinTap: ((String) -> Void)?
        var onVisibleCenterChange: ((CLLocationCoordinate2D) -> Void)?
        var lastCommandID: UUID?
        var suppressSelectionCallback = false
        private var imageCache: [String: UIImage] = [:]

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            guard let annotation = annotation as? TaskPointAnnotation else { return nil }
            let reuseIdentifier = "TaskPointAnnotationView"
            let view: MKAnnotationView

            if let existing = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) {
                view = existing
                view.annotation = annotation
            } else {
                view = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
                view.canShowCallout = false
                view.centerOffset = CGPoint(x: 0, y: -18)
            }

            view.image = markerImage(
                text: annotation.markerText,
                kind: annotation.kind
            )
            view.layer.zPosition = annotation.kind == .selected ? 200 : (annotation.kind == .onRoute ? 150 : 100)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation as? TaskPointAnnotation else { return }
            guard !suppressSelectionCallback else { return }
            onPinTap?(annotation.pinID)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor(Theme.ColorToken.turquoise)
            renderer.lineWidth = 5
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            onVisibleCenterChange?(mapView.centerCoordinate)
        }

        private func markerImage(text: String, kind: MapTaskMarkerKind) -> UIImage {
            let key = "\(kind)|\(text)"
            if let cached = imageCache[key] {
                return cached
            }

            let font = UIFont.systemFont(ofSize: 12, weight: .bold)
            let displayText = text.isEmpty ? "Задача" : text
            let textSize = (displayText as NSString).size(withAttributes: [.font: font])
            let horizontalPadding: CGFloat = 14
            let height: CGFloat = 36
            let width = max(72, textSize.width + horizontalPadding * 2)
            let size = CGSize(width: width, height: height)
            let radius = height / 2

            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { _ in
                let rect = CGRect(origin: .zero, size: size)
                let fillColor: UIColor
                let strokeColor: UIColor
                let textColor: UIColor

                switch kind {
                case .regular:
                    fillColor = UIColor.white
                    strokeColor = UIColor(Theme.ColorToken.turquoise).withAlphaComponent(0.22)
                    textColor = UIColor.label
                case .onRoute:
                    fillColor = UIColor(Theme.ColorToken.turquoise)
                    strokeColor = fillColor
                    textColor = .white
                case .selected:
                    fillColor = UIColor(Theme.ColorToken.peach)
                    strokeColor = fillColor
                    textColor = .white
                }

                let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
                fillColor.setFill()
                path.fill()

                strokeColor.setStroke()
                path.lineWidth = 1
                path.stroke()

                let textRect = CGRect(
                    x: (width - textSize.width) / 2,
                    y: (height - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                (displayText as NSString).draw(
                    in: textRect,
                    withAttributes: [
                        .font: font,
                        .foregroundColor: textColor,
                    ]
                )
            }

            imageCache[key] = image
            return image
        }
    }
}

private final class TaskPointAnnotation: NSObject, MKAnnotation {
    let pinID: String
    let markerText: String
    let kind: MapTaskMarkerKind
    let title: String?
    let subtitle: String?
    dynamic var coordinate: CLLocationCoordinate2D

    init(
        pinID: String,
        coordinate: CLLocationCoordinate2D,
        title: String,
        subtitle: String,
        markerText: String,
        kind: MapTaskMarkerKind
    ) {
        self.pinID = pinID
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.markerText = markerText
        self.kind = kind
    }
}
