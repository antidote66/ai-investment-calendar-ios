import Foundation

enum MacroCalendarProvider {
    static func seedEvents() -> [CalendarEvent] {
        var events: [CalendarEvent] = []

        events += fomcEvents()
        events += usMacroSeeds()
        events += chinaMacroSeeds()

        return events
    }

    static func fetchOnlineEvents() async -> [CalendarEvent] {
        async let bls = BLSCalendarProvider.fetch()
        async let cpi = CPIActualProvider.fetchLatestEvent()
        var events = await bls
        if let cpi = await cpi {
            events.append(cpi)
        }
        return events
    }

    private static func fomcEvents() -> [CalendarEvent] {
        let source = URL(string: "https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm")
        let items: [(Date, String, String, Bool)] = [
            (DateKeys.date(2026, 1, 29, hour: 3), "FOMC 利率决议", "2026年1月27-28日会议，北京时间通常为结束次日凌晨。", false),
            (DateKeys.date(2026, 3, 19, hour: 2), "FOMC 利率决议 + SEP", "2026年3月17-18日会议，含经济预测摘要。", true),
            (DateKeys.date(2026, 4, 30, hour: 2), "FOMC 利率决议", "2026年4月28-29日会议。", false),
            (DateKeys.date(2026, 6, 18, hour: 2), "FOMC 利率决议 + SEP", "2026年6月16-17日会议，含经济预测摘要。", true),
            (DateKeys.date(2026, 7, 30, hour: 2), "FOMC 利率决议", "2026年7月28-29日会议。", false),
            (DateKeys.date(2026, 9, 17, hour: 2), "FOMC 利率决议 + SEP", "2026年9月15-16日会议，含经济预测摘要。", true),
            (DateKeys.date(2026, 10, 29, hour: 2), "FOMC 利率决议", "2026年10月27-28日会议。", false),
            (DateKeys.date(2026, 12, 10, hour: 3), "FOMC 利率决议 + SEP", "2026年12月8-9日会议，含经济预测摘要。", true)
        ]

        return items.map { date, title, detail, isProjection in
            CalendarEvent(
                id: "fomc-\(DateKeys.day.string(from: date))",
                title: title,
                detail: detail,
                date: date,
                category: .fomc,
                importance: isProjection ? .high : .normal,
                sourceName: "Federal Reserve",
                sourceURL: source,
                relatedCode: nil,
                createdAt: Date()
            )
        }
    }

    private static func usMacroSeeds() -> [CalendarEvent] {
        let source = URL(string: "https://www.bls.gov/schedule/2026/home.htm")
        let items: [(Date, EventCategory, String, String, EventImportance)] = [
            (DateKeys.date(2026, 6, 10, hour: 20, minute: 30), .cpi, "美国 CPI", "BLS 发布 2026年5月 CPI，8:30 ET。", .high),
            (DateKeys.date(2026, 6, 11, hour: 20, minute: 30), .usMacro, "美国 PPI", "BLS 发布 2026年5月 PPI，8:30 ET。", .normal),
            (DateKeys.date(2026, 6, 16, hour: 20, minute: 30), .usMacro, "美国进出口价格指数", "BLS 发布 2026年5月进口/出口价格指数。", .normal),
            (DateKeys.date(2026, 6, 30, hour: 22), .usMacro, "美国 JOLTS", "BLS 发布 2026年5月职位空缺和劳动力流动调查。", .normal),
            (DateKeys.date(2026, 7, 2, hour: 20, minute: 30), .usMacro, "美国非农就业", "BLS 发布 2026年6月就业形势。", .high),
            (DateKeys.date(2026, 7, 14, hour: 20, minute: 30), .cpi, "美国 CPI", "BLS 发布 2026年6月 CPI，8:30 ET。", .high),
            (DateKeys.date(2026, 8, 7, hour: 20, minute: 30), .usMacro, "美国非农就业", "BLS 发布 2026年7月就业形势。", .high),
            (DateKeys.date(2026, 9, 4, hour: 20, minute: 30), .usMacro, "美国非农就业", "BLS 发布 2026年8月就业形势。", .high),
            (DateKeys.date(2026, 10, 2, hour: 20, minute: 30), .usMacro, "美国非农就业", "BLS 发布 2026年9月就业形势。", .high),
            (DateKeys.date(2026, 10, 14, hour: 20, minute: 30), .cpi, "美国 CPI", "BLS 发布 2026年9月 CPI，8:30 ET。", .high),
            (DateKeys.date(2026, 11, 6, hour: 21, minute: 30), .usMacro, "美国非农就业", "BLS 发布 2026年10月就业形势。", .high),
            (DateKeys.date(2026, 11, 10, hour: 21, minute: 30), .cpi, "美国 CPI", "BLS 发布 2026年10月 CPI，8:30 ET。", .high),
            (DateKeys.date(2026, 12, 4, hour: 21, minute: 30), .usMacro, "美国非农就业", "BLS 发布 2026年11月就业形势。", .high),
            (DateKeys.date(2026, 12, 10, hour: 21, minute: 30), .cpi, "美国 CPI", "BLS 发布 2026年11月 CPI，8:30 ET。", .high)
        ]

        return items.map { date, category, title, detail, importance in
            CalendarEvent(
                id: "us-\(title)-\(DateKeys.day.string(from: date))",
                title: title,
                detail: detail,
                date: date,
                category: category,
                importance: importance,
                sourceName: "U.S. BLS",
                sourceURL: source,
                relatedCode: nil,
                createdAt: Date()
            )
        }
    }

