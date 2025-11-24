import SwiftUI
import YandexMapsMobile

/// Обёртка над YMKMapView для использования в SwiftUI.
///
/// Важно: в превью мы не создаём нативную карту вообще,
/// чтобы не падал SwiftUI Preview.
struct YandexMapView: UIViewRepresentable {

    /// Координата центра карты.
    @Binding var centerPoint: YMKPoint?

    final class Coordinator {
        var mapView: YMKMapView?
        var placemark: YMKPlacemarkMapObject?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        // Контейнер, в который при обычном запуске добавим YMKMapView.
        let container = UIView()
        container.backgroundColor = .clear

        // В превью — ничего не добавляем, просто пустой UIView.
        guard !RuntimeEnvironment.isPreview else {
            return container
        }

        // В обычном запуске инициализируем SDK и карту.
        YandexMapConfigurator.configureIfNeeded()

        let mapView = YMKMapView(frame: .zero)
        mapView!.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(mapView!)

        NSLayoutConstraint.activate([
            mapView!.topAnchor.constraint(equalTo: container.topAnchor),
            mapView!.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            mapView!.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            mapView!.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        context.coordinator.mapView = mapView

        // Стартовая точка.
        let startPoint = centerPoint ?? YMKPoint(
            latitude: 55.751244,
            longitude: 37.618423
        )
        updateMap(on: mapView!, coordinator: context.coordinator, to: startPoint)

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard
            !RuntimeEnvironment.isPreview,
            let mapView = context.coordinator.mapView,
            let point = centerPoint
        else { return }

        updateMap(on: mapView, coordinator: context.coordinator, to: point)
    }

    // MARK: - Internal helpers

    private func updateMap(
        on mapView: YMKMapView,
        coordinator: Coordinator,
        to point: YMKPoint
    ) {
        let map = mapView.mapWindow.map
        let position = YMKCameraPosition(
            target: point,
            zoom: 15,
            azimuth: 0,
            tilt: 0
        )
        let animation = YMKAnimation(type: .smooth, duration: 1.0)
        map.move(with: position, animation: animation, cameraCallback: nil)

        let mapObjects = map.mapObjects
        if let oldPlacemark = coordinator.placemark {
            mapObjects.remove(with: oldPlacemark)
        }
        let placemark = mapObjects.addPlacemark(with: point)
        coordinator.placemark = placemark
    }
}
