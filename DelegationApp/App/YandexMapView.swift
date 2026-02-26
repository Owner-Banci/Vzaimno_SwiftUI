/// Обёртка над YMKMapView для использования в SwiftUI.
///
/// Поддерживает:
/// - интерактивные маркеры объявлений;
/// - выделение выбранного маркера;
/// - отрисовку маршрута;
/// - подстройку камеры под маршрут.

import SwiftUI
import YandexMapsMobile
import UIKit

struct YandexMapView: UIViewRepresentable {
    @Binding var centerPoint: YMKPoint?

    let pins: [MapAdPin]
    let selectedPinID: String?
    let routePolyline: YMKPolyline?
    let shouldFitRoute: Bool
    let onRouteFitted: () -> Void
    let onPinTap: (String) -> Void

    final class Coordinator: NSObject, YMKMapObjectTapListener {
        var mapView: YMKMapView?
        var pinPlacemarks: [String: YMKPlacemarkMapObject] = [:]
        var routeObject: YMKPolylineMapObject?
        var lastCenterPoint: YMKPoint?
        var imageCache: [String: UIImage] = [:]
        var onPinTap: ((String) -> Void)?

        func onMapObjectTap(with mapObject: YMKMapObject, point: YMKPoint) -> Bool {
            if let id = mapObject.userData as? String {
                onPinTap?(id)
                return true
            }
            if let id = mapObject.userData as? NSString {
                onPinTap?(id as String)
                return true
            }
            return false
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        YandexMapConfigurator.configureIfNeeded()

        guard let mapView = makeNativeMapView() else {
            return container
        }
        mapView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: container.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        context.coordinator.mapView = mapView
        context.coordinator.onPinTap = onPinTap

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let mapView = context.coordinator.mapView else { return }
        context.coordinator.onPinTap = onPinTap

        let map = mapView.mapWindow.map
        let mapObjects = map.mapObjects

        syncPins(
            pins: pins,
            selectedPinID: selectedPinID,
            mapObjects: mapObjects,
            coordinator: context.coordinator
        )
        syncRoute(routePolyline, mapObjects: mapObjects, coordinator: context.coordinator)

        if shouldFitRoute, let routePolyline {
            fitCameraToRoute(routePolyline, mapView: mapView)
            onRouteFitted()
            return
        }

        if let center = centerPoint {
            moveCameraIfNeeded(to: center, map: map, coordinator: context.coordinator)
        }
    }

    private func makeNativeMapView() -> YMKMapView? {
        #if targetEnvironment(simulator)
        // For Apple Silicon simulators MapKit recommends Vulkan-backed view.
        return YMKMapView(frame: .zero, vulkanPreferred: true)
        #else
        return YMKMapView(frame: .zero)
        #endif
    }

    private func syncPins(
        pins: [MapAdPin],
        selectedPinID: String?,
        mapObjects: YMKMapObjectCollection,
        coordinator: Coordinator
    ) {
        let currentIDs = Set(pins.map(\.id))

        for (id, placemark) in coordinator.pinPlacemarks where !currentIDs.contains(id) {
            placemark.removeTapListener(with: coordinator)
            mapObjects.remove(with: placemark)
            coordinator.pinPlacemarks.removeValue(forKey: id)
        }

        for pin in pins {
            let placemark: YMKPlacemarkMapObject
            if let existing = coordinator.pinPlacemarks[pin.id] {
                placemark = existing
                placemark.geometry = pin.point
            } else {
                placemark = mapObjects.addPlacemark()
                placemark.geometry = pin.point
                placemark.userData = pin.id
                placemark.zIndex = 100
                placemark.addTapListener(with: coordinator)
                coordinator.pinPlacemarks[pin.id] = placemark
            }

            let isSelected = (selectedPinID == pin.id)
            applyMarkerStyle(
                for: placemark,
                label: pin.label,
                isSelected: isSelected,
                coordinator: coordinator
            )
        }
    }