    private static func chinaMacroSeeds() -> [CalendarEvent] {
        let source = URL(string: "https://www.stats.gov.cn/sj/fbrc/bnxxfb/")
        let items: [(Date, String, String, EventImportance)] = [
            (DateKeys.date(2026, 6, 10, hour: 9, minute: 30), "中国 CPI/PPI", "国家统计局发布 2026年5月居民消费价格和工业生产者出厂价格。", .high),
            (DateKeys.date(2026, 6, 16, hour: 10), "中国国民经济运行情况", "国家统计局月度国民经济运行新闻稿。", .high),
            (DateKeys.date(2026, 6, 30, hour: 9, minute: 30), "中国官方 PMI", "国家统计局发布制造业/非制造业 PMI。", .high),
            (DateKeys.date(2026, 7, 15, hour: 10), "中国国民经济运行情况", "国家统计局季度/月度国民经济运行新闻稿。", .high),
            (DateKeys.date(2026, 7, 31, hour: 9, minute: 30), "中国官方 PMI", "国家统计局发布制造业/非制造业 PMI。", .high),
            (DateKeys.date(2026, 8, 17, hour: 10), "中国国民经济运行情况", "国家统计局月度国民经济运行新闻稿。", .high),
            (DateKeys.date(2026, 8, 31, hour: 9, minute: 30), "中国官方 PMI", "国家统计局发布制造业/非制造业 PMI。", .high),
            (DateKeys.date(2026, 9, 15, hour: 10), "中国国民经济运行情况", "国家统计局月度国民经济运行新闻稿。", .high),
            (DateKeys.date(2026, 9, 30, hour: 9, minute: 30), "中国官方 PMI", "国家统计局发布制造业/非制造业 PMI。", .high),
            (DateKeys.date(2026, 10, 19, hour: 10), "中国国民经济运行情况", "国家统计局季度/月度国民经济运行新闻稿。", .high),
            (DateKeys.date(2026, 10, 31, hour: 9, minute: 30), "中国官方 PMI", "国家统计局发布制造业/非制造业 PMI。", .high),
            (DateKeys.date(2026, 11, 16, hour: 10), "中国国民经济运行情况", "国家统计局月度国民经济运行新闻稿。", .high),
            (DateKeys.date(2026, 11, 30, hour: 9, minute: 30), "中国官方 PMI", "国家统计局发布制造业/非制造业 PMI。", .high),
            (DateKeys.date(2026, 12, 15, hour: 10), "中国国民经济运行情况", "国家统计局月度国民经济运行新闻稿。", .high),
            (DateKeys.date(2026, 12, 31, hour: 9, minute: 30), "中国官方 PMI", "国家统计局发布制造业/非制造业 PMI。", .high)
        ]

        return items.map { date, title, detail, importance in
            CalendarEvent(
                id: "cn-\(title)-\(DateKeys.day.string(from: date))",
                title: title,
                detail: detail,
                date: date,
                category: .chinaMacro,
                importance: importance,
                sourceName: "国家统计局",
                sourceURL: source,
                relatedCode: nil,
                createdAt: Date()
            )
        }
    }
}

