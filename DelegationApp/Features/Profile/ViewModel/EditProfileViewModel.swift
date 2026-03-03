import Foundation

@MainActor
final class EditProfileViewModel: ObservableObject {
    let bioLimit: Int = 300

    @Published var displayName: String
    @Published var city: String
    @Published var bio: String
    @Published var preferredAddress: String

    @Published private(set) var displayNameError: String?
    @Published private(set) var bioError: String?
    @Published private(set) var preferredAddressError: String?
    @Published private(set) var formError: String?
    @Published private(set) var isSaving: Bool = false
    @Published private(set) var isLoggingOut: Bool = false
    @Published var isLogoutConfirmationPresented: Bool = false

    private let service: ProfileService
    private let session: SessionStore
    private let onSaved: (UserProfile) -> Void
    private var baseProfile: UserProfile

    init(
        profile: UserProfile,
        service: ProfileService,
        session: SessionStore,
        onSaved: @escaping (UserProfile) -> Void
    ) {
        self.baseProfile = profile
        self.service = service
        self.session = session
        self.onSaved = onSaved

        let editable = profile.editableFields
        self.displayName = editable.displayName
        self.city = editable.city
        self.bio = editable.bio
        self.preferredAddress = editable.preferredAddress
    }

    var contactTitle: String { baseProfile.contactTitle }
    var contactValue: String { baseProfile.contactValue }
    var contactCaption: String { baseProfile.contactCaption }
    var stats: ProfileStats { baseProfile.stats }
    var isBusy: Bool { isSaving || isLoggingOut }
    var bioCounterText: String { "\(bio.count)/\(bioLimit)" }

    func save() async -> Bool {
        formError = nil

        guard let draft = validateAndBuildDraft() else { return false }
        guard let token = session.token else {
            formError = "Сессия истекла. Войдите снова."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let updatedFields = try await service.updateMyProfile(token: token, fields: draft)
            let updatedProfile = baseProfile.applying(updatedFields)
            baseProfile = updatedProfile
            onSaved(updatedProfile)
            return true
        } catch {
            if error.isUnauthorizedResponse {
                await session.logout()
                return false
            }

            formError = error.localizedDescription
            return false
        }
    }

    func logout() async {
        isLoggingOut = true
        defer { isLoggingOut = false }
        await session.logout()
    }

    private func validateAndBuildDraft() -> EditableProfileFields? {
        displayNameError = nil
        bioError = nil
        preferredAddressError = nil

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.count < 2 {
            displayNameError = "Укажите имя не короче 2 символов."
        }

        let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBio.count > bioLimit {
            bioError = "Описание не должно превышать \(bioLimit) символов."
        }

        let trimmedPreferredAddress = preferredAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPreferredAddress.count > 180 {
            preferredAddressError = "Адрес не должен превышать 180 символов."
        }

        guard displayNameError == nil, bioError == nil, preferredAddressError == nil else {
            return nil
        }

        return EditableProfileFields(
            displayName: trimmedName,
            bio: trimmedBio,
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            preferredAddress: trimmedPreferredAddress,
            homeLocation: baseProfile.homeLocation
        )
    }
}
