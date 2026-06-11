import Foundation

enum AnnouncementProvider {
    static func fetch(for stocks: [WatchStock]) async -> [CalendarEvent] {
        async let reportDates = AStockReportCalendarProvider.fetch(for: stocks)
        let announcements = await withTaskGroup(of: [CalendarEvent].self) { group in
            for stock in stocks {
                group.addTask {
                    switch stock.market {
                    case .aShare:
                        return await EastMoneyAnnouncementProvider.fetch(stock: stock)
                    case .hk:
                        return await HKEXAnnouncementProvider.fetch(stock: stock)
                    }
                }
            }

            var events: [CalendarEvent] = []
            for await partial in group {
                events += partial
            }
            return events
        }
        return announcements + (await reportDates)
    }
}

private enum EastMoneyAnnouncementProvider {
    static func fetch(stock: WatchStock) async -> [CalendarEvent] {
        var components = URLComponents(string: "https://np-anotice-stock.eastmoney.com/api/security/ann")
        components?.queryItems = [
            URLQueryItem(name: "sr", value: "-1"),
            URLQueryItem(name: "page_size", value: "40"),
            URLQueryItem(name: "page_index", value: "1"),
            URLQueryItem(name: "ann_type", value: "A"),
            URLQueryItem(name: "client_source", value: "web"),
            URLQueryItem(name: "stock_list", value: stock.code)
        ]
        guard let url = components?.url else { return [] }
        guard let data = try? await WebClient.shared.data(from: url, timeout: 8) else { return [] }
        guard let response = try? JSONDecoder().decode(EastMoneyResponse.self, from: data) else { return [] }

        return response.data?.list.compactMap { item in
            let title = item.titleCh ?? item.title
            guard isRelevant(title: title) else { return nil }
            let date = parseEastMoneyDate(item.noticeDate) ?? parseEastMoneyDate(item.displayTime) ?? Date()
            let link = URL(string: "https://data.eastmoney.com/notices/detail/\(stock.code)/\(item.artCode).html")
            return CalendarEvent(
                id: "em-\(item.artCode)",
                title: title,
                detail: "\(stock.name) \(stock.code) · \(item.columns.map(\.columnName).joined(separator: " / "))",
                date: date,
                category: .announcement,
                importance: importance(title: title),
                sourceName: "东方财富公告",
                sourceURL: link,
                relatedCode: stock.code,
                createdAt: Date()
            )
        } ?? []
    }

