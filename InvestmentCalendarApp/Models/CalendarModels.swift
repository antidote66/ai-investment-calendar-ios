import Foundation
import SwiftUI

enum EventCategory: String, Codable, CaseIterable, Identifiable {
    case fomc
    case usMacro
    case chinaMacro
    case cpi
    case announcement
    case stockCalendar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fomc: return "美联储"
        case .usMacro: return "美国宏观"
        case .chinaMacro: return "中国宏观"
        case .cpi: return "CPI"
        case .announcement: return "个股公告"
        case .stockCalendar: return "披露日期"
        }
    }

    var symbolName: String {
        switch self {
        case .fomc: return "building.columns"
        case .usMacro: return "chart.line.uptrend.xyaxis"
        case .chinaMacro: return "chart.bar.doc.horizontal"
        case .cpi: return "percent"
        case .announcement: return "doc.text"
        case .stockCalendar: return "calendar.badge.clock"
        }
    }

    var tint: Color {
        switch self {
        case .fomc: return AppTheme.sumiBlue
        case .usMacro: return Color(red: 0.286, green: 0.470, blue: 0.682)
        case .chinaMacro: return AppTheme.vermilion
        case .cpi: return AppTheme.amber
        case .announcement: return AppTheme.matcha
        case .stockCalendar: return Color(red: 0.500, green: 0.365, blue: 0.552)
        }
    }
}

enum EventImportance: String, Codable, Comparable {
    case low
    case normal
    case high

    static func < (lhs: EventImportance, rhs: EventImportance) -> Bool {
        rank(lhs) < rank(rhs)
    }

    private static func rank(_ value: EventImportance) -> Int {
        switch value {
        case .low: return 0
        case .normal: return 1
        case .high: return 2
        }
    }

    var label: String {
        switch self {
        case .low: return "一般"
        case .normal: return "关注"
        case .high: return "重要"
        }
    }
}

struct CalendarEvent: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var detail: String
    var date: Date
    var category: EventCategory
    var importance: EventImportance
    var sourceName: String
    var sourceURL: URL?
    var relatedCode: String?
    var createdAt: Date

    var dayKey: String {
        DateKeys.day.string(from: date)
    }
}

enum Market: String, Codable, CaseIterable, Identifiable {
    case aShare = "A股"
    case hk = "港股"

    var id: String { rawValue }
}

struct WatchStock: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var code: String
    var market: Market
    var hkexStockId: String?

    init(id: UUID = UUID(), name: String, code: String, market: Market, hkexStockId: String? = nil) {
        self.id = id
        self.name = name
        self.code = code
        self.market = market
        self.hkexStockId = hkexStockId
    }

    var displayCode: String {
        switch market {
        case .aShare: return code
        case .hk: return code.hasPrefix("0") ? code : String(format: "%05d", Int(code) ?? 0)
        }
    }

    static let defaults: [WatchStock] = [
        WatchStock(name: "腾讯控股", code: "00700", market: .hk, hkexStockId: "7609"),
        WatchStock(name: "宁德时代", code: "300750", market: .aShare),
        WatchStock(name: "紫金矿业", code: "601899", market: .aShare),
        WatchStock(name: "洛阳钼业", code: "603993", market: .aShare),
        WatchStock(name: "三美股份", code: "603379", market: .aShare)
    ]
}

enum MarginTemperature: String, Codable {
    case cool
    case warming
    case crowded
    case unavailable

    var title: String {
        switch self {
        case .cool: return "低温"
        case .warming: return "升温"
        case .crowded: return "拥挤"
        case .unavailable: return "缺数据"
        }
    }

    var tint: Color {
        switch self {
        case .cool: return AppTheme.matcha
        case .warming: return AppTheme.amber
        case .crowded: return AppTheme.vermilion
        case .unavailable: return AppTheme.mutedInk
        }
    }
}

struct MarginSnapshot: Identifiable, Codable, Hashable {
    var id: String { code }
    var code: String
    var name: String
    var date: Date
    var financingBalance: Double
    var marginBalance: Double
    var shortBalance: Double
    var shortVolume: Double
    var financingBuy: Double
    var financingRepay: Double
    var financingNetBuy: Double
    var financingNetBuy5D: Double
    var financingNetBuy10D: Double
    var financingBalanceRatio: Double?
    var financingBalanceRatioPercentile: Double?
    var closingPrice: Double?
    var priceChangePercent: Double?
    var temperatureScore: Double
    var sourceName: String
    var sourceURL: URL?
    var updatedAt: Date

    var temperature: MarginTemperature {
        if temperatureScore >= 68 { return .crowded }
        if temperatureScore >= 42 { return .warming }
        return .cool
    }

    var dateText: String {
        DateKeys.day.string(from: date)
    }
}

enum DateKeys {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return calendar
    }()

    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let displayDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()

    static let monthTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: year, month: month, day: day, hour: hour, minute: minute)) ?? Date()
    }
}
