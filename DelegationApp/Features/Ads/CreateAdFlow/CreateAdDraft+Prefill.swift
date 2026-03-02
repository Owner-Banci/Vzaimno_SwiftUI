//
//  CreateAdDraft+Prefill.swift
//  iCuno test
//
//  Created by maftuna murtazaeva on 27.02.2026.
//

import Foundation
import YandexMapsMobile

extension CreateAdDraft {

    static func prefilled(from ann: AnnouncementDTO) -> CreateAdDraft {
        let d = CreateAdDraft()

        // category
        d.category = Category(rawValue: ann.category)

        // common
        d.title = ann.title
        d.budget = ann.data["budget"]?.stringValue ?? ""
        d.notes = ann.data["notes"]?.stringValue ?? ""

        // audience/contact (если есть)
        if let a = ann.data["audience"]?.stringValue, let aud = Audience(rawValue: a) {
            d.audience = aud
        }
        if let cm = ann.data["contact_method"]?.stringValue, let m = ContactMethod(rawValue: cm) {
            d.contactMethod = m
        }
        d.contactName = ann.data["contact_name"]?.stringValue ?? ""
        d.contactPhone = ann.data["contact_phone"]?.stringValue ?? ""

        // addresses
        if ann.category == "delivery" {
            d.pickupAddress = ann.data["pickup_address"]?.stringValue ?? ""
            d.dropoffAddress = ann.data["dropoff_address"]?.stringValue ?? ""
        } else if ann.category == "help" {
            d.helpAddress = ann.data["address"]?.stringValue ?? ""
        }

        return d
    }

    func applyModerationMarks(from ann: AnnouncementDTO) {
        guard let reasons = ann.moderationPayload?.reasons else { return }
        var dict: [String: DraftModerationMark] = [:]

        for r in reasons {
            let mark = DraftModerationMark(
                severity: r.severity,
                code: r.code,
                details: r.details
            )
            // если по одному полю несколько причин — берём более строгую
            if let existing = dict[r.field], existing.severity >= mark.severity {
                continue
            }
            dict[r.field] = mark
        }

        moderationMarks = dict
    }
}