private enum CPIActualProvider {
    static func fetchLatestEvent() async -> CalendarEvent? {
        guard let seed = latestReleasedCPISeed() else { return nil }
        guard let summary = await fetchSummary() else { return nil }
        return CalendarEvent(
            id: "us-美国 CPI-\(DateKeys.day.string(from: seed.date))",
            title: "美国 CPI",
            detail: "\(seed.detail)\n已公布：\(summary)",
            date: seed.date,
            category: .cpi,
            importance: .high,
            sourceName: "U.S. BLS",
            sourceURL: URL(string: "https://www.bls.gov/news.release/cpi.nr0.htm"),
            relatedCode: nil,
            createdAt: Date()
        )
    }

    private static func latestReleasedCPISeed() -> CalendarEvent? {
        MacroCalendarProvider.seedEvents()
            .filter { $0.category == .cpi && $0.date <= Date() }
            .max(by: { $0.date < $1.date })
    }

    private static func fetchSummary() async -> String? {
        if let summary = await fetchFromAPI() {
            return summary
        }
        return await fetchFromNewsRelease()
    }

    private static func fetchFromAPI() async -> String? {
        let endYear = DateKeys.calendar.component(.year, from: Date())
        let startYear = endYear - 1
        async let nsaValues = fetchSeries("CUUR0000SA0", startYear: startYear, endYear: endYear)
        async let saValues = fetchSeries("CUSR0000SA0", startYear: startYear, endYear: endYear)
        async let coreValues = fetchSeries("CUSR0000SA0L1E", startYear: startYear, endYear: endYear)

        guard let nsa = await nsaValues,
              let latest = latestMonth(in: nsa),
              let latestValue = Double(latest.value),
              let yearAgo = point(in: nsa, year: latest.year - 1, month: latest.month),
              let yearAgoValue = Double(yearAgo.value) else {
            return nil
        }

        let yoy = (latestValue / yearAgoValue - 1) * 100
        let mom = monthChange(await saValues, year: latest.year, month: latest.month)
        let coreMom = monthChange(await coreValues, year: latest.year, month: latest.month)

        var parts = ["\(latest.year)年\(latest.month)月 CPI 同比 \(formatPercent(yoy))"]
        if let mom {
            parts.append("季调环比 \(formatPercent(mom))")
        }
        if let coreMom {
            parts.append("核心 CPI 环比 \(formatPercent(coreMom))")
        }
        return parts.joined(separator: "，")
    }

    private static func fetchSeries(_ seriesID: String, startYear: Int, endYear: Int) async -> [BLSDataPoint]? {
        var components = URLComponents(string: "https://api.bls.gov/publicAPI/v2/timeseries/data/\(seriesID)")
        components?.queryItems = [
            URLQueryItem(name: "startyear", value: "\(startYear)"),
            URLQueryItem(name: "endyear", value: "\(endYear)")
        ]
        guard let url = components?.url,
              let data = try? await WebClient.shared.data(from: url, timeout: 6),
              let response = try? JSONDecoder().decode(BLSTimeSeriesResponse.self, from: data),
              let firstSeries = response.results?.series.first else {
            return nil
        }
        return firstSeries.data
    }

