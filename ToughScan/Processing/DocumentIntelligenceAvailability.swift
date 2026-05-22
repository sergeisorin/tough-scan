import Foundation
import FoundationModels

enum DocumentIntelligenceAvailability: Equatable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unsupportedLocale
    case unknown

    var canGenerate: Bool {
        self == .available
    }

    var title: String {
        switch self {
        case .available:
            return "AI-assisted review ready"
        case .deviceNotEligible:
            return "AI-assisted review unavailable"
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is off"
        case .modelNotReady:
            return "AI-assisted review is preparing"
        case .unsupportedLocale:
            return "Language not supported"
        case .unknown:
            return "AI-assisted review unavailable"
        }
    }

    var message: String {
        switch self {
        case .available:
            return "AI-assisted review is ready for this recovered text."
        case .deviceNotEligible:
            return "This device does not support Apple Intelligence. You can still scan, copy, and export recovered documents."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to summarize, extract, or clean recovered text. Scan, copy, and export still work without it."
        case .modelNotReady:
            return "Apple Intelligence is still downloading or preparing. Try again later. Recovered text can still be copied and exported."
        case .unsupportedLocale:
            return "AI-assisted review is not available for the current language or locale. You can still copy and export recovered text."
        case .unknown:
            return "AI-assisted review is not available right now. Scan, copy, and export still work."
        }
    }

    static var current: DocumentIntelligenceAvailability {
        let model = SystemLanguageModel.default
        return map(
            modelAvailability: model.availability,
            supportsLocale: model.supportsLocale()
        )
    }

    static func map(
        modelAvailability: SystemLanguageModel.Availability,
        supportsLocale: Bool
    ) -> DocumentIntelligenceAvailability {
        switch modelAvailability {
        case .available:
            return supportsLocale ? .available : .unsupportedLocale
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        @unknown default:
            return .unknown
        }
    }
}

protocol DocumentIntelligenceAvailabilityProviding {
    func currentAvailability() -> DocumentIntelligenceAvailability
}

struct SystemDocumentIntelligenceAvailabilityProvider: DocumentIntelligenceAvailabilityProviding {
    func currentAvailability() -> DocumentIntelligenceAvailability {
        DocumentIntelligenceAvailability.current
    }
}

struct StaticDocumentIntelligenceAvailabilityProvider: DocumentIntelligenceAvailabilityProviding {
    let availability: DocumentIntelligenceAvailability

    func currentAvailability() -> DocumentIntelligenceAvailability {
        availability
    }
}
