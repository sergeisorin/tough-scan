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
            return "Apple Intelligence ready"
        case .deviceNotEligible:
            return "Apple Intelligence unavailable"
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is off"
        case .modelNotReady:
            return "Apple Intelligence is preparing"
        case .unsupportedLocale:
            return "Language not supported"
        case .unknown:
            return "Apple Intelligence unavailable"
        }
    }

    var message: String {
        switch self {
        case .available:
            return "Apple Intelligence is available for this document."
        case .deviceNotEligible:
            return "This device does not support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to summarize or clean recovered text."
        case .modelNotReady:
            return "Apple Intelligence is still downloading or preparing. Try again later."
        case .unsupportedLocale:
            return "Apple Intelligence is not available for the current language or locale."
        case .unknown:
            return "Apple Intelligence is not available right now."
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