    private static func fetchFromNewsRelease() async -> String? {
        guard let url = URL(string: "https://www.bls.gov/news.release/cpi.nr0.htm"),
              let html = try? await WebClient.shared.text(from: url, timeout: 8) else { return nil }
        let text = HTMLTools.decodeEntities(html.replacingOccurrences(of: "<[^>]+>", with: "\n", options: .regularExpression))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard let sentence = HTMLTools.matches("(The Consumer Price Index[^.]+\\.[^.]+12 months[^.]+\\.)", in: text).first?.last else {
            return nil
        }
        return sentence.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func latestMonth(in points: [BLSDataPoint]) -> BLSDataPoint? {
        points
            .filter { (1...12).contains($0.month) }
            .sorted {
                if $0.year == $1.year { return $0.month > $1.month }
                return $0.year > $1.year
            }
            .first
    }

    private static func point(in points: [BLSDataPoint], year: Int, month: Int) -> BLSDataPoint? {
        points.first { $0.year == year && $0.month == month }
    }

    private static func monthChange(_ points: [BLSDataPoint]?, year: Int, month: Int) -> Double? {
        guard let points,
              let current = point(in: points, year: year, month: month),
              let currentValue = Double(current.value) else { return nil }
        let previousMonth = month == 1 ? 12 : month - 1
        let previousYear = month == 1 ? year - 1 : year
        guard let previous = point(in: points, year: previousYear, month: previousMonth),
              let previousValue = Double(previous.value) else { return nil }
        return (currentValue / previousValue - 1) * 100
    }

    private static func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
}

private struct BLSTimeSeriesResponse: Decodable {
    var results: BLSResults?

    enum CodingKeys: String, CodingKey {
        case results = "Results"
    }
}

private struct BLSResults: Decodable {
    var series: [BLSSeries]
}

private struct BLSSeries: Decodable {
    var data: [BLSDataPoint]
}

private struct BLSDataPoint: Decodable {
    var yearRaw: String
    var period: String
    var value: String

    enum CodingKeys: String, CodingKey {
        case yearRaw = "year"
        case period
        case value
    }

    var year: Int {
        Int(yearRaw) ?? 0
    }

    var month: Int {
        guard period.hasPrefix("M") else { return 0 }
        return Int(period.dropFirst()) ?? 0
    }
}

private enum BLSCalendarProvider {
    static func fetch() async -> [CalendarEvent] {
        guard let url = URL(string: "https://www.bls.gov/schedule/2026/home.htm") else { return [] }
        guard let text = try? await WebClient.shared.text(from: url, timeout: 8) else { return [] }
        let plain = HTMLTools.decodeEntities(text.replacingOccurrences(of: "<[^>]+>", with: "\n", options: .regularExpression))
        let lines = plain
            .components(separatedBy: .newlines)
            .map {
                $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "America/New_York")
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy h:mm a"

        var results: [CalendarEvent] = []
        for index in lines.indices {
            guard lines[index].range(of: #"^[A-Za-z]+, [A-Za-z]+ [0-9]{1,2}, 2026$"#, options: .regularExpression) != nil else { continue }
            guard index + 2 < lines.count else { continue }
            let time = lines[index + 1]
            let release = lines[index + 2]
            let important = release.contains("Consumer Price Index")
                || release.contains("Employment Situation")
                || release.contains("Producer Price Index")
                || release.contains("Job Openings and Labor Turnover")
            guard important, let etDate = dateFormatter.date(from: "\(lines[index]) \(time)") else { continue }
            let category: EventCategory = release.contains("Consumer Price Index") ? .cpi : .usMacro
            let importance: EventImportance = release.contains("Consumer Price Index") || release.contains("Employment Situation") ? .high : .normal
            results.append(
                CalendarEvent(
                    id: "bls-\(release)-\(DateKeys.day.string(from: etDate))",
                    title: release.replacingOccurrences(of: " for ", with: " "),
                    detail: "BLS 官方发布日程，时间为 \(time) ET。",
                    date: etDate,
                    category: category,
                    importance: importance,
                    sourceName: "U.S. BLS",
                    sourceURL: url,
                    relatedCode: nil,
                    createdAt: Date()
                )
            )
        }
        return results
    }
}