    private func applyMarkerStyle(
        for placemark: YMKPlacemarkMapObject,
        label: String,
        isSelected: Bool,
        coordinator: Coordinator
    ) {
        let image = markerImage(label: label, isSelected: isSelected, cache: &coordinator.imageCache)
        let style = YMKIconStyle()
        style.anchor = NSValue(cgPoint: CGPoint(x: 0.5, y: 1.0))
        style.scale = 1.0
        style.zIndex = NSNumber(value: isSelected ? 10.0 : 0.0)
        placemark.setIconWith(image, style: style)
        placemark.zIndex = isSelected ? 200 : 100
    }

    private func markerImage(label: String, isSelected: Bool, cache: inout [String: UIImage]) -> UIImage {
        let key = "\(label)|\(isSelected ? "1" : "0")"
        if let cached = cache[key] { return cached }

        let text = label.isEmpty ? "Объявление" : label
        let font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        let textSize = (text as NSString).size(withAttributes: [.font: font])

        let paddingX: CGFloat = 12
        let height: CGFloat = 34
        let width = max(64, textSize.width + paddingX * 2)
        let size = CGSize(width: width, height: height)
        let radius = height / 2

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            let fillColor = isSelected ? UIColor.systemBlue : UIColor.white
            let strokeColor = isSelected ? UIColor.systemBlue : UIColor.systemTeal.withAlphaComponent(0.4)
            let textColor = isSelected ? UIColor.white : UIColor.label

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
            (text as NSString).draw(
                in: textRect,
                withAttributes: [
                    .font: font,
                    .foregroundColor: textColor,
                ]
            )
        }

        cache[key] = image
        return image
    }

    private func syncRoute(
        _ polyline: YMKPolyline?,
        mapObjects: YMKMapObjectCollection,
        coordinator: Coordinator
    ) {
        guard let polyline else {
            if let routeObject = coordinator.routeObject {
                mapObjects.remove(with: routeObject)
                coordinator.routeObject = nil
            }
            return
        }

        if let routeObject = coordinator.routeObject {
            routeObject.geometry = polyline
        } else {
            let routeObject = mapObjects.addPolyline(with: polyline)
            routeObject.strokeWidth = 5
            routeObject.outlineWidth = 2
            routeObject.outlineColor = UIColor.systemBlue.withAlphaComponent(0.2)
            routeObject.setStrokeColorWith(.systemBlue)
            routeObject.zIndex = 50
            coordinator.routeObject = routeObject
        }
    }

    private func moveCameraIfNeeded(
        to point: YMKPoint,
        map: YMKMap,
        coordinator: Coordinator
    ) {
        let shouldMove: Bool
        if let last = coordinator.lastCenterPoint {
            let dLat = abs(last.latitude - point.latitude)
            let dLon = abs(last.longitude - point.longitude)
            shouldMove = dLat > 0.000001 || dLon > 0.000001
        } else {
            shouldMove = true
        }

        guard shouldMove else { return }

        coordinator.lastCenterPoint = point
        let position = YMKCameraPosition(target: point, zoom: 14, azimuth: 0, tilt: 0)
        let animation = YMKAnimation(type: .smooth, duration: 0.6)
        map.move(with: position, animation: animation, cameraCallback: nil)
    }

    private func fitCameraToRoute(_ polyline: YMKPolyline, mapView: YMKMapView) {
        let map = mapView.mapWindow.map
        let width = Float(max(1, mapView.bounds.width))
        let height = Float(max(1, mapView.bounds.height))

        let insetX: Float = 24
        let insetTop: Float = 80
        let insetBottom: Float = 220

        let topLeft = YMKScreenPoint(x: insetX, y: insetTop)
        let bottomRight = YMKScreenPoint(
            x: max(insetX + 1, width - insetX),
            y: max(insetTop + 1, height - insetBottom)
        )
        let focusRect = YMKScreenRect(topLeft: topLeft, bottomRight: bottomRight)

        let geometry = YMKGeometry(polyline: polyline)
        let camera = map.cameraPosition(
          with: geometry,
          azimuth: 0.0,
          tilt: 0.0,
          focus: focusRect
        )
        map.move(with: camera, animation: YMKAnimation(type: .smooth, duration: 0.65), cameraCallback: nil)
    }
}
