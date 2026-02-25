/// Обёртка над YMKMapView для использования в SwiftUI.
///
/// Важно: в превью мы не создаём нативную карту вообще,
/// чтобы не падал SwiftUI Preview.

import SwiftUI
import YandexMapsMobile

struct YandexMapView: UIViewRepresentable {
    @Binding var centerPoint: YMKPoint?
    let pins: [YMKPoint]

    final class Coordinator {
        var mapView: YMKMapView?
        var centerPlacemark: YMKPlacemarkMapObject?
        var pinPlacemarks: [YMKPlacemarkMapObject] = []
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

        let startPoint = centerPoint ?? YMKPoint(latitude: 55.751244, longitude: 37.618423)
        applyState(on: mapView, coordinator: context.coordinator, center: startPoint, pins: pins)

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let mapView = context.coordinator.mapView else { return }

        let target = centerPoint ?? YMKPoint(latitude: 55.751244, longitude: 37.618423)
        applyState(on: mapView, coordinator: context.coordinator, center: target, pins: pins)
    }

    private func makeNativeMapView() -> YMKMapView? {
        #if targetEnvironment(simulator)
        // For Apple Silicon simulators MapKit recommends Vulkan-backed view.
        return YMKMapView(frame: .zero, vulkanPreferred: true)
        #else
        return YMKMapView(frame: .zero)
        #endif
    }

    private func applyState(
        on mapView: YMKMapView,
        coordinator: Coordinator,
        center: YMKPoint,
        pins: [YMKPoint]
    ) {
        let map = mapView.mapWindow.map

        // Камера
        let position = YMKCameraPosition(target: center, zoom: 14, azimuth: 0, tilt: 0)
        let animation = YMKAnimation(type: .smooth, duration: 0.8)
        map.move(with: position, animation: animation, cameraCallback: nil)

        let mapObjects = map.mapObjects

        // Маркер центра (поиск)
        if let old = coordinator.centerPlacemark {
            mapObjects.remove(with: old)
        }
        coordinator.centerPlacemark = mapObjects.addPlacemark(with: center)

        // Пины объявлений
        for old in coordinator.pinPlacemarks {
            mapObjects.remove(with: old)
        }
        coordinator.pinPlacemarks.removeAll()

        for p in pins {
            let pm = mapObjects.addPlacemark(with: p)
            coordinator.pinPlacemarks.append(pm)
        }
    }
}