    private static func parseEastMoneyDate(_ raw: String) -> Date? {
        let normalized = raw.replacingOccurrences(of: #":\d{3}$"#, with: "", options: .regularExpression)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = DateKeys.calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: normalized)
    }
}

private enum HKEXAnnouncementProvider {
    static func fetch(stock: WatchStock) async -> [CalendarEvent] {
        guard let hkexStockId = stock.hkexStockId, !hkexStockId.isEmpty else { return [] }
        let to = Date()
        let from = DateKeys.calendar.date(byAdding: .day, value: -365, to: to) ?? to
        let queryFormatter = DateFormatter()
        queryFormatter.calendar = DateKeys.calendar
        queryFormatter.locale = Locale(identifier: "en_US_POSIX")
        queryFormatter.timeZone = DateKeys.calendar.timeZone
        queryFormatter.dateFormat = "yyyyMMdd"

        var components = URLComponents(string: "https://www1.hkexnews.hk/search/titlesearch.xhtml")
        components?.queryItems = [
            URLQueryItem(name: "MB-Daterange", value: "0"),
            URLQueryItem(name: "category", value: "0"),
            URLQueryItem(name: "documentType", value: ""),
            URLQueryItem(name: "from", value: queryFormatter.string(from: from)),
            URLQueryItem(name: "lang", value: "ZH"),
            URLQueryItem(name: "market", value: "SEHK"),
            URLQueryItem(name: "searchType", value: "0"),
            URLQueryItem(name: "stockId", value: hkexStockId),
            URLQueryItem(name: "title", value: ""),
            URLQueryItem(name: "to", value: queryFormatter.string(from: to))
        ]
        guard let url = components?.url else { return [] }
        guard let html = try? await WebClient.shared.text(from: url, timeout: 8) else { return [] }

        let rows = HTMLTools.matches("<tr>(.*?)</tr>", in: html).compactMap { $0.count > 1 ? $0[1] : nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = DateKeys.calendar.timeZone
        formatter.dateFormat = "dd/MM/yyyy HH:mm"

        return rows.compactMap { row in
            guard row.contains("release-time") else { return nil }
            let releaseTime = firstMatch(#"release-time[^>]*>.*?</span>(.*?)</td>"#, row)
            let headline = firstMatch(#"<div class="headline">(.*?)</div>"#, row)
            let linkPath = firstMatch(#"<a href="([^"]+)""#, row)
            let linkTitle = firstMatch(#"<a href="[^"]+"[^>]*>(.*?)</a>"#, row)
            let title = HTMLTools.stripTags(linkTitle.isEmpty ? headline : linkTitle)
            guard !title.isEmpty, isRelevant(title: title) else { return nil }
            let date = formatter.date(from: HTMLTools.stripTags(releaseTime)) ?? Date()
            let absolute = linkPath.hasPrefix("http") ? linkPath : "https://www1.hkexnews.hk\(linkPath)"
            return CalendarEvent(
                id: "hkex-\(stock.code)-\(DateKeys.day.string(from: date))-\(stableID(title))",
                title: "\(stock.name): \(title)",
                detail: HTMLTools.stripTags(headline),
                date: date,
                category: .announcement,
                importance: importance(title: title),
                sourceName: "HKEXnews",
                sourceURL: URL(string: absolute),
                relatedCode: stock.code,
                createdAt: Date()
            )
        }
    }

    private static func firstMatch(_ pattern: String, _ text: String) -> String {
        HTMLTools.matches(pattern, in: text).first.flatMap { $0.count > 1 ? $0[1] : nil } ?? ""
    }

    private static func stableID(_ value: String) -> String {
        value.unicodeScalars
            .map { String($0.value, radix: 16) }
            .joined(separator: "-")
            .prefix(80)
            .description
    }
}

private func isRelevant(title: String) -> Bool {
    if isLowSignalDisclosure(title: title) { return false }
    if importance(title: title) == .high { return true }
    let keywords = ["重大合同", "合同", "中标", "订单", "定期报告", "业绩", "業績", "年度", "季度", "半年报", "分红", "分派", "收购", "出售", "重组", "停牌", "复牌"]
    return keywords.contains { title.localizedCaseInsensitiveContains($0) }
}

private func importance(title: String) -> EventImportance {
    let high = ["重大合同", "合同", "中标", "中選", "中选", "订单", "定期报告", "业绩", "業績", "年报", "年度报告", "半年报", "半年度报告", "季报", "季度报告", "业绩预告", "業績預告", "业绩快报", "利润分配", "分红", "权益分派", "收购", "出售", "资产重组", "重大资产", "停牌", "复牌", "股份回购方案", "股份回購方案"]
    if high.contains(where: { title.localizedCaseInsensitiveContains($0) }) {
        return .high
    }
    return .normal
}

private func isLowSignalDisclosure(title: String) -> Bool {
    let lowSignal = [
        "翌日披露报表", "翌日披露報表", "证券变动月报表", "證券變動月報表", "月报表", "月報表",
        "担保", "擔保", "关联交易", "關連交易", "关联方", "關連方",
        "股东大会", "股東大會", "股東週年大會", "董事会", "董事會", "监事会", "監事會",
        "独立董事", "獨立董事", "法律意见书", "法律意見書"
    ]
    return lowSignal.contains { title.localizedCaseInsensitiveContains($0) }
}

private struct EastMoneyResponse: Decodable {
    var data: EastMoneyData?
}

private struct EastMoneyData: Decodable {
    var list: [EastMoneyAnnouncement]
}

private struct EastMoneyAnnouncement: Decodable {
    var artCode: String
    var displayTime: String
    var noticeDate: String
    var title: String
    var titleCh: String?
    var columns: [EastMoneyColumn]

    enum CodingKeys: String, CodingKey {
        case artCode = "art_code"
        case displayTime = "display_time"
        case noticeDate = "notice_date"
        case title
        case titleCh = "title_ch"
        case columns
    }
}

private struct EastMoneyColumn: Decodable {
    var columnName: String

    enum CodingKeys: String, CodingKey {
        case columnName = "column_name"
    }
}
