//
//  CreateAdDraft.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 18.02.2026.
//

import UIKit
import Foundation
#if canImport(YandexMapsMobile)
import YandexMapsMobile
#endif

@MainActor
final class CreateAdDraft: ObservableObject {

    struct DraftModerationMark: Equatable {
        let severity: ModerationSeverity
        let code: String
        let details: String
    }

    struct RecommendedPriceRange: Equatable {
        let min: Int
        let max: Int

        var text: String {
            if min == max {
                return "\(min) ₽"
            }
            return "\(min)–\(max) ₽"
        }

        var minPlaceholder: String { "\(min)" }
        var maxPlaceholder: String { "\(max)" }
    }

    enum Category: String, CaseIterable, Identifiable {
        case delivery = "delivery"
        case help = "help"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .delivery: return "Доставка и поручения"
            case .help: return "Помощь"
            }
        }
    }

    enum MainGroup: String, CaseIterable, Identifiable {
        case delivery = "delivery"
        case help = "help"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .delivery: return "Доставка"
            case .help: return "Помощь"
            }
        }

        var legacyCategory: Category {
            switch self {
            case .delivery: return .delivery
            case .help: return .help
            }
        }
    }

    typealias DeliveryMainGroup = MainGroup

    enum UserActionType: String, CaseIterable, Identifiable {
        case pickup = "pickup"
        case buy = "buy"
        case carry = "carry"
        case ride = "ride"
        case proHelp = "pro_help"
        case other = "other"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .pickup: return "Забрать"
            case .buy: return "Купить"
            case .carry: return "Перенести"
            case .ride: return "Подвезти"
            case .proHelp: return "Помощь от профи"
            case .other: return "Другое"
            }
        }

        var subtitle: String {
            switch self {
            case .pickup: return "Забрать и отвезти"
            case .buy: return "Купить и привезти"
            case .carry: return "Донести, поднять, перенести"
            case .ride: return "Подвезти пассажира"
            case .proHelp: return "Быстрая помощь специалиста"
            case .other: return "Нестандартное поручение"
            }
        }

        var systemImage: String {
            switch self {
            case .pickup: return "shippingbox"
            case .buy: return "cart"
            case .carry: return "figure.strengthtraining.traditional"
            case .ride: return "car"
            case .proHelp: return "wrench.and.screwdriver"
            case .other: return "sparkles"
            }
        }
    }

    typealias ActionType = UserActionType

    enum ResolvedCategory: String, CaseIterable, Identifiable {
        case pickupPoint = "pickup_point"
        case handoff = "handoff"
        case buy = "buy"
        case carry = "carry"
        case ride = "ride"
        case proHelp = "pro_help"
        case other = "other"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .pickupPoint: return "Забрать"
            case .handoff: return "Передача"
            case .buy: return "Покупка"
            case .carry: return "Перенос"
            case .ride: return "Поездка"
            case .proHelp: return "Помощь от профи"
            case .other: return "Другое"
            }
        }
    }

    enum ItemType: String, CaseIterable, Identifiable {
        case groceries = "groceries"
        case documents = "documents"
        case electronics = "electronics"
        case fragileItem = "fragile_item"
        case bags = "bags"
        case bulkyItem = "bulky_item"
        case other = "other"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .groceries: return "Продукты"
            case .documents: return "Документы"
            case .electronics: return "Техника"
            case .fragileItem: return "Хрупкая вещь"
            case .bags: return "Пакеты"
            case .bulkyItem: return "Крупная вещь"
            case .other: return "Другое"
            }
        }

        var accusativeTitle: String {
            switch self {
            case .groceries: return "продукты"
            case .documents: return "документы"
            case .electronics: return "технику"
            case .fragileItem: return "хрупкую вещь"
            case .bags: return "пакеты"
            case .bulkyItem: return "крупную вещь"
            case .other: return "вещь"
            }
        }

        var systemImage: String {
            switch self {
            case .groceries: return "basket"
            case .documents: return "doc.text"
            case .electronics: return "laptopcomputer"
            case .fragileItem: return "wineglass"
            case .bags: return "bag"
            case .bulkyItem: return "shippingbox.fill"
            case .other: return "square.grid.2x2"
            }
        }
    }

    enum PurchaseType: String, CaseIterable, Identifiable {
        case groceries = "groceries"
        case medicine = "medicine"
        case clothing = "clothing"
        case electronics = "electronics"
        case homeGoods = "home_goods"
        case other = "other"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .groceries: return "Продукты"
            case .medicine: return "Лекарства"
            case .clothing: return "Одежда"
            case .electronics: return "Техника"
            case .homeGoods: return "Товары для дома"
            case .other: return "Другое"
            }
        }

        var accusativeTitle: String {
            switch self {
            case .groceries: return "продукты"
            case .medicine: return "лекарства"
            case .clothing: return "одежду"
            case .electronics: return "технику"
            case .homeGoods: return "товары для дома"
            case .other: return "покупку"
            }
        }

        var systemImage: String {
            switch self {
            case .groceries: return "basket"
            case .medicine: return "cross.case"
            case .clothing: return "tshirt"
            case .electronics: return "ipad.and.iphone"
            case .homeGoods: return "house"
            case .other: return "ellipsis.circle"
            }
        }
    }

    enum HelpType: String, CaseIterable, Identifiable {
        case consultation = "consultation"
        case setupDevice = "setup_device"
        case installOrConnect = "install_or_connect"
        case minorRepair = "minor_repair"
        case diagnose = "diagnose"
        case other = "other"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .consultation: return "Консультация"
            case .setupDevice: return "Настроить устройство"
            case .installOrConnect: return "Подключить / установить"
            case .minorRepair: return "Мелкий ремонт"
            case .diagnose: return "Проверить / диагностировать"
            case .other: return "Другое"
            }
        }

        var shortTitle: String {
            switch self {
            case .consultation: return "консультация"
            case .setupDevice: return "настроить устройство"
            case .installOrConnect: return "подключить / установить"
            case .minorRepair: return "мелкий ремонт"
            case .diagnose: return "проверить / диагностировать"
            case .other: return "быстрая помощь"
            }
        }

        var systemImage: String {
            switch self {
            case .consultation: return "bubble.left.and.bubble.right"
            case .setupDevice: return "gearshape.2"
            case .installOrConnect: return "cable.connector"
            case .minorRepair: return "wrench.adjustable"
            case .diagnose: return "stethoscope"
            case .other: return "sparkles"
            }
        }
    }

    enum SourceKind: String, CaseIterable, Identifiable {
        case person = "person"
        case pickupPoint = "pickup_point"
        case venue = "venue"
        case address = "address"
        case office = "office"
        case other = "other"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .person: return "У человека"
            case .pickupPoint: return "Из ПВЗ"
            case .venue: return "Из заведения"
            case .address: return "С адреса"
            case .office: return "Из офиса"
            case .other: return "Другое"
            }
        }

        var systemImage: String {
            switch self {
            case .person: return "person.crop.circle"
            case .pickupPoint: return "shippingbox.circle"
            case .venue: return "storefront"
            case .address: return "mappin.and.ellipse"
            case .office: return "building.2"
            case .other: return "ellipsis.circle"
            }
        }
    }

    enum DestinationKind: String, CaseIterable, Identifiable {
        case person = "person"
        case address = "address"
        case office = "office"
        case entrance = "entrance"
        case metro = "metro"
        case other = "other"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .person: return "Человеку"
            case .address: return "По адресу"
            case .office: return "В офис"
            case .entrance: return "До подъезда"
            case .metro: return "К метро"
            case .other: return "Другое"
            }
        }

        var systemImage: String {
            switch self {
            case .person: return "person.crop.circle.badge.checkmark"
            case .address: return "mappin.circle"
            case .office: return "building.2.crop.circle"
            case .entrance: return "door.left.hand.open"
            case .metro: return "tram.circle"
            case .other: return "ellipsis.circle"
            }
        }
    }

    enum Urgency: String, CaseIterable, Identifiable {
        case now = "now"
        case today = "today"
        case scheduled = "scheduled"
        case flexible = "flexible"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .now: return "Сейчас"
            case .today: return "Сегодня"
            case .scheduled: return "Ко времени"
            case .flexible: return "Не срочно"
            }
        }

        var systemImage: String {
            switch self {
            case .now: return "bolt"
            case .today: return "sun.max"
            case .scheduled: return "calendar"
            case .flexible: return "clock.arrow.circlepath"
            }
        }
    }

    enum WeightCategory: String, CaseIterable, Identifiable {
        case upTo1kg = "up_to_1kg"
        case upTo3kg = "up_to_3kg"
        case upTo7kg = "up_to_7kg"
        case upTo15kg = "up_to_15kg"
        case over15kg = "over_15kg"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .upTo1kg: return "До 1 кг"
            case .upTo3kg: return "До 3 кг"
            case .upTo7kg: return "До 7 кг"
            case .upTo15kg: return "До 15 кг"
            case .over15kg: return "Тяжелее"
            }
        }
    }

    enum SizeCategory: String, CaseIterable, Identifiable {
        case pocket = "pocket"
        case hand = "hand"
        case backpack = "backpack"
        case trunk = "trunk"
        case bulky = "bulky"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .pocket: return "Карман"
            case .hand: return "В руку"
            case .backpack: return "В рюкзак"
            case .trunk: return "В багажник"
            case .bulky: return "Крупное"
            }
        }
    }

    enum ConditionOption: String, CaseIterable, Identifiable {
        case requiresVehicle = "requires_vehicle"
        case needsTrunk = "needs_trunk"
        case requiresCarefulHandling = "requires_careful_handling"
        case requiresLiftToFloor = "requires_lift_to_floor"
        case hasElevator = "has_elevator"
        case needsLoader = "needs_loader"
        case waitOnSite = "wait_on_site"
        case callBeforeArrival = "call_before_arrival"
        case requiresConfirmationCode = "requires_confirmation_code"
        case contactless = "contactless"
        case requiresReceipt = "requires_receipt"
        case photoReportRequired = "photo_report_required"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .requiresVehicle: return "Нужна машина"
            case .needsTrunk: return "Нужен багажник"
            case .requiresCarefulHandling: return "Нужна аккуратная перевозка"
            case .requiresLiftToFloor: return "Нужно поднять / спустить"
            case .hasElevator: return "Есть лифт"
            case .needsLoader: return "Нужна вторая пара рук"
            case .waitOnSite: return "Нужно подождать на месте"
            case .callBeforeArrival: return "Нужно созвониться заранее"
            case .requiresConfirmationCode: return "Нужен код / подтверждение"
            case .contactless: return "Бесконтактно"
            case .requiresReceipt: return "Нужен чек"
            case .photoReportRequired: return "Нужен фотоотчёт"
            }
        }

        var subtitle: String {
            switch self {
            case .requiresVehicle: return "Если без авто не справиться"
            case .needsTrunk: return "Важно место для груза"
            case .requiresCarefulHandling: return "Хрупкое, ценное или деликатное"
            case .requiresLiftToFloor: return "Важно учесть этаж"
            case .hasElevator: return "Чтобы быстрее поднять или спустить"
            case .needsLoader: return "Если одному не справиться"
            case .waitOnSite: return "Придётся подождать в точке"
            case .callBeforeArrival: return "Нужно связаться заранее"
            case .requiresConfirmationCode: return "Код, пропуск или подтверждение"
            case .contactless: return "Передать без личного контакта"
            case .requiresReceipt: return "Важно сохранить чек"
            case .photoReportRequired: return "Подтвердить выполнение фото"
            }
        }

        var systemImage: String {
            switch self {
            case .requiresVehicle: return "car"
            case .needsTrunk: return "car.rear.and.tire.marks"
            case .requiresCarefulHandling: return "hand.raised.square.on.square"
            case .requiresLiftToFloor: return "arrow.up.arrow.down"
            case .hasElevator: return "arrow.up.forward.square"
            case .needsLoader: return "person.2"
            case .waitOnSite: return "hourglass"
            case .callBeforeArrival: return "phone"
            case .requiresConfirmationCode: return "number.square"
            case .contactless: return "hand.wave"
            case .requiresReceipt: return "receipt"
            case .photoReportRequired: return "camera"
            }
        }
    }

    enum ContactMethod: String, CaseIterable, Identifiable {
        case callsAndMessages = "calls_and_messages"
        case messagesOnly = "messages_only"
        case callsOnly = "calls_only"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .callsAndMessages: return "Звонки и сообщения"
            case .messagesOnly: return "Только сообщения"
            case .callsOnly: return "Только звонки"
            }
        }
    }

    enum Audience: String, CaseIterable, Identifiable {
        case individuals = "individuals"
        case business = "business"
        case both = "both"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .individuals: return "Частные лица"
            case .business: return "Бизнес"
            case .both: return "Частные лица и бизнес"
            }
        }
    }

    @Published var moderationMarks: [String: DraftModerationMark] = [:]

    // MARK: - Legacy / compatibility fields
    @Published var category: Category?
    @Published var title: String = ""
    @Published var budget: String = ""
    @Published var budgetMin: String = ""
    @Published var budgetMax: String = ""

    @Published var pickupAddress: String = ""
    @Published var dropoffAddress: String = ""
    @Published var pickupPoint: YMKPoint?
    @Published var dropoffPoint: YMKPoint?
    @Published var startDate: Date = Date().addingTimeInterval(2 * 60 * 60)
    @Published var hasEndTime: Bool = false
    @Published var endDate: Date = Date().addingTimeInterval(3 * 60 * 60)

    @Published var cargoLength: String = ""
    @Published var cargoWidth: String = ""
    @Published var cargoHeight: String = ""

    @Published var floor: String = ""
    @Published var hasElevator: Bool = true
    @Published var needLoader: Bool = false

    @Published var helpAddress: String = ""
    @Published var helpPoint: YMKPoint?
    @Published var helpDestinationAddress: String = ""
    @Published var helpDestinationPoint: YMKPoint?

    // MARK: - Structured fields
    @Published var actionType: UserActionType? {
        didSet {
            guard actionType != oldValue else { return }
            applyActionDefaults(from: oldValue, to: actionType)
        }
    }
    @Published var itemType: ItemType?
    @Published var purchaseType: PurchaseType?
    @Published var helpType: HelpType?
    @Published var sourceKind: SourceKind?
    @Published var destinationKind: DestinationKind?
    @Published var urgency: Urgency = .today {
        didSet {
            guard urgency != oldValue else { return }
            applyUrgencyDefaults()
        }
    }
    @Published var weightCategory: WeightCategory?
    @Published var sizeCategory: SizeCategory?

    @Published var estimatedTaskMinutes: String = ""
    @Published var waitingMinutes: String = ""

    @Published var requiresVehicle: Bool = false
    @Published var needsTrunk: Bool = false
    @Published var requiresCarefulHandling: Bool = false
    @Published var requiresLiftToFloor: Bool = false
    @Published var waitOnSite: Bool = false
    @Published var contactless: Bool = false
    @Published var requiresReceipt: Bool = false
    @Published var requiresConfirmationCode: Bool = false
    @Published var callBeforeArrival: Bool = false
    @Published var photoReportRequired: Bool = false

    @Published var taskBrief: String = ""
    @Published var notes: String = ""
    @Published var mediaLocalIdentifiers: [String] = []
    @Published var aiHints: [String] = []

    // MARK: - Contacts
    @Published var contactName: String = ""
    @Published var contactPhone: String = ""
    @Published var contactMethod: ContactMethod = .callsAndMessages
    @Published var audience: Audience = .both

    @Published var mediaImages: [UIImage] = []
    @Published var mediaJPEGData: [Data] = []

    private var pickupAddressSnapshot: String?
    private var dropoffAddressSnapshot: String?
    private var lastAutoFilledDescription: String = ""

    var manualTitleOverride: String {
        get { title }
        set { title = newValue }
    }

    var userActionType: UserActionType? { actionType }

    var sourceAddress: String {
        AdValidators.normalizedAddress(pickupAddress)
    }

    var destinationAddress: String {
        AdValidators.normalizedAddress(dropoffAddress)
    }

    var hasAttachedMedia: Bool {
        !mediaJPEGData.isEmpty
    }

    var userEnteredFreeTextValues: [String] {
        [
            AdValidators.trimmed(resolvedTitle),
            AdValidators.trimmed(resolvedDescription),
        ]
        .filter { !$0.isEmpty }
    }

    var hasUserEnteredFreeText: Bool {
        !AdValidators.trimmed(resolvedDescription).isEmpty
    }

    var usesOnlyStructuredTemplateData: Bool {
        false
    }

    var moderationTextPayload: String {
        userEnteredFreeTextValues.joined(separator: "\n")
    }

    var hasExactDimensions: Bool {
        !AdValidators.trimmed(cargoLength).isEmpty
            || !AdValidators.trimmed(cargoWidth).isEmpty
            || !AdValidators.trimmed(cargoHeight).isEmpty
    }

    var resolvedCategory: ResolvedCategory {
        if let actionType {
            switch actionType {
            case .pickup:
                return sourceKind == .person ? .handoff : .pickupPoint
            case .buy:
                return .buy
            case .carry:
                return .carry
            case .ride:
                return .ride
            case .proHelp:
                return .proHelp
            case .other:
                return .other
            }
        }

        if helpType != nil {
            return .proHelp
        }
        if purchaseType != nil || requiresReceipt {
            return .buy
        }
        if sourceKind == .person, !destinationAddress.isEmpty {
            return .handoff
        }
        if category == .delivery {
            return .pickupPoint
        }
        return .other
    }

    var mainGroup: MainGroup {
        switch resolvedCategory {
        case .pickupPoint, .handoff, .buy:
            return .delivery
        case .carry, .ride, .proHelp, .other:
            return .help
        }
    }

    var availableGenericItemTypes: [ItemType] {
        switch actionType {
        case .some(.pickup):
            return [.groceries, .documents, .electronics, .fragileItem, .bags, .bulkyItem, .other]
        case .some(.carry):
            return [.bags, .fragileItem, .bulkyItem, .electronics, .other]
        default:
            return [.groceries, .documents, .electronics, .fragileItem, .bags, .bulkyItem, .other]
        }
    }

    var availableSourceKinds: [SourceKind] {
        switch actionType {
        case .some(.pickup):
            return [.person, .pickupPoint, .venue, .address, .office, .other]
        case .some(.buy):
            return [.venue, .address, .other]
        case .some(.carry):
            return [.address, .office, .other]
        case .some(.ride):
            return [.address, .office, .other]
        case .some(.proHelp):
            return [.address, .office, .venue, .other]
        case .some(.other):
            return [.address, .person, .other]
        case .none:
            return []
        }
    }

    var availableDestinationKinds: [DestinationKind] {
        switch actionType {
        case .some(.pickup):
            return [.address, .person, .office, .entrance, .metro, .other]
        case .some(.buy):
            return [.address, .office, .entrance, .metro, .other]
        case .some(.carry):
            return [.address, .office, .entrance, .other]
        case .some(.ride):
            return [.address, .metro, .other]
        default:
            return []
        }
    }

    var availableConditionOptions: [ConditionOption] {
        guard let actionType else { return [] }

        switch actionType {
        case .pickup:
            var options: [ConditionOption] = [
                .requiresVehicle,
                .needsTrunk,
                .requiresCarefulHandling,
                .requiresLiftToFloor,
                .needsLoader,
                .waitOnSite,
                .callBeforeArrival,
                .requiresConfirmationCode,
                .contactless,
                .photoReportRequired,
            ]
            if requiresLiftToFloor {
                options.insert(.hasElevator, at: 4)
            }
            return options

        case .buy:
            return [
                .requiresVehicle,
                .needsTrunk,
                .waitOnSite,
                .callBeforeArrival,
                .contactless,
                .requiresReceipt,
                .photoReportRequired,
            ]

        case .carry:
            var options: [ConditionOption] = [
                .requiresVehicle,
                .needsTrunk,
                .requiresCarefulHandling,
                .requiresLiftToFloor,
                .needsLoader,
                .waitOnSite,
                .callBeforeArrival,
            ]
            if requiresLiftToFloor {
                options.insert(.hasElevator, at: 4)
            }
            return options

        case .ride:
            return [
                .needsTrunk,
                .waitOnSite,
                .callBeforeArrival,
            ]

        case .proHelp:
            return [
                .callBeforeArrival,
                .photoReportRequired,
            ]

        case .other:
            return [
                .requiresVehicle,
                .needsTrunk,
                .requiresCarefulHandling,
                .callBeforeArrival,
                .contactless,
            ]
        }
    }

    var showsStructuredSections: Bool {
        actionType != nil
    }

    var showsSourceSection: Bool {
        actionType != nil
    }

    var showsDestinationSection: Bool {
        guard let actionType else { return false }
        switch actionType {
        case .pickup, .buy, .carry, .ride:
            return true
        case .proHelp, .other:
            return false
        }
    }

    var requiresDestinationAddress: Bool {
        switch actionType {
        case .some(.pickup), .some(.buy), .some(.ride):
            return true
        case .some(.carry):
            return false
        case .some(.proHelp), .some(.other), .none:
            return false
        }
    }

    var showsCargoSection: Bool {
        switch actionType {
        case .some(.pickup), .some(.buy), .some(.carry):
            return true
        case .some(.other):
            return true
        default:
            return false
        }
    }

    var showsWeightAndSizeSection: Bool {
        showsCargoSection
    }

    var showsTaskBriefField: Bool {
        switch actionType {
        case .some(.proHelp), .some(.other):
            return true
        default:
            return false
        }
    }

    var requiresTaskBrief: Bool {
        switch actionType {
        case .some(.proHelp), .some(.other):
            return true
        default:
            return false
        }
    }

    var sourceAddressModerationKey: String {
        mainGroup == .delivery ? "pickup_address" : "address"
    }

    var destinationAddressModerationKey: String {
        mainGroup == .delivery ? "dropoff_address" : "destination_address"
    }

    var objectSectionTitle: String {
        switch actionType {
        case .some(.pickup), .some(.carry):
            return "Что именно"
        case .some(.buy):
            return "Что купить"
        case .some(.ride):
            return "Параметры поездки"
        case .some(.proHelp):
            return "Тип помощи"
        case .some(.other):
            return "Что нужно сделать"
        case .none:
            return "Что именно"
        }
    }

    var objectSectionSubtitle: String {
        switch actionType {
        case .some(.pickup):
            return "Выберите, что нужно забрать и отвезти."
        case .some(.buy):
            return "Отдельный набор для сценария покупки."
        case .some(.carry):
            return "Сфокусируйтесь на том, что нужно перенести."
        case .some(.ride):
            return "Минимум параметров: пассажир и багаж."
        case .some(.proHelp):
            return "Короткая быстрая задача, где нужен человек с опытом."
        case .some(.other):
            return "Коротко опишите задачу одной строкой."
        case .none:
            return "Сначала выберите главное действие."
        }
    }

    var taskBriefLabel: String {
        switch actionType {
        case .some(.proHelp):
            return "Что именно нужно?"
        case .some(.other):
            return "Что нужно сделать?"
        default:
            return "Уточнение"
        }
    }

    var taskBriefPlaceholder: String {
        switch actionType {
        case .some(.proHelp):
            return "Например: настроить телевизор"
        case .some(.other):
            return "Например: быстро проверить устройство"
        default:
            return "Коротко опишите задачу"
        }
    }

    var sourceSectionTitle: String {
        switch actionType {
        case .some(.pickup):
            return "Откуда забрать"
        case .some(.buy):
            return "Где купить"
        case .some(.carry):
            return "Откуда начать"
        case .some(.ride):
            return "Откуда забрать пассажира"
        case .some(.proHelp):
            return "Где нужна помощь"
        case .some(.other):
            return "Где это нужно"
        case .none:
            return "Откуда"
        }
    }

    var sourceFieldLabel: String {
        switch actionType {
        case .some(.buy):
            return "Адрес или место покупки"
        case .some(.proHelp):
            return "Где нужна помощь"
        case .some(.ride):
            return "Точка подачи"
        default:
            return "Адрес отправления"
        }
    }

    var destinationSectionTitle: String {
        switch actionType {
        case .some(.pickup):
            return "Куда привезти"
        case .some(.buy):
            return "Куда привезти покупку"
        case .some(.carry):
            return "Куда перенести"
        case .some(.ride):
            return "Куда подвезти"
        default:
            return "Куда"
        }
    }

    var destinationFieldLabel: String {
        switch actionType {
        case .some(.ride):
            return "Точка назначения"
        case .some(.carry):
            return "Куда перенести (опционально)"
        default:
            return requiresDestinationAddress ? "Адрес назначения" : "Адрес назначения (опционально)"
        }
    }

    var pickupObjectSummary: String {
        itemType?.title ?? "Не выбрано"
    }

    var objectSummary: String {
        switch actionType {
        case .some(.pickup), .some(.carry):
            return itemType?.title ?? "Что именно не выбрано"
        case .some(.buy):
            return purchaseType?.title ?? "Что купить не выбрано"
        case .some(.ride):
            return needsTrunk ? "1 пассажир, нужен багажник" : "1 пассажир, без багажа"
        case .some(.proHelp):
            if let helpType {
                if !AdValidators.trimmed(taskBrief).isEmpty {
                    return "\(helpType.title), \(AdValidators.trimmed(taskBrief))"
                }
                return helpType.title
            }
            return AdValidators.trimmed(taskBrief).isEmpty ? "Тип помощи не выбран" : AdValidators.trimmed(taskBrief)
        case .some(.other):
            let brief = AdValidators.trimmed(taskBrief)
            return brief.isEmpty ? "Нужно короткое уточнение" : brief
        case .none:
            return "Сначала выберите действие"
        }
    }

    var generatedTitle: String {
        switch actionType {
        case .some(.pickup):
            return "Забрать \(itemType?.accusativeTitle ?? "заказ")"

        case .some(.buy):
            return "Купить \(purchaseType?.accusativeTitle ?? "товары")"

        case .some(.carry):
            return "Перенести \(itemType?.accusativeTitle ?? "вещь")"

        case .some(.ride):
            return "Подвезти пассажира"

        case .some(.proHelp):
            return "Помощь от профи"

        case .some(.other):
            return "Нестандартная задача"

        case .none:
            return "Новое объявление"
        }
    }

    var resolvedTitle: String {
        generatedTitle
    }

    var assembledDescription: String {
        guard actionType != nil else { return "" }
        let source = shortAddress(sourceAddress)
        let destination = shortAddress(destinationAddress)
        var lines: [String] = [descriptionLeadLine(source: source, destination: destination)]

        if let route = detailedRouteLine(source: source, destination: destination) {
            lines.append(route)
        }

        if let timing = detailedTimingLine {
            lines.append(timing)
        }

        if let effort = detailedEffortLine {
            lines.append(effort)
        }

        if let conditions = detailedConditionsLine {
            lines.append(conditions)
        }

        if let dimensions = detailedDimensionsLine {
            lines.append(dimensions)
        }

        return Self.uniqueStrings(lines.map(AdValidators.trimmed).filter { !$0.isEmpty })
            .joined(separator: "\n")
    }

    var resolvedDescription: String {
        let custom = AdValidators.trimmed(notes)
        return custom.isEmpty ? assembledDescription : custom
    }

    var routeSummary: String {
        guard let actionType else { return "Сценарий ещё не выбран" }

        let sourceSummary = sourceSummaryPhrase(shortAddress: shortAddress(sourceAddress)) ?? "Точка старта не указана"

        switch actionType {
        case .proHelp, .other:
            return sourceSummary
        case .carry:
            if let destinationSummary = destinationSummaryPhrase(shortAddress: shortAddress(destinationAddress)) {
                return "\(sourceSummary) -> \(destinationSummary)"
            }
            return sourceSummary
        default:
            let destinationSummary = destinationSummaryPhrase(shortAddress: shortAddress(destinationAddress)) ?? "Точка назначения не указана"
            return "\(sourceSummary) -> \(destinationSummary)"
        }
    }

    var timeSummary: String {
        let base: String
        switch urgency {
        case .now:
            base = "Сейчас"
        case .today:
            base = "Сегодня"
        case .scheduled:
            base = Self.dateTimeFormatter.string(from: startDate)
        case .flexible:
            base = "Не срочно"
        }

        guard hasEndTime else { return base }
        return "\(base), до \(Self.timeFormatter.string(from: endDate))"
    }

    var budgetSummary: String {
        let minValue = AdValidators.parseDecimal(budgetMin).map(Int.init)
        let maxValue = AdValidators.parseDecimal(budgetMax).map(Int.init)

        switch (minValue, maxValue) {
        case let (min?, max?) where min == max:
            return "\(min) ₽"
        case let (min?, max?):
            return "\(min)-\(max) ₽"
        case let (min?, nil):
            return "от \(min) ₽"
        case let (nil, max?):
            return "до \(max) ₽"
        default:
            return "Рекомендуем \(recommendedPriceRange.text)"
        }
    }

    var generatedTags: [String] {
        var tags: [String] = [
            mainGroup.rawValue,
            resolvedCategory.rawValue,
            urgency.rawValue,
        ]

        if let actionType {
            tags.append(actionType.rawValue)
        }
        if let itemType {
            tags.append(itemType.rawValue)
        }
        if let purchaseType {
            tags.append(purchaseType.rawValue)
        }
        if let helpType {
            tags.append(helpType.rawValue)
        }
        if let sourceKind {
            tags.append(sourceKind.rawValue)
        }
        if let destinationKind {
            tags.append(destinationKind.rawValue)
        }
        if let weightCategory {
            tags.append(weightCategory.rawValue)
        }
        if let sizeCategory {
            tags.append(sizeCategory.rawValue)
        }
        if requiresVehicle { tags.append("requires_vehicle") }
        if needsTrunk { tags.append("needs_trunk") }
        if requiresCarefulHandling { tags.append("careful") }
        if requiresLiftToFloor { tags.append("lift") }
        if needLoader { tags.append("loader") }
        if waitOnSite { tags.append("wait_on_site") }
        if contactless { tags.append("contactless") }
        if requiresReceipt { tags.append("receipt") }
        if requiresConfirmationCode { tags.append("confirmation_code") }
        if photoReportRequired { tags.append("photo_report") }

        return Self.uniqueStrings(tags)
    }

    var generatedHints: [String] {
        var hints: [String] = []

        if let actionType {
            hints.append(actionType.title)
        }

        switch actionType {
        case .some(.pickup), .some(.carry):
            if let itemType {
                hints.append(itemType.title)
            }
        case .some(.buy):
            if let purchaseType {
                hints.append(purchaseType.title)
            }
        case .some(.proHelp):
            if let helpType {
                hints.append(helpType.title)
            }
        case .some(.ride):
            hints.append(needsTrunk ? "С багажом" : "Без багажа")
        default:
            break
        }

        hints.append(urgency.title)

        if let weightCategory, showsWeightAndSizeSection {
            hints.append(weightCategory.title)
        }
        if let sizeCategory, showsWeightAndSizeSection {
            hints.append(sizeCategory.title)
        }

        hints.append(contentsOf: selectedConditionTitles)
        return Self.uniqueStrings(hints)
    }

    var selectedConditionTitles: [String] {
        var values: [String] = []
        if requiresVehicle, actionType != .ride { values.append(ConditionOption.requiresVehicle.title) }
        if needsTrunk { values.append(ConditionOption.needsTrunk.title) }
        if requiresCarefulHandling { values.append(ConditionOption.requiresCarefulHandling.title) }
        if requiresLiftToFloor { values.append(ConditionOption.requiresLiftToFloor.title) }
        if requiresLiftToFloor, hasElevator { values.append(ConditionOption.hasElevator.title) }
        if needLoader { values.append(ConditionOption.needsLoader.title) }
        if waitOnSite { values.append(ConditionOption.waitOnSite.title) }
        if callBeforeArrival { values.append(ConditionOption.callBeforeArrival.title) }
        if requiresConfirmationCode { values.append(ConditionOption.requiresConfirmationCode.title) }
        if contactless { values.append(ConditionOption.contactless.title) }
        if requiresReceipt { values.append(ConditionOption.requiresReceipt.title) }
        if photoReportRequired { values.append(ConditionOption.photoReportRequired.title) }
        if contactMethod == .messagesOnly { values.append("Только сообщения") }
        return values
    }

    var recommendedPriceRange: RecommendedPriceRange {
        var base = baseRecommendedPrice()

        switch urgency {
        case .now:
            base += 250
        case .today:
            base += 90
        case .scheduled:
            base += 0
        case .flexible:
            base -= 40
        }

        if requiresVehicle, actionType != .ride {
            base += 150
        }
        if needsTrunk {
            base += 120
        }
        if requiresCarefulHandling {
            base += 90
        }
        if requiresLiftToFloor {
            base += 130
            if !hasElevator {
                base += 140
            }
        }
        if needLoader {
            base += 240
        }
        if waitOnSite {
            let minutes = Int(AdValidators.parseDecimal(waitingMinutes) ?? 10)
            base += min(280, max(40, minutes * 8))
        }
        if callBeforeArrival {
            base += 20
        }
        if requiresConfirmationCode {
            base += 40
        }
        if contactless {
            base += 20
        }
        if requiresReceipt {
            base += 35
        }
        if photoReportRequired {
            base += 40
        }

        switch weightCategory {
        case .some(.upTo1kg):
            base += 0
        case .some(.upTo3kg):
            base += 30
        case .some(.upTo7kg):
            base += 70
        case .some(.upTo15kg):
            base += 120
        case .some(.over15kg):
            base += 200
        case .none:
            break
        }

        switch sizeCategory {
        case .some(.pocket):
            base += 0
        case .some(.hand):
            base += 20
        case .some(.backpack):
            base += 50
        case .some(.trunk):
            base += 110
        case .some(.bulky):
            base += 180
        case .none:
            break
        }

        let longestSide = [cargoLength, cargoWidth, cargoHeight]
            .compactMap { AdValidators.parseDecimal($0) }
            .max() ?? 0
        if longestSide >= 100 {
            base += 180
        } else if longestSide >= 60 {
            base += 100
        } else if longestSide >= 30 {
            base += 40
        }

        let roundedBase = Self.roundToNearest50(max(250, base))
        let min = Self.roundToNearest50(max(250, Int(Double(roundedBase) * 0.85)))
        let max = Self.roundToNearest50(max(min, Int(Double(roundedBase) * 1.15)))
        return RecommendedPriceRange(min: min, max: max)
    }

    var submitReadinessIssues: [String] {
        var issues: [String] = []

        guard let actionType else {
            return ["Выберите, что нужно сделать"]
        }

        switch actionType {
        case .pickup, .carry:
            if itemType == nil {
                issues.append("Уточните, что именно нужно \(actionType == .pickup ? "забрать" : "перенести")")
            }
        case .buy:
            if purchaseType == nil {
                issues.append("Выберите, что нужно купить")
            }
        case .proHelp:
            if helpType == nil {
                issues.append("Выберите тип помощи")
            }
        case .ride:
            break
        case .other:
            break
        }

        if requiresTaskBrief, AdValidators.trimmed(taskBrief).isEmpty {
            issues.append(taskBriefLabel)
        }

        if sourceKind == nil {
            issues.append("Выберите, откуда начинается задача")
        }

        if let error = AdValidators.validateAddress(pickupAddress, fieldName: sourceFieldLabel) {
            issues.append(error)
        }

        if showsDestinationSection, requiresDestinationAddress {
            if destinationKind == nil {
                issues.append("Выберите, куда нужно доставить")
            }
            if let error = AdValidators.validateAddress(dropoffAddress, fieldName: "Адрес назначения") {
                issues.append(error)
            }
        } else if showsDestinationSection, !destinationAddress.isEmpty,
                  let error = AdValidators.validateAddress(dropoffAddress, fieldName: "Адрес назначения") {
            issues.append(error)
        }

        if actionType == .carry,
           !destinationAddress.isEmpty,
           let error = AdValidators.validateDifferentAddresses(pickupAddress, dropoffAddress) {
            issues.append(error)
        }

        if actionType == .pickup || actionType == .buy,
           let error = AdValidators.validateDifferentAddresses(pickupAddress, dropoffAddress) {
            issues.append(error)
        }

        if let error = AdValidators.validateBudgetRange(min: budgetMin, max: budgetMax) {
            issues.append(error)
        }

        if let error = AdValidators.validateTimeWindow(
            startDate: startDate,
            hasEndTime: hasEndTime,
            endDate: endDate
        ) {
            issues.append(error)
        }

        if let error = AdValidators.validateDimension(cargoLength, fieldName: "Длина", max: 500) {
            issues.append(error)
        }
        if let error = AdValidators.validateDimension(cargoWidth, fieldName: "Ширина", max: 500) {
            issues.append(error)
        }
        if let error = AdValidators.validateDimension(cargoHeight, fieldName: "Высота", max: 500) {
            issues.append(error)
        }

        if let error = Self.validateOptionalMinutes(estimatedTaskMinutes, fieldName: "Оценка по времени") {
            issues.append(error)
        }
        if waitOnSite, AdValidators.trimmed(waitingMinutes).isEmpty {
            issues.append("Укажите, сколько можно подождать на месте")
        }
        if waitOnSite, let error = Self.validateOptionalMinutes(waitingMinutes, fieldName: "Время ожидания") {
            issues.append(error)
        }

        if requiresLiftToFloor, AdValidators.trimmed(floor).isEmpty {
            issues.append("Укажите этаж")
        }
        if requiresLiftToFloor, let error = AdValidators.validateFloor(floor) {
            issues.append(error)
        }

        if let error = AdValidators.validateTitle(resolvedTitle) {
            issues.append(error)
        }

        if generatedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Не удалось собрать заголовок объявления")
        }

        if resolvedDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Не удалось собрать описание объявления")
        }

        if let phoneError = AdValidators.validateOptionalPhone(contactPhone).error {
            issues.append(phoneError)
        }

        return Self.uniqueStrings(issues)
    }

    var isReadyForSubmit: Bool {
        submitReadinessIssues.isEmpty
    }

    // MARK: - Validation
    func validateMainDataSync() -> String? {
        syncLegacyFields()
        return submitReadinessIssues.first
    }

    func validateAndGeocodeIfNeeded(searchService: AddressSearchService) async -> String? {
        if let error = validateMainDataSync() {
            return error
        }

        let sourceNormalized = AdValidators.normalizedAddress(pickupAddress)
        let destinationNormalized = AdValidators.normalizedAddress(dropoffAddress)

        if pickupAddressSnapshot != sourceNormalized {
            pickupPoint = await searchService.searchAddress(sourceNormalized)
            pickupAddressSnapshot = pickupPoint == nil ? nil : sourceNormalized
        }

        guard pickupPoint != nil else {
            return "Адрес отправления не найден. Уточните адрес"
        }

        if showsDestinationSection && (requiresDestinationAddress || !destinationNormalized.isEmpty) {
            if dropoffAddressSnapshot != destinationNormalized {
                dropoffPoint = await searchService.searchAddress(destinationNormalized)
                dropoffAddressSnapshot = dropoffPoint == nil ? nil : destinationNormalized
            }

            guard dropoffPoint != nil else {
                return "Адрес назначения не найден. Уточните адрес"
            }
        } else {
            dropoffPoint = nil
            dropoffAddressSnapshot = nil
        }

        syncLegacyFields()
        return nil
    }

    func validateContactStep() -> String? {
        let phone = AdValidators.validateOptionalPhone(contactPhone)
        if let error = phone.error {
            return error
        }

        contactPhone = phone.normalized ?? ""
        contactName = AdValidators.trimmed(contactName)
        taskBrief = AdValidators.trimmed(taskBrief)
        syncAutoGeneratedDescriptionIfNeeded()
        notes = AdValidators.trimmed(resolvedDescription)
        return nil
    }

    func validateForSubmit(searchService: AddressSearchService) async -> String? {
        if let error = await validateAndGeocodeIfNeeded(searchService: searchService) {
            return error
        }
        if let error = validateContactStep() {
            return error
        }
        return nil
    }

    // Legacy aliases for still-compiled old screens
    func validateMainStepSync() -> String? {
        validateMainDataSync()
    }

    func validateAndGeocodeMainStep(searchService: AddressSearchService) async -> String? {
        await validateAndGeocodeIfNeeded(searchService: searchService)
    }

    // MARK: - Mapping to request
    func toCreateRequest(status: String = "pending_review") -> CreateAnnouncementRequest {
        syncLegacyFields()
        syncAutoGeneratedDescriptionIfNeeded()

        let iso = ISO8601DateFormatter()
        var data: [String: JSONValue] = [:]

        let recommended = recommendedPriceRange
        let title = resolvedTitle
        let source = sourceAddress
        let destination = destinationAddress
        let taskBriefTrimmed = AdValidators.trimmed(taskBrief)
        let notesTrimmed = AdValidators.trimmed(resolvedDescription)
        let itemRaw = resolvedItemTypeRawValue
        let compatibleBudget = budgetCompatibilityValue()
        let budgetMinJSON = jsonOptionalBudgetInt(budgetMin)
        let budgetMaxJSON = jsonOptionalBudgetInt(budgetMax)
        let quickOfferPrice = max(0, compatibleBudget ?? recommended.min)
        let normalizedLifecycleStatus = status == "active" ? "open" : status
        let travelMode = (requiresVehicle || actionType == .ride || mainGroup == .delivery) ? "driving" : "walking"

        data["category"] = .string(mainGroup.rawValue)
        data["main_group"] = .string(mainGroup.rawValue)
        data["user_action_type"] = jsonString(actionType?.rawValue)
        data["action_type"] = jsonString(actionType?.rawValue)
        data["resolved_category"] = .string(resolvedCategory.rawValue)
        data["item_type"] = jsonString(itemRaw)
        data["purchase_type"] = jsonString(purchaseType?.rawValue)
        data["help_type"] = jsonString(helpType?.rawValue)
        data["source_kind"] = jsonString(sourceKind?.rawValue)
        data["destination_kind"] = jsonString(destinationKind?.rawValue)
        data["urgency"] = .string(urgency.rawValue)

        data["recommended_price_min"] = .int(recommended.min)
        data["recommended_price_max"] = .int(recommended.max)
        data["budget_min"] = budgetMinJSON
        data["budget_max"] = budgetMaxJSON
        data["quick_offer_price"] = .int(quickOfferPrice)
        if let compatibleBudget {
            data["budget"] = .int(compatibleBudget)
        } else {
            data["budget"] = .null
        }

        data["requires_vehicle"] = .bool(requiresVehicle || actionType == .ride)
        data["needs_trunk"] = .bool(needsTrunk)
        data["requires_careful_handling"] = .bool(requiresCarefulHandling)
        data["needs_loader"] = .bool(needLoader)
        data["need_loader"] = .bool(needLoader)
        data["requires_lift_to_floor"] = .bool(requiresLiftToFloor)
        data["has_elevator"] = .bool(hasElevator)
        data["wait_on_site"] = .bool(waitOnSite)
        data["contactless"] = .bool(contactless)
        data["requires_receipt"] = .bool(requiresReceipt)
        data["requires_confirmation_code"] = .bool(requiresConfirmationCode)
        data["call_before_arrival"] = .bool(callBeforeArrival)
        data["photo_report_required"] = .bool(photoReportRequired)
        data["weight_category"] = jsonString(weightCategory?.rawValue)
        data["size_category"] = jsonString(sizeCategory?.rawValue)
        data["cargo_length_cm"] = jsonOptionalInt(cargoLength)
        data["cargo_width_cm"] = jsonOptionalInt(cargoWidth)
        data["cargo_height_cm"] = jsonOptionalInt(cargoHeight)
        data["cargo_length"] = jsonOptionalDouble(cargoLength)
        data["cargo_width"] = jsonOptionalDouble(cargoWidth)
        data["cargo_height"] = jsonOptionalDouble(cargoHeight)
        data["estimated_task_minutes"] = jsonOptionalInt(estimatedTaskMinutes)
        data["waiting_minutes"] = waitOnSite ? jsonOptionalInt(waitingMinutes) : .null
        data["floor"] = jsonOptionalInt(floor)

        data["source_address"] = source.isEmpty ? .null : .string(source)
        data["destination_address"] = destination.isEmpty ? .null : .string(destination)
        data["start_at"] = .string(iso.string(from: startDate))
        data["has_end_time"] = .bool(hasEndTime)
        data["end_at"] = hasEndTime ? .string(iso.string(from: endDate)) : .null
        data["task_brief"] = taskBriefTrimmed.isEmpty ? .null : .string(taskBriefTrimmed)
        data["notes"] = notesTrimmed.isEmpty ? .null : .string(notesTrimmed)
        data["generated_description"] = .string(assembledDescription)
        data["generated_title"] = .string(generatedTitle)
        data["generated_tags"] = .array(generatedTags.map { .string($0) })
        data["ai_hints"] = .array(Self.uniqueStrings(generatedHints + aiHints).map { .string($0) })
        data["media_local_identifiers"] = .array(mediaLocalIdentifiers.map { .string($0) })

        let contactNameTrimmed = AdValidators.trimmed(contactName)
        data["contact_name"] = contactNameTrimmed.isEmpty ? .null : .string(contactNameTrimmed)
        if let phoneNormalized = AdValidators.validateOptionalPhone(contactPhone).normalized {
            data["contact_phone"] = .string(phoneNormalized)
        } else {
            data["contact_phone"] = .null
        }
        data["contact_method"] = .string(contactMethod.rawValue)
        data["audience"] = .string(audience.rawValue)

        switch mainGroup {
        case .delivery:
            data["pickup_address"] = source.isEmpty ? .null : .string(source)
            data["dropoff_address"] = destination.isEmpty ? .null : .string(destination)

            if let pickupPoint {
                let point = Self.jsonPoint(pickupPoint)
                data["pickup_point"] = point
                data["point"] = point
            }
            if let dropoffPoint {
                data["dropoff_point"] = Self.jsonPoint(dropoffPoint)
            }

        case .help:
            data["address"] = source.isEmpty ? .null : .string(source)
            data["destination_address"] = destination.isEmpty ? .null : .string(destination)

            if let pickupPoint {
                let point = Self.jsonPoint(pickupPoint)
                data["help_point"] = point
                data["point"] = point
            }
            if let dropoffPoint {
                data["destination_point"] = Self.jsonPoint(dropoffPoint)
            }
        }

        let sourcePointJSON: JSONValue = pickupPoint.map(Self.jsonPoint) ?? .null
        let destinationPointJSON: JSONValue = dropoffPoint.map(Self.jsonPoint) ?? .null
        let taskPayload: [String: JSONValue] = [
            "schema_version": .int(2),
            "lifecycle": .object([
                "status": .string(normalizedLifecycleStatus),
                "deleted_at": .null,
            ]),
            "builder": .object([
                "main_group": .string(mainGroup.rawValue),
                "action_type": jsonString(actionType?.rawValue),
                "resolved_category": .string(resolvedCategory.rawValue),
                "item_type": jsonString(itemRaw),
                "purchase_type": jsonString(purchaseType?.rawValue),
                "help_type": jsonString(helpType?.rawValue),
                "source_kind": jsonString(sourceKind?.rawValue),
                "destination_kind": jsonString(destinationKind?.rawValue),
                "urgency": .string(urgency.rawValue),
                "task_brief": taskBriefTrimmed.isEmpty ? .null : .string(taskBriefTrimmed),
                "notes": notesTrimmed.isEmpty ? .null : .string(notesTrimmed),
            ]),
            "attributes": .object([
                "requires_vehicle": .bool(requiresVehicle || actionType == .ride),
                "needs_trunk": .bool(needsTrunk),
                "requires_careful_handling": .bool(requiresCarefulHandling),
                "needs_loader": .bool(needLoader),
                "requires_lift_to_floor": .bool(requiresLiftToFloor),
                "has_elevator": .bool(hasElevator),
                "wait_on_site": .bool(waitOnSite),
                "contactless": .bool(contactless),
                "requires_receipt": .bool(requiresReceipt),
                "requires_confirmation_code": .bool(requiresConfirmationCode),
                "call_before_arrival": .bool(callBeforeArrival),
                "photo_report_required": .bool(photoReportRequired),
                "weight_category": jsonString(weightCategory?.rawValue),
                "size_category": jsonString(sizeCategory?.rawValue),
                "cargo": .object([
                    "length_cm": jsonOptionalInt(cargoLength),
                    "width_cm": jsonOptionalInt(cargoWidth),
                    "height_cm": jsonOptionalInt(cargoHeight),
                ]),
                "estimated_task_minutes": jsonOptionalInt(estimatedTaskMinutes),
                "waiting_minutes": waitOnSite ? jsonOptionalInt(waitingMinutes) : .null,
                "floor": jsonOptionalInt(floor),
            ]),
            "budget": .object([
                "currency": .string("RUB"),
                "recommended_min": .int(recommended.min),
                "recommended_max": .int(recommended.max),
                "min": budgetMinJSON,
                "max": budgetMaxJSON,
                "amount": compatibleBudget.map(JSONValue.int) ?? .null,
            ]),
            "route": .object([
                "travel_mode": .string(travelMode),
                "start_at": .string(iso.string(from: startDate)),
                "has_end_time": .bool(hasEndTime),
                "end_at": hasEndTime ? .string(iso.string(from: endDate)) : .null,
                "source": .object([
                    "address": source.isEmpty ? .null : .string(source),
                    "kind": jsonString(sourceKind?.rawValue),
                    "point": sourcePointJSON,
                ]),
                "destination": .object([
                    "address": destination.isEmpty ? .null : .string(destination),
                    "kind": jsonString(destinationKind?.rawValue),
                    "point": destinationPointJSON,
                ]),
            ]),
            "contacts": .object([
                "name": contactNameTrimmed.isEmpty ? .null : .string(contactNameTrimmed),
                "phone": data["contact_phone"] ?? .null,
                "method": .string(contactMethod.rawValue),
                "audience": .string(audience.rawValue),
            ]),
            "search": .object([
                "generated_title": .string(generatedTitle),
                "generated_description": .string(assembledDescription),
                "generated_tags": .array(generatedTags.map { .string($0) }),
                "hints": .array(Self.uniqueStrings(generatedHints + aiHints).map { .string($0) }),
            ]),
            "offer_policy": .object([
                "quick_offer_enabled": .bool(true),
                "quick_offer_price": .int(quickOfferPrice),
                "counter_price_allowed": .bool(true),
                "reoffer_policy": .string("blocked_after_reject"),
            ]),
            "execution": .object([
                "status": .string("open"),
                "assignment_id": .null,
                "performer_user_id": .null,
            ]),
        ]
        data["task"] = .object(taskPayload)

        return CreateAnnouncementRequest(
            category: mainGroup.rawValue,
            title: title,
            status: status,
            data: data
        )
    }

    // MARK: - Media helpers
    func setMediaFromPicker(datas: [Data]) {
        var images: [UIImage] = []
        var jpeg: [Data] = []

        for data in datas {
            guard let image = UIImage(data: data) else { continue }
            let compressed = image.jpegData(compressionQuality: 0.82) ?? data
            images.append(image)
            jpeg.append(compressed)
        }

        mediaImages = images
        mediaJPEGData = jpeg
    }

    func removeMedia(at index: Int) {
        guard mediaImages.indices.contains(index) else { return }
        mediaImages.remove(at: index)
        mediaJPEGData.remove(at: index)
    }

    // MARK: - Private
    private func applyActionDefaults(from oldValue: UserActionType?, to newValue: UserActionType?) {
        guard let newValue else {
            return
        }

        resetIncompatibleFields(for: newValue)

        switch newValue {
        case .pickup:
            if sourceKind == nil { sourceKind = .pickupPoint }
            if destinationKind == nil { destinationKind = .address }
            if itemType == nil { itemType = .documents }
            if AdValidators.trimmed(estimatedTaskMinutes).isEmpty { estimatedTaskMinutes = "30" }

        case .buy:
            if sourceKind == nil { sourceKind = .venue }
            if destinationKind == nil { destinationKind = .address }
            if purchaseType == nil { purchaseType = .groceries }
            if AdValidators.trimmed(estimatedTaskMinutes).isEmpty { estimatedTaskMinutes = "40" }

        case .carry:
            if sourceKind == nil { sourceKind = .address }
            if destinationKind == nil { destinationKind = .entrance }
            if itemType == nil { itemType = .bags }
            if AdValidators.trimmed(estimatedTaskMinutes).isEmpty { estimatedTaskMinutes = "45" }

        case .ride:
            if sourceKind == nil { sourceKind = .address }
            if destinationKind == nil { destinationKind = .metro }
            requiresVehicle = true
            if AdValidators.trimmed(estimatedTaskMinutes).isEmpty { estimatedTaskMinutes = "20" }

        case .proHelp:
            if sourceKind == nil { sourceKind = .address }
            if helpType == nil { helpType = .consultation }
            if AdValidators.trimmed(estimatedTaskMinutes).isEmpty { estimatedTaskMinutes = "30" }

        case .other:
            if sourceKind == nil { sourceKind = .address }
            if AdValidators.trimmed(estimatedTaskMinutes).isEmpty { estimatedTaskMinutes = "30" }
        }

        if oldValue == .ride, newValue != .ride {
            needsTrunk = false
            requiresVehicle = false
        }

        syncLegacyFields()
    }

    private func resetIncompatibleFields(for action: UserActionType) {
        switch action {
        case .pickup:
            purchaseType = nil
            helpType = nil
            taskBrief = ""
            requiresReceipt = false

        case .buy:
            itemType = nil
            helpType = nil
            taskBrief = ""
            requiresConfirmationCode = false

        case .carry:
            purchaseType = nil
            helpType = nil
            taskBrief = ""
            requiresReceipt = false
            requiresConfirmationCode = false
            contactless = false

        case .ride:
            itemType = nil
            purchaseType = nil
            helpType = nil
            taskBrief = ""
            weightCategory = nil
            sizeCategory = nil
            cargoLength = ""
            cargoWidth = ""
            cargoHeight = ""
            requiresCarefulHandling = false
            requiresLiftToFloor = false
            hasElevator = true
            needLoader = false
            requiresReceipt = false
            requiresConfirmationCode = false
            contactless = false
            photoReportRequired = false

        case .proHelp:
            itemType = nil
            purchaseType = nil
            destinationKind = nil
            dropoffAddress = ""
            dropoffPoint = nil
            dropoffAddressSnapshot = nil
            weightCategory = nil
            sizeCategory = nil
            cargoLength = ""
            cargoWidth = ""
            cargoHeight = ""
            requiresVehicle = false
            needsTrunk = false
            requiresCarefulHandling = false
            requiresLiftToFloor = false
            hasElevator = true
            needLoader = false
            waitOnSite = false
            contactless = false
            requiresReceipt = false
            requiresConfirmationCode = false

        case .other:
            itemType = nil
            purchaseType = nil
            helpType = nil
            destinationKind = nil
            dropoffAddress = ""
            dropoffPoint = nil
            dropoffAddressSnapshot = nil
            requiresReceipt = false
            requiresConfirmationCode = false
        }

        if !availableSourceKinds.contains(sourceKind ?? .other) {
            sourceKind = availableSourceKinds.first
        }

        if !availableDestinationKinds.contains(destinationKind ?? .other) {
            destinationKind = availableDestinationKinds.first
        }

        let visibleConditions = Set(availableConditionOptions)
        if action != .ride && !visibleConditions.contains(.requiresVehicle) {
            requiresVehicle = false
        }
        if action == .ride {
            requiresVehicle = true
        }
        if !visibleConditions.contains(.needsTrunk) {
            needsTrunk = false
        }
        if !visibleConditions.contains(.requiresCarefulHandling) {
            requiresCarefulHandling = false
        }
        if !visibleConditions.contains(.requiresLiftToFloor) {
            requiresLiftToFloor = false
            floor = ""
            hasElevator = true
        }
        if !visibleConditions.contains(.hasElevator) {
            hasElevator = true
        }
        if !visibleConditions.contains(.needsLoader) {
            needLoader = false
        }
        if !visibleConditions.contains(.waitOnSite) {
            waitOnSite = false
            waitingMinutes = ""
        }
        if !visibleConditions.contains(.callBeforeArrival) {
            callBeforeArrival = false
        }
        if !visibleConditions.contains(.requiresConfirmationCode) {
            requiresConfirmationCode = false
        }
        if !visibleConditions.contains(.contactless) {
            contactless = false
        }
        if !visibleConditions.contains(.requiresReceipt) {
            requiresReceipt = false
        }
        if !visibleConditions.contains(.photoReportRequired) {
            photoReportRequired = false
        }
    }

    private func applyUrgencyDefaults() {
        switch urgency {
        case .now:
            let proposed = Date().addingTimeInterval(20 * 60)
            if startDate < proposed {
                startDate = proposed
            }
        case .today:
            let proposed = Date().addingTimeInterval(2 * 60 * 60)
            if !Calendar.current.isDate(startDate, inSameDayAs: Date()) || startDate < proposed {
                startDate = proposed
            }
        case .scheduled:
            let proposed = Date().addingTimeInterval(3 * 60 * 60)
            if startDate < Date().addingTimeInterval(20 * 60) {
                startDate = proposed
            }
        case .flexible:
            let proposed = Date().addingTimeInterval(6 * 60 * 60)
            if startDate < Date().addingTimeInterval(20 * 60) {
                startDate = proposed
            }
        }
    }

    private func syncLegacyFields() {
        category = mainGroup.legacyCategory
        title = generatedTitle

        let normalizedSource = sourceAddress
        let normalizedDestination = destinationAddress

        helpAddress = normalizedSource
        helpDestinationAddress = normalizedDestination
        helpPoint = pickupPoint
        helpDestinationPoint = dropoffPoint
    }

    func syncAutoGeneratedDescriptionIfNeeded(force: Bool = false) {
        let candidate = assembledDescription
        let current = AdValidators.trimmed(notes)
        let previous = AdValidators.trimmed(lastAutoFilledDescription)

        guard force || current.isEmpty || current == previous else { return }
        notes = candidate
        lastAutoFilledDescription = candidate
    }

    private func baseRecommendedPrice() -> Int {
        switch actionType {
        case .some(.pickup):
            return resolvedCategory == .handoff ? 520 : 480
        case .some(.buy):
            var base = 620
            switch purchaseType {
            case .some(.medicine):
                base += 80
            case .some(.electronics):
                base += 120
            case .some(.homeGoods):
                base += 70
            case .some(.clothing):
                base += 40
            default:
                break
            }
            return base
        case .some(.carry):
            return 720
        case .some(.ride):
            return 650
        case .some(.proHelp):
            switch helpType {
            case .some(.consultation):
                return 850
            case .some(.setupDevice):
                return 980
            case .some(.installOrConnect):
                return 1_050
            case .some(.minorRepair):
                return 1_100
            case .some(.diagnose):
                return 950
            case .some(.other), .none:
                return 900
            }
        case .some(.other):
            return 560
        case .none:
            return 500
        }
    }

    private var resolvedItemTypeRawValue: String? {
        switch actionType {
        case .some(.buy):
            return purchaseType?.rawValue
        case .some(.proHelp):
            return nil
        default:
            return itemType?.rawValue
        }
    }

    private func descriptionLeadLine(source: String?, destination: String?) -> String {
        switch actionType {
        case .some(.pickup):
            let object = itemType?.accusativeTitle ?? "заказ"
            return "Нужно забрать \(object)."

        case .some(.buy):
            let object = purchaseType?.accusativeTitle ?? "товары"
            return "Нужно купить \(object)."

        case .some(.carry):
            let object = itemType?.accusativeTitle ?? "вещь"
            return "Нужно перенести \(object)."

        case .some(.ride):
            return needsTrunk
                ? "Нужно подвезти пассажира с багажом."
                : "Нужно подвезти пассажира без багажа."

        case .some(.proHelp):
            let brief = AdValidators.trimmed(taskBrief)
            if !brief.isEmpty {
                return "Нужна помощь от профи: \(brief)."
            }
            if let helpType {
                return "Нужна помощь от профи по сценарию \"\(helpType.title)\"."
            }
            return "Нужна помощь от профи."

        case .some(.other):
            let brief = AdValidators.trimmed(taskBrief)
            if !brief.isEmpty {
                return "Нестандартная задача: \(brief)."
            }
            return "Нестандартная задача."

        case .none:
            return "Опишите задачу через готовые параметры."
        }
    }

    private func detailedRouteLine(source: String?, destination: String?) -> String? {
        var fragments: [String] = []

        if let from = source {
            switch actionType {
            case .some(.pickup):
                if let sourcePhrase = pickupSourcePhrase(shortAddress: from) {
                    fragments.append("Забор: \(sourcePhrase).")
                }
            case .some(.buy):
                if let sourcePhrase = buySourcePhrase(shortAddress: from) {
                    fragments.append("Покупка: \(sourcePhrase).")
                }
            case .some(.carry):
                if let sourcePhrase = carrySourcePhrase(shortAddress: from) {
                    fragments.append("Старт: \(sourcePhrase).")
                }
            case .some(.ride):
                fragments.append("Подача: \(from).")
            case .some(.proHelp), .some(.other):
                fragments.append("Адрес: \(from).")
            case .none:
                break
            }
        }

        if let to = destination {
            switch actionType {
            case .some(.pickup), .some(.buy):
                if let destinationPhrase = deliveryDestinationPhrase(shortAddress: to) {
                    fragments.append("Куда доставить: \(destinationPhrase).")
                }
            case .some(.carry):
                fragments.append("Куда перенести: \(to).")
            case .some(.ride):
                fragments.append("Маршрут до: \(to).")
            case .some(.proHelp), .some(.other), .none:
                break
            }
        }

        return fragments.isEmpty ? nil : fragments.joined(separator: " ")
    }

    private var detailedTimingLine: String? {
        var fragments: [String] = ["Когда: \(timeSummary)."]

        if let minutes = Self.validateOptionalMinutes(estimatedTaskMinutes, fieldName: "") == nil
            ? Int(AdValidators.trimmed(estimatedTaskMinutes))
            : nil,
           minutes > 0 {
            fragments.append("Оценка по времени: около \(minutes) мин.")
        }

        if waitOnSite,
           let waiting = Int(AdValidators.trimmed(waitingMinutes)),
           waiting > 0 {
            fragments.append("Можно подождать на месте до \(waiting) мин.")
        }

        return fragments.joined(separator: " ")
    }

    private var detailedEffortLine: String? {
        var fragments: [String] = []

        if let weightCategory, showsWeightAndSizeSection {
            fragments.append("Вес: \(weightCategory.title).")
        }

        if let sizeCategory, showsWeightAndSizeSection {
            fragments.append("Размер: \(sizeCategory.title).")
        }

        if requiresLiftToFloor, let floorValue = Int(AdValidators.trimmed(floor)) {
            let elevator = hasElevator ? "есть лифт" : "без лифта"
            fragments.append("Подъём на \(floorValue) этаж, \(elevator).")
        }

        if needLoader {
            fragments.append("Нужен грузчик.")
        }

        return fragments.isEmpty ? nil : fragments.joined(separator: " ")
    }

    private var detailedConditionsLine: String? {
        let values = selectedConditionTitles.filter { !$0.isEmpty }
        guard !values.isEmpty else { return nil }
        return "Дополнительно: \(values.joined(separator: ", "))."
    }

    private var detailedDimensionsLine: String? {
        var dimensions: [String] = []
        if let length = Int(AdValidators.trimmed(cargoLength)), length > 0 { dimensions.append("длина \(length) см") }
        if let width = Int(AdValidators.trimmed(cargoWidth)), width > 0 { dimensions.append("ширина \(width) см") }
        if let height = Int(AdValidators.trimmed(cargoHeight)), height > 0 { dimensions.append("высота \(height) см") }
        guard !dimensions.isEmpty else { return nil }
        return "Габариты: \(dimensions.joined(separator: ", "))."
    }

    private func pickupSourcePhrase(shortAddress: String?) -> String? {
        switch sourceKind {
        case .some(.person):
            return shortAddress.map { "у человека на \($0)" } ?? "у человека"
        case .some(.pickupPoint):
            return shortAddress.map { "из ПВЗ \($0)" } ?? "из ПВЗ"
        case .some(.venue):
            return shortAddress.map { "из заведения \($0)" } ?? "из заведения"
        case .some(.address):
            return shortAddress.map { "с \($0)" } ?? "с адреса"
        case .some(.office):
            return shortAddress.map { "из офиса \($0)" } ?? "из офиса"
        case .some(.other):
            return shortAddress.map { "с точки \($0)" } ?? "с точки"
        case .none:
            return shortAddress.map { "с \($0)" }
        }
    }

    private func buySourcePhrase(shortAddress: String?) -> String? {
        switch sourceKind {
        case .some(.venue):
            return shortAddress.map { "в \($0)" } ?? "в заведении"
        case .some(.address):
            return shortAddress.map { "в месте \($0)" } ?? "в конкретном месте"
        case .some(.other):
            return shortAddress.map { "рядом с \($0)" } ?? "рядом"
        default:
            return shortAddress.map { "в \($0)" }
        }
    }

    private func carrySourcePhrase(shortAddress: String?) -> String? {
        switch sourceKind {
        case .some(.address):
            return shortAddress.map { "с \($0)" } ?? "с адреса"
        case .some(.office):
            return shortAddress.map { "из офиса \($0)" } ?? "из офиса"
        case .some(.other):
            return shortAddress.map { "из точки \($0)" } ?? "из точки"
        default:
            return shortAddress.map { "с \($0)" }
        }
    }

    private func deliveryDestinationPhrase(shortAddress: String?) -> String? {
        switch destinationKind {
        case .some(.person):
            return shortAddress.map { "человеку на \($0)" } ?? "человеку"
        case .some(.address):
            return shortAddress.map { "на \($0)" } ?? "по адресу"
        case .some(.office):
            return shortAddress.map { "в офис \($0)" } ?? "в офис"
        case .some(.entrance):
            return shortAddress.map { "до подъезда \($0)" } ?? "до подъезда"
        case .some(.metro):
            return shortAddress.map { "к метро \($0)" } ?? "к метро"
        case .some(.other):
            return shortAddress.map { "в точку \($0)" } ?? "в точку"
        case .none:
            return shortAddress.map { "на \($0)" }
        }
    }

    private func carryDestinationPhrase(shortAddress: String?) -> String? {
        guard let shortAddress else { return nil }
        return "до \(shortAddress)"
    }

    private func rideSourcePhrase(shortAddress: String?) -> String? {
        shortAddress.map { "от \($0)" }
    }

    private func rideDestinationPhrase(shortAddress: String?) -> String? {
        switch destinationKind {
        case .some(.metro):
            return shortAddress.map { "до метро \($0)" } ?? "до метро"
        case .some(.address):
            return shortAddress.map { "до \($0)" } ?? "по адресу"
        case .some(.other):
            return shortAddress.map { "до точки \($0)" } ?? "до точки"
        default:
            return shortAddress.map { "до \($0)" }
        }
    }

    private func sourceSummaryPhrase(shortAddress: String?) -> String? {
        switch actionType {
        case .some(.buy):
            return buySourcePhrase(shortAddress: shortAddress)
        case .some(.carry):
            return carrySourcePhrase(shortAddress: shortAddress)
        case .some(.ride):
            return rideSourcePhrase(shortAddress: shortAddress)
        default:
            return pickupSourcePhrase(shortAddress: shortAddress)
        }
    }

    private func destinationSummaryPhrase(shortAddress: String?) -> String? {
        switch actionType {
        case .some(.carry):
            return carryDestinationPhrase(shortAddress: shortAddress)
        case .some(.ride):
            return rideDestinationPhrase(shortAddress: shortAddress)
        default:
            return deliveryDestinationPhrase(shortAddress: shortAddress)
        }
    }

    private func shortAddress(_ value: String) -> String? {
        let normalized = AdValidators.normalizedAddress(value)
        guard !normalized.isEmpty else { return nil }

        let parts = normalized
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if parts.count >= 2 {
            return parts.suffix(2).joined(separator: ", ")
        }

        return parts.first ?? normalized
    }

    private func jsonString(_ value: String?) -> JSONValue {
        guard let value, !value.isEmpty else { return .null }
        return .string(value)
    }

    private func jsonOptionalBudgetInt(_ raw: String) -> JSONValue {
        guard let value = AdValidators.parseDecimal(raw) else { return .null }
        return .int(Int(value))
    }

    private func jsonOptionalInt(_ raw: String) -> JSONValue {
        let trimmed = AdValidators.trimmed(raw)
        guard let value = Int(trimmed) else { return .null }
        return .int(value)
    }

    private func jsonOptionalDouble(_ raw: String) -> JSONValue {
        guard let value = AdValidators.parseDecimal(raw) else { return .null }
        return .double(value)
    }

    private func budgetCompatibilityValue() -> Int? {
        if let maxValue = AdValidators.parseDecimal(budgetMax) {
            return Int(maxValue)
        }
        if let minValue = AdValidators.parseDecimal(budgetMin) {
            return Int(minValue)
        }
        if let legacyBudget = AdValidators.parseDecimal(budget) {
            return Int(legacyBudget)
        }
        return nil
    }

    private static func validateOptionalMinutes(_ raw: String, fieldName: String) -> String? {
        let trimmed = AdValidators.trimmed(raw)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Int(trimmed) else {
            return "\(fieldName) должна быть целым числом"
        }
        guard (0...1440).contains(value) else {
            return "\(fieldName) должна быть в диапазоне 0...1440 минут"
        }
        return nil
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }

    private static func roundToNearest50(_ value: Int) -> Int {
        let rounded = Int((Double(value) / 50.0).rounded()) * 50
        return max(0, rounded)
    }

    private static func jsonPoint(_ point: YMKPoint) -> JSONValue {
        .object([
            "lat": .double(point.latitude),
            "lon": .double(point.longitude),
        ])
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeStyle = .short
        return formatter
    }()
}
