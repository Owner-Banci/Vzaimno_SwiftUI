import Foundation
import UIKit

protocol DeviceService {
    func registerCurrentDevice(token: String) async throws
    func unregisterCurrentDevice(token: String) async throws
}

final class NetworkDeviceService: DeviceService {
    private let api: APIClient

    init(api: APIClient = APIClient()) {
        self.api = api
    }

    func registerCurrentDevice(token: String) async throws {
        let request = DeviceRegistrationRequestDTO(
            device_id: CurrentDeviceIdentity.deviceID,
            platform: "ios",
            push_token: nil,
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier,
            device_name: CurrentDeviceIdentity.deviceName
        )

        let _: OperationStatusResponseDTO = try await api.request(.registerDevice, body: request, token: token)
    }

    func unregisterCurrentDevice(token: String) async throws {
        let request = UnregisterDeviceRequestDTO(
            device_id: CurrentDeviceIdentity.deviceID,
            push_token: nil
        )

        let _: OperationStatusResponseDTO = try await api.request(.deleteCurrentDevice, body: request, token: token)
    }
}

private enum CurrentDeviceIdentity {
    private static let fallbackDeviceIDKey = "icuno.device.fallback-id"

    static var deviceID: String {
        if let vendorID = UIDevice.current.identifierForVendor?.uuidString, !vendorID.isEmpty {
            return vendorID
        }

        if let saved = UserDefaults.standard.string(forKey: fallbackDeviceIDKey), !saved.isEmpty {
            return saved
        }

        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: fallbackDeviceIDKey)
        return generated
    }

    static var deviceName: String {
        let current = UIDevice.current
        let name = current.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? current.model : name
    }
}
