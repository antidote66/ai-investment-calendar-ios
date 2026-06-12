import Foundation
import SwiftUI

enum ExposureEdgeKind: String, Codable, Hashable {
    case stablePositive
    case stableNegative
    case unstable
    case leverage

    var title: String {
        switch self {
        case .stablePositive: return "STABLE+"
        case .stableNegative: return "STABLE-"
        case .unstable: return "UNSTABLE"
        case .leverage: return "LEVERAGE"
        }
    }

    var tint: Color {
        switch self {
        case .stablePositive: return AppTheme.matcha
        case .stableNegative: return AppTheme.vermilion
        case .unstable: return AppTheme.amber
        case .leverage: return AppTheme.sumiBlue
        }
    }

    var countsForConcentration: Bool {
        switch self {
        case .stablePositive, .stableNegative, .leverage:
            return true
        case .unstable:
            return false
        }
    }
}

enum DriverMoveDirection: String, Codable, Hashable {
    case up
    case down
    case flat

    var tint: Color {
        switch self {
        case .up: return AppTheme.vermilion
        case .down: return AppTheme.matcha
        case .flat: return AppTheme.mutedInk
        }
    }
}

struct ExposureHoldingEdge: Identifiable, Codable, Hashable {
    var id: String { "\(code)-\(kind.rawValue)-\(rhoText)" }
    var stockName: String
    var code: String
    var rhoText: String
    var kind: ExposureEdgeKind
    var stability: Double
    var blocks: [Double]
    var note: String

    var reliabilityText: String {
        if kind == .unstable { return "不计入集中度" }
        return "稳定性 \(String(format: "%.2f", stability))"
    }
}

struct ExposureDriver: Identifiable, Codable, Hashable {
    var id: String
    var symbolName: String
    var category: String
    var title: String
    var level: String
    var move: String
    var direction: DriverMoveDirection
    var subtitle: String
    var edges: [ExposureHoldingEdge]
    var aiNote: String
    var eventTitle: String
    var eventDetail: String
    var order: Int

    var reliableEdgeCount: Int {
        edges.filter(\.kind.countsForConcentration).count
    }

    var hasHiddenConcentration: Bool {
        reliableEdgeCount >= 2
    }
}

struct ExposureConcentration: Identifiable, Hashable {
    var id: String { driver.id }
    var driver: ExposureDriver
    var title: String
    var detail: String
}
