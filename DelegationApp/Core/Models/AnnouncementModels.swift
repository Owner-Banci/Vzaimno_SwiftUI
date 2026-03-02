//
//  AnnouncementModels.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 18.02.2026.
//

import Foundation

// MARK: - Network models

struct AnnouncementDTO: Codable, Identifiable {
    let id: String
    let user_id: String
    let category: String
    let title: String
    let status: String
    let data: [String: JSONValue]
    let created_at: String
    let media: [JSONValue]?

    init(
        id: String,
        user_id: String,
        category: String,
        title: String,
        status: String,
        data: [String: JSONValue],
        created_at: String,
        media: [JSONValue]? = nil
    ) {
        self.id = id
        self.user_id = user_id
        self.category = category
        self.title = title
        self.status = status
        self.data = data
        self.created_at = created_at
        self.media = media
    }
}

struct CreateAnnouncementRequest: Codable {
    let category: String
    let title: String
    let status: String
    let data: [String: JSONValue]

    init(category: String, title: String, status: String = "active", data: [String: JSONValue]) {
        self.category = category
        self.title = title
        self.status = status
        self.data = data
    }
}


//------------------------------

struct MediaModerationResponse: Codable {
    let announcement: AnnouncementDTO
    let max_nsfw: Double
    let decision: String
    let can_appeal: Bool
    let message: String
}

struct AppealRequest: Codable {
    let reason: String?
}

extension AnnouncementDTO {
    var createdAtDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: created_at) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: created_at) ?? .distantPast
    }

    var imageURLs: [URL] {
        var seen: Set<String> = []
        return rawMediaValues
            .compactMap(Self.resolveMediaURL(from:))
            .filter { seen.insert($0.absoluteString).inserted }
    }

    var previewImageURL: URL? {
        imageURLs.first
    }

    var moderationCanAppeal: Bool {
        guard
            let mod = data["moderation"]?.objectValue,
            let img = mod["image"]?.objectValue,
            let can = img["can_appeal"]?.boolValue
        else { return false }
        return can
    }

    private var rawMediaValues: [JSONValue] {
        var values: [JSONValue] = media ?? []

        for key in ["media", "images", "photos"] {
            guard let raw = data[key] else { continue }

            if let array = raw.arrayValue {
                values.append(contentsOf: array)
            } else {
                values.append(raw)
            }
        }

        return values
    }

    private static func resolveMediaURL(from value: JSONValue) -> URL? {
        switch value {
        case .string(let string):
            return makeURL(from: string)

        case .object(let object):
            let preferredKeys = [
                "preview_url",
                "previewUrl",
                "thumbnail_url",
                "thumbnailUrl",
                "url",
                "image_url",
                "imageUrl",
                "file_url",
                "fileUrl",
                "path",
            ]

            for key in preferredKeys {
                if let raw = object[key]?.stringValue, let url = makeURL(from: raw) {
                    return url
                }
            }

            if let nested = object["file"] {
                return resolveMediaURL(from: nested)
            }

            return nil

        default:
            return nil
        }
    }

    private static func makeURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        if trimmed.hasPrefix("/") {
            return AppConfig.apiBaseURL.appendingPathComponent(String(trimmed.dropFirst()))
        }

        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? trimmed
        return URL(string: encoded)
    }
}
