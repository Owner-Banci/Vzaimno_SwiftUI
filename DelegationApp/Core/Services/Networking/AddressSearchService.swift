// AddressSearchService.swift
// iCuno test / DelegationApp

import Foundation
import YandexMapsMobile

final class AddressSearchService {

    private let searchManager: YMKSearchManager?
    private var searchSession: YMKSearchSession?
    private let isEnabled: Bool

    init() {
//        // В превью отключаем сервис.
//        if RuntimeEnvironment.isPreview {
//            self.searchManager = nil
//            self.isEnabled = false
//            return
//        }

        YandexMapConfigurator.configureIfNeeded()

        let managerType: YMKSearchManagerType = .combined
        let search = YMKSearch.sharedInstance()
        self.searchManager = search?.createSearchManager(with: managerType)
        self.isEnabled = (self.searchManager != nil)
    }

    func searchAddress(
        _ text: String,
        completion: @escaping (YMKPoint?) -> Void
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(nil)
            return
        }

        // В превью просто ничего не ищем.
        guard isEnabled, let searchManager else {
            completion(nil)
            return
        }

        let bbox = YMKBoundingBox(
            southWest: YMKPoint(latitude: -85.0, longitude: -180.0),
            northEast: YMKPoint(latitude: 85.0, longitude: 180.0)
        )
        let geometry = YMKGeometry(boundingBox: bbox)

        let options = YMKSearchOptions()
        options.geometry = true

        searchSession = searchManager.submit(
            withText: trimmed,
            geometry: geometry,
            searchOptions: options
        ) { [weak self] response, error in
            defer { self?.searchSession = nil }

            if let error {
                print("Search error: \(error)")
                completion(nil)
                return
            }

            guard
                let collection = response?.collection,
                let firstItem = collection.children.first,
                let obj = firstItem.obj,
                let point = obj.geometry.first?.point
            else {
                completion(nil)
                return
            }

            completion(point)
        }
    }
}
