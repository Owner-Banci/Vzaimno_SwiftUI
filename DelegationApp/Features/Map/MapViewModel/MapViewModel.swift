import SwiftUI
import YandexMapsMobile
import Foundation

enum MapDisplayMode {
    case real
    case placeholder
}

enum MapDisplayConfig {
    static func defaultMode() -> MapDisplayMode {
        #if DEBUG
        return .real
        #else
        return .real
        #endif
    }
}

struct MapCanvasView: View {
    @Binding var centerPoint: YMKPoint?
    let pins: [YMKPoint]
    let mode: MapDisplayMode

    var body: some View {
        Group {
            switch mode {
            case .real:
                YandexMapView(centerPoint: $centerPoint, pins: pins)
            case .placeholder:
                Rectangle()
                    .fill(Theme.ColorToken.milk)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.system(size: 32))
                                .foregroundColor(Theme.ColorToken.textSecondary)
                            Text("Map placeholder")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.ColorToken.textSecondary)
                        }
                    )
            }
        }
    }
}

@MainActor
final class MapViewModel: ObservableObject {
    // MARK: - Фильтры
    @Published var chips: [String] = [
        "Купить", "Доставить", "Забрать",
        "Помочь", "Перенести", "Другое"
    ]
    @Published var selected: Set<String> = []

    // MARK: - Моковые задачи (пока оставляем)
    @Published var tasks: [TaskItem] = []

    // MARK: - Объявления на карте
    @Published private(set) var announcements: [AnnouncementDTO] = []
    @Published var pins: [YMKPoint] = []

    // MARK: - Поиск и карта
    @Published var searchText: String = ""
    @Published var centerPoint: YMKPoint?
    @Published var errorMessage: String?

    private let service: TaskService
    private let announcementService: AnnouncementService
    private let searchService: AddressSearchService

    init(
        service: TaskService,
        announcementService: AnnouncementService,
        searchService: AddressSearchService = AddressSearchService()
    ) {
        self.service = service
        self.announcementService = announcementService
        self.searchService = searchService

        self.tasks = service.loadNearbyTasks()
        self.centerPoint = YMKPoint(latitude: 55.751244, longitude: 37.618423)
    }

    func toggle(_ chip: String) {
        if selected.contains(chip) { selected.remove(chip) }
        else { selected.insert(chip) }
    }

    func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            errorMessage = nil
            return
        }

        searchService.searchAddress(query) { [weak self] point in
            DispatchQueue.main.async {
                guard let self else { return }
                if let point {
                    self.centerPoint = point
                    self.errorMessage = nil
                } else {
                    self.errorMessage = "Адрес не найден"
                }
            }
        }
    }

    func reloadPins() async {
        do {
            let list = try await announcementService.publicAnnouncements()
            self.announcements = list
            self.pins = list.compactMap { Self.extractPoint(from: $0) }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private static func extractPoint(from a: AnnouncementDTO) -> YMKPoint? {
        guard let pointVal = a.data["point"]?.objectValue else { return nil }
        guard
            let lat = pointVal["lat"]?.doubleValue,
            let lon = pointVal["lon"]?.doubleValue
        else { return nil }

        return YMKPoint(latitude: lat, longitude: lon)
    }
}
