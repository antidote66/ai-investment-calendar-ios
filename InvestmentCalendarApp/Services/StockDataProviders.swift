import Foundation

enum StockLookupProvider {
    static func resolveAStock(keyword: String) async -> WatchStock? {
        let cleaned = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        if cleaned.range(of: #"^\d{6}$"#, options: .regularExpression) != nil {
            return WatchStock(name: cleaned, code: cleaned, market: .aShare)
        }

        var components = URLComponents(string: "https://searchapi.eastmoney.com/api/suggest/get")
        components?.queryItems = [
            URLQueryItem(name: "input", value: cleaned),
            URLQueryItem(name: "type", value: "14"),
            URLQueryItem(name: "token", value: "D43BF722C8E33BD840A95C9F5E6D620A")
        ]
        guard let url = components?.url,
              let data = try? await WebClient.shared.data(from: url, timeout: 8),
              let response = try? JSONDecoder().decode(EastMoneySuggestResponse.self, from: data),
              let item = response.quotationCodeTable?.data.first(where: { $0.classify == "AStock" || $0.securityTypeName.contains("A") }) else {
            return nil
        }

        return WatchStock(name: item.name, code: item.code, market: .aShare)
    }
}

enum AStockReportCalendarProvider {
    static func fetch(for stocks: [WatchStock]) async -> [CalendarEvent] {
        let aShares = stocks.filter { $0.market == .aShare }
        guard !aShares.isEmpty else { return [] }

        return await withTaskGroup(of: [CalendarEvent].self) { group in
            for stock in aShares {
                for period in reportPeriods() {
                    group.addTask {
                        await fetch(stock: stock, reportDate: period)
                    }
                }
            }

            var events: [CalendarEvent] = []
            for await partial in group {
                events += partial
            }
            return events
        }
    }

    private static func fetch(stock: WatchStock, reportDate: String) async -> [CalendarEvent] {
        let reportDateValue = "\(reportDate.prefix(4))-\(reportDate.dropFirst(4).prefix(2))-\(reportDate.suffix(2))"
        var components = URLComponents(string: "https://datacenter-web.eastmoney.com/api/data/v1/get")
        components?.queryItems = [
            URLQueryItem(name: "sortColumns", value: "FIRST_APPOINT_DATE,SECURITY_CODE"),
            URLQueryItem(name: "sortTypes", value: "1,1"),
            URLQueryItem(name: "pageSize", value: "50"),
            URLQueryItem(name: "pageNumber", value: "1"),
            URLQueryItem(name: "reportName", value: "RPT_PUBLIC_BS_APPOIN"),
            URLQueryItem(name: "columns", value: "ALL"),
            URLQueryItem(
                name: "filter",
                value: "(SECURITY_TYPE_CODE in (\"058001001\",\"058001008\"))(TRADE_MARKET_CODE!=\"069001017\")(REPORT_DATE='\(reportDateValue)')(SECURITY_CODE=\"\(stock.code)\")"
            )
        ]

        guard let url = components?.url,
              let data = try? await WebClient.shared.data(from: url, timeout: 8),
              let response = try? JSONDecoder().decode(EastMoneyReportDateResponse.self, from: data),
              let rows = response.result?.data,
              !rows.isEmpty else {
            return []
        }

        return rows.compactMap { row in
            guard row.securityCode == stock.code,
                  let date = eventDate(for: row) else { return nil }
            let actual = cleanDate(row.actualPublishDate)
            let appoint = cleanDate(row.appointPublishDate) ?? cleanDate(row.firstAppointDate)
            var fragments = ["\(row.reportTypeName ?? "财报")"]
            if let appoint {
                fragments.append("预约披露 \(appoint)")
            }
            if let actual {
                fragments.append("实际披露 \(actual)")
            }
            if let changed = latestChangedDate(row) {
                fragments.append("变更至 \(changed)")
            }

            let titlePrefix = row.isPublish == "1" ? "已披露" : "预约披露"
            return CalendarEvent(
                id: "report-\(stock.code)-\(reportDate)-\(DateKeys.day.string(from: date))",
                title: "\(stock.name) \(titlePrefix)\(row.reportTypeName ?? "财报")",
                detail: fragments.joined(separator: " · "),
                date: date,
                category: .stockCalendar,
                importance: .high,
                sourceName: "东方财富预约披露",
                sourceURL: URL(string: "https://data.eastmoney.com/bbsj/\(String(reportDate.prefix(6)))/yysj.html"),
                relatedCode: stock.code,
                createdAt: Date()
            )
        }
    }

    private static func reportPeriods() -> [String] {
        let year = DateKeys.calendar.component(.year, from: Date())
        return [
            "\(year - 1)1231",
            "\(year)0331",
            "\(year)0630",
            "\(year)0930",
            "\(year)1231"
        ]
    }

    private static func eventDate(for row: EastMoneyReportDate) -> Date? {
        parseDate(row.actualPublishDate)
            ?? parseDate(row.appointPublishDate)
            ?? parseDate(row.thirdChangeDate)
            ?? parseDate(row.secondChangeDate)
            ?? parseDate(row.firstChangeDate)
            ?? parseDate(row.firstAppointDate)
    }

    private static func latestChangedDate(_ row: EastMoneyReportDate) -> String? {
        cleanDate(row.thirdChangeDate)
            ?? cleanDate(row.secondChangeDate)
            ?? cleanDate(row.firstChangeDate)
    }

    private static func cleanDate(_ raw: String?) -> String? {
        guard let date = parseDate(raw) else { return nil }
        return DateKeys.day.string(from: date)
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = DateKeys.calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: raw)
    }
}

private struct EastMoneySuggestResponse: Decodable {
    var quotationCodeTable: SuggestTable?

    enum CodingKeys: String, CodingKey {
        case quotationCodeTable = "QuotationCodeTable"
    }
}

private struct SuggestTable: Decodable {
    var data: [SuggestStock]

    enum CodingKeys: String, CodingKey {
        case data = "Data"
    }
}

private struct SuggestStock: Decodable {
    var code: String
    var name: String
    var classify: String
    var securityTypeName: String

    enum CodingKeys: String, CodingKey {
        case code = "Code"
        case name = "Name"
        case classify = "Classify"
        case securityTypeName = "SecurityTypeName"
    }
}

private struct EastMoneyReportDateResponse: Decodable {
    var result: EastMoneyReportDateResult?
}

private struct EastMoneyReportDateResult: Decodable {
    var data: [EastMoneyReportDate]
}

private struct EastMoneyReportDate: Decodable {
    var securityCode: String
    var reportTypeName: String?
    var firstAppointDate: String?
    var firstChangeDate: String?
    var secondChangeDate: String?
    var thirdChangeDate: String?
    var actualPublishDate: String?
    var appointPublishDate: String?
    var isPublish: String?

    enum CodingKeys: String, CodingKey {
        case securityCode = "SECURITY_CODE"
        case reportTypeName = "REPORT_TYPE_NAME"
        case firstAppointDate = "FIRST_APPOINT_DATE"
        case firstChangeDate = "FIRST_CHANGE_DATE"
        case secondChangeDate = "SECOND_CHANGE_DATE"
        case thirdChangeDate = "THIRD_CHANGE_DATE"
        case actualPublishDate = "ACTUAL_PUBLISH_DATE"
        case appointPublishDate = "APPOINT_PUBLISH_DATE"
        case isPublish = "IS_PUBLISH"
    }
}
