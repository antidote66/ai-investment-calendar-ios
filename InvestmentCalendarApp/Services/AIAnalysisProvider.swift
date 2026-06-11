import Foundation
import Security

enum AIProviderKind: String, Codable, CaseIterable, Identifiable {
    case localRule
    case gemini
    case deepSeek
    case kimi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .localRule: return "本地规则"
        case .gemini: return "Gemini"
        case .deepSeek: return "DeepSeek"
        case .kimi: return "Kimi"
        }
    }

    var displayTitle: String {
        switch self {
        case .gemini: return "Gemini（推荐）"
        default: return title
        }
    }

    var detail: String {
        switch self {
        case .localRule:
            return "不需要 API Key，稳定兜底，适合日常事件排序。"
        case .gemini:
            return "Google 官方 API，有 Free Tier，适合作为个人版默认云端 AI。"
        case .deepSeek:
            return "OpenAI 兼容接口，成本低，但通常需要付费余额。"
        case .kimi:
            return "Moonshot/Kimi API，中文体验好，通常需要开放平台 Key。"
        }
    }

    var requiresAPIKey: Bool {
        self != .localRule
    }

    var modelName: String {
        switch self {
        case .localRule: return "local"
        case .gemini: return "gemini-2.5-flash"
        case .deepSeek: return "deepseek-chat"
        case .kimi: return "kimi-k2.6"
        }
    }
}

struct AIInsight: Codable, Equatable {
    var headline: String
    var badge: String
    var regime: String
    var intensity: String
    var nextNode: String
    var holdingImpact: String
    var filterRule: String
    var mapSummary: String
    var risks: [String]
    var sourceNote: String
    var updatedAt: Date

    static let empty = AIInsight(
        headline: "正在建立事件链，先用本地规则筛出真正会改变预期的节点。",
        badge: "本地规则",
        regime: "初始化",
        intensity: "低",
        nextNode: "等待宏观日历和自选股公告更新。",
        holdingImpact: "先按披露日期、重大合同、业绩和宏观节点建立观察顺序。",
        filterRule: "担保、关联交易和普通材料不进入主屏重大事项。",
        mapSummary: "联动图谱会把自选股映射到利率、商品、产业价格和公告驱动。",
        risks: [],
        sourceNote: "AI 来源：本地规则；无需网络和 API Key。",
        updatedAt: Date()
    )
}

enum AIProviderKeychain {
    private static let service = "com.andyyu.InvestmentCalendar.ai"

    static func read(for provider: AIProviderKind) -> String? {
        guard provider.requiresAPIKey else { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    static func hasKey(for provider: AIProviderKind) -> Bool {
        read(for: provider) != nil
    }

    static func save(_ value: String, for provider: AIProviderKind) {
        guard provider.requiresAPIKey else { return }
        delete(for: provider)

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8) else { return }

        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        SecItemAdd(item as CFDictionary, nil)
    }

    static func delete(for provider: AIProviderKind) {
        guard provider.requiresAPIKey else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum AIAnalysisProvider {
    static func analyze(
        events: [CalendarEvent],
        watchlist: [WatchStock],
        marginSnapshots: [String: MarginSnapshot] = [:],
        provider: AIProviderKind
    ) async -> AIInsight {
        if provider == .localRule {
            return localInsight(events: events, watchlist: watchlist, marginSnapshots: marginSnapshots)
        }

        guard let apiKey = AIProviderKeychain.read(for: provider) else {
            var fallback = localInsight(events: events, watchlist: watchlist, marginSnapshots: marginSnapshots)
            fallback.badge = "本地兜底"
            fallback.sourceNote = "AI 来源：未配置 \(provider.title) API Key，当前使用本地规则。"
            return fallback
        }

        do {
            return try await remoteInsight(
                events: events,
                watchlist: watchlist,
                marginSnapshots: marginSnapshots,
                provider: provider,
                apiKey: apiKey
            )
        } catch {
            var fallback = localInsight(events: events, watchlist: watchlist, marginSnapshots: marginSnapshots)
            fallback.badge = "本地兜底"
            fallback.sourceNote = "AI 来源：\(provider.title) 暂不可用，已回落到本地规则。"
            fallback.risks = ["云端 AI 调用失败：\(error.localizedDescription)"] + fallback.risks
            return fallback
        }
    }

    static func localInsight(
        events: [CalendarEvent],
        watchlist: [WatchStock],
        marginSnapshots: [String: MarginSnapshot] = [:]
    ) -> AIInsight {
        let focus = upcomingFocusEvents(events: events, limit: 6)
        let stockEvent = focus.first { $0.category == .announcement || $0.category == .stockCalendar }
        let fomc = focus.first { $0.category == .fomc }
        let firstFocus = focus.first
        let hottestMargin = marginSnapshots.values.sorted { $0.temperatureScore > $1.temperatureScore }.first
        let latestReleasedCPI = events
            .filter { $0.category == .cpi && $0.date <= Date() && $0.detail.contains("已公布") }
            .sorted { $0.date > $1.date }
            .first

        let headline: String
        let regime: String
        let intensity: String
        if let hottestMargin, hottestMargin.temperature == .crowded {
            headline = "\(hottestMargin.name) 两融杠杆温度已到拥挤区，先看融资净买入是否在事件日前继续推高。"
            regime = "杠杆拥挤"
            intensity = "高"
        } else if let stockEvent {
            headline = "先处理真正改变预期的公告，再看宏观节点。重点是重大合同、定期报告、业绩、分红、重组和停复牌。"
            regime = "公告优先"
            intensity = stockEvent.importance == .high ? "高" : "中"
        } else if fomc != nil {
            headline = "当前进入事件验证期。CPI 落地后，真正把数据翻译成市场后果的是 FOMC 和点阵图。"
            regime = "等待验证"
            intensity = "中高"
        } else if latestReleasedCPI != nil {
            headline = "通胀数据已落地，短线不再只看单点 CPI，下一步看利率预期和持仓暴露是否同向。"
            regime = "消化数据"
            intensity = "中"
        } else {
            headline = "本周没有特别集中的强触发，日历进入低噪音跟踪模式，重点看自选股披露日期。"
            regime = "常规跟踪"
            intensity = "低"
        }

        let nextNode: String
        if let fomc {
            nextNode = "\(shortDate(fomc.date)) \(fomc.title)：确认利率路径和 SEP，优先级高于普通宏观数据。"
        } else if let firstFocus {
            nextNode = "\(shortDate(firstFocus.date)) \(firstFocus.title)：先看它是否改变持仓假设。"
        } else {
            nextNode = "暂无强节点，等待新的公告、披露日期或宏观发布。"
        }

        let names = Set(watchlist.map(\.name))
        let hasResources = !names.isDisjoint(with: Set(["紫金矿业", "洛阳钼业"]))
        let hasDuration = !names.isDisjoint(with: Set(["腾讯控股", "宁德时代"]))
        let holdingImpact: String
        if let hottestMargin, hottestMargin.temperature != .cool {
            holdingImpact = "\(hottestMargin.name) 当前融资余额占流通市值约 \(formatPercent(hottestMargin.financingBalanceRatio))，近10日融资净买入 \(formatAmount(hottestMargin.financingNetBuy10D))；这是事件前后最需要盯的杠杆变量。"
        } else if hasResources && hasDuration {
            holdingImpact = "资源股和久期资产看似分散，但都可能受实际利率节点影响；这是罗盘里的隐藏集中度逻辑。"
        } else if hasResources {
            holdingImpact = "资源股优先看铜、金、美元和实际利率，不只看公司公告本身。"
        } else if hasDuration {
            holdingImpact = "腾讯、宁德这类久期资产对利率预期更敏感，事件日前后少追涨。"
        } else {
            holdingImpact = "先按公告和财报披露建立事件链，再逐步接入宏观驱动。"
        }

        return AIInsight(
            headline: headline,
            badge: "本地规则",
            regime: regime,
            intensity: intensity,
            nextNode: nextNode,
            holdingImpact: holdingImpact,
            filterRule: "低相关宏观只保留日历圆点；与自选股、利率、通胀、业绩、重大合同或两融杠杆相关的事项才进入主屏。",
            mapSummary: mapSummary(for: watchlist, marginSnapshots: marginSnapshots),
            risks: riskNotes(for: focus, watchlist: watchlist, marginSnapshots: marginSnapshots),
            sourceNote: "AI 来源：本地规则；无需网络和 API Key。",
            updatedAt: Date()
        )
    }

    private static func remoteInsight(
        events: [CalendarEvent],
        watchlist: [WatchStock],
        marginSnapshots: [String: MarginSnapshot],
        provider: AIProviderKind,
        apiKey: String
    ) async throws -> AIInsight {
        let prompt = prompt(events: events, watchlist: watchlist, marginSnapshots: marginSnapshots)
        let text: String
        switch provider {
        case .gemini:
            text = try await callGemini(prompt: prompt, apiKey: apiKey, model: provider.modelName)
        case .deepSeek:
            text = try await callOpenAICompatible(
                prompt: prompt,
                apiKey: apiKey,
                model: provider.modelName,
                endpoint: URL(string: "https://api.deepseek.com/chat/completions")!
            )
        case .kimi:
            text = try await callOpenAICompatible(
                prompt: prompt,
                apiKey: apiKey,
                model: provider.modelName,
                endpoint: URL(string: "https://api.moonshot.cn/v1/chat/completions")!
            )
        case .localRule:
            return localInsight(events: events, watchlist: watchlist, marginSnapshots: marginSnapshots)
        }

        return try decodeRemoteInsight(
            text,
            provider: provider,
            fallback: localInsight(events: events, watchlist: watchlist, marginSnapshots: marginSnapshots)
        )
    }

    private static func prompt(events: [CalendarEvent], watchlist: [WatchStock], marginSnapshots: [String: MarginSnapshot]) -> String {
        let focus = upcomingFocusEvents(events: events, limit: 12)
        let eventLines = focus.map { event in
            "- \(DateKeys.day.string(from: event.date)) [\(event.category.title)/\(event.importance.label)] \(event.title)：\(event.detail)"
        }.joined(separator: "\n")
        let stockLines = watchlist.map { "- \($0.name) \($0.displayCode) \($0.market.rawValue)" }.joined(separator: "\n")
        let marginLines = watchlist.compactMap { stock -> String? in
            guard let snapshot = marginSnapshots[stock.code] else { return nil }
            return "- \(stock.name) \(snapshot.dateText)：两融温度 \(snapshot.temperature.title)，融资余额 \(formatAmount(snapshot.financingBalance))，融资余额占流通市值 \(formatPercent(snapshot.financingBalanceRatio))，近10日融资净买入 \(formatAmount(snapshot.financingNetBuy10D))"
        }.joined(separator: "\n")

        return """
        你是一个只服务个人投资日历的投研 AI。请根据已抓取事件做简洁研判，不要编造没有提供的数据或日期。

        当前日期：\(DateKeys.day.string(from: Date()))

        自选股：
        \(stockLines.isEmpty ? "- 暂无" : stockLines)

        重大事件：
        \(eventLines.isEmpty ? "- 未来三周暂无高优先级事项" : eventLines)

        A股融资融券：
        \(marginLines.isEmpty ? "- 暂无可用两融数据；港股不要套用A股两融口径。" : marginLines)

        规则：
        1. 重点看重大合同、中标订单、定期报告、业绩预告/快报、分红、重组、停复牌、CPI、FOMC 和高优先级宏观数据。
        2. 担保、关联交易、普通会议材料、月报表等低信号公告不要放大。
        3. 融资融券是资金拥挤核心信号；事件日前融资净买入快速增加、融资余额占流通市值升高、股价滞涨但融资增加，都要提示。
        4. 输出必须是 JSON，不要 Markdown，不要解释。
        5. 字段必须包含 headline, badge, regime, intensity, nextNode, holdingImpact, filterRule, mapSummary, risks。
        6. risks 是 0 到 3 条中文字符串数组。
        """
    }

    private static func callGemini(prompt: String, apiKey: String, model: String) async throws -> String {
        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components?.url else { throw AIProviderError.badURL }

        let body = GeminiRequest(
            contents: [GeminiContent(parts: [GeminiPart(text: prompt)])],
            generationConfig: GeminiGenerationConfig(temperature: 0.2, responseMimeType: "application/json")
        )
        var request = URLRequest(url: url, timeoutInterval: 24)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let data = try await validatedData(for: request)
        let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = response.candidates.first?.content.parts.first?.text, !text.isEmpty else {
            throw AIProviderError.emptyResponse
        }
        return text
    }

    private static func callOpenAICompatible(prompt: String, apiKey: String, model: String, endpoint: URL) async throws -> String {
        let body = ChatCompletionRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: "你是一个中文投研日历 AI，只输出 JSON。"),
                ChatMessage(role: "user", content: prompt)
            ],
            temperature: 0.2
        )

        var request = URLRequest(url: endpoint, timeoutInterval: 24)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let data = try await validatedData(for: request)
        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let text = response.choices.first?.message.content, !text.isEmpty else {
            throw AIProviderError.emptyResponse
        }
        return text
    }

    private static func validatedData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return data }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIProviderError.http(http.statusCode, String(body.prefix(180)))
        }
        return data
    }

    private static func decodeRemoteInsight(_ text: String, provider: AIProviderKind, fallback: AIInsight) throws -> AIInsight {
        guard let json = extractJSONObject(from: text),
              let data = json.data(using: .utf8) else {
            throw AIProviderError.invalidJSON
        }
        let decoded = try JSONDecoder().decode(RemoteInsight.self, from: data)
        return AIInsight(
            headline: cleaned(decoded.headline, fallback: fallback.headline),
            badge: cleaned(decoded.badge, fallback: provider.title),
            regime: cleaned(decoded.regime, fallback: fallback.regime),
            intensity: cleaned(decoded.intensity, fallback: fallback.intensity),
            nextNode: cleaned(decoded.nextNode, fallback: fallback.nextNode),
            holdingImpact: cleaned(decoded.holdingImpact, fallback: fallback.holdingImpact),
            filterRule: cleaned(decoded.filterRule, fallback: fallback.filterRule),
            mapSummary: cleaned(decoded.mapSummary, fallback: fallback.mapSummary),
            risks: Array((decoded.risks ?? fallback.risks).prefix(3)),
            sourceNote: "AI 来源：\(provider.title) \(provider.modelName)。",
            updatedAt: Date()
        )
    }

    private static func extractJSONObject(from text: String) -> String? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        value = value.replacingOccurrences(of: "```json", with: "")
        value = value.replacingOccurrences(of: "```", with: "")
        guard let start = value.firstIndex(of: "{"),
              let end = value.lastIndex(of: "}"),
              start <= end else { return nil }
        return String(value[start...end])
    }

    private static func cleaned(_ value: String?, fallback: String) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func upcomingFocusEvents(events: [CalendarEvent], start: Date = Date(), days: Int = 21, limit: Int) -> [CalendarEvent] {
        let startDay = DateKeys.calendar.startOfDay(for: start)
        let endDay = DateKeys.calendar.date(byAdding: .day, value: days, to: startDay) ?? startDay
        return events
            .filter { $0.date >= startDay && $0.date < endDay && isMajorDisplayEvent($0) }
            .sorted {
                if $0.date == $1.date { return $0.importance > $1.importance }
                return $0.date < $1.date
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func isMajorDisplayEvent(_ event: CalendarEvent) -> Bool {
        switch event.category {
        case .stockCalendar:
            return true
        case .announcement:
            return event.importance == .high
        case .fomc, .cpi:
            return true
        case .usMacro, .chinaMacro:
            return event.importance == .high
        }
    }

    private static func mapSummary(for watchlist: [WatchStock], marginSnapshots: [String: MarginSnapshot]) -> String {
        if let hottest = marginSnapshots.values.sorted(by: { $0.temperatureScore > $1.temperatureScore }).first,
           hottest.temperature != .cool {
            return "\(hottest.name) 的两融温度最高，融资余额占流通市值约 \(formatPercent(hottest.financingBalanceRatio))，近10日融资净买入 \(formatAmount(hottest.financingNetBuy10D))；联动图谱会把它放在公告和宏观节点前一起看。"
        }

        let names = Set(watchlist.map(\.name))
        if names.contains("紫金矿业") && names.contains("腾讯控股") {
            return "紫金矿业和腾讯控股表面行业不同，但都被实际利率和美元流动性影响；FOMC 前后要一起看。"
        }
        if names.contains("宁德时代") {
            return "宁德时代要同时看电池产业链价格、需求预期和利率，单一财报日期不足以解释波动。"
        }
        return "联动图谱先把自选股映射到利率、商品价格、产业价格和公告触发，再逐步补实时因子。"
    }

    private static func riskNotes(for focus: [CalendarEvent], watchlist: [WatchStock], marginSnapshots: [String: MarginSnapshot]) -> [String] {
        var notes: [String] = []
        if let hottest = marginSnapshots.values.sorted(by: { $0.temperatureScore > $1.temperatureScore }).first,
           hottest.temperature != .cool {
            notes.append("\(hottest.name) 杠杆温度\(hottest.temperature.title)，近10日融资净买入 \(formatAmount(hottest.financingNetBuy10D))，事件日前后要防融资推动后的反向波动。")
        }
        if focus.contains(where: { $0.category == .fomc || $0.category == .cpi }) {
            notes.append("宏观节点前后，先降低单日价格信号权重。")
        }
        if watchlist.contains(where: { ["紫金矿业", "洛阳钼业"].contains($0.name) }) {
            notes.append("资源股需要叠加商品价格和美元方向确认。")
        }
        if focus.contains(where: { $0.category == .announcement }) {
            notes.append("公告只进入主屏不代表买卖结论，需要回到合同质量和业绩弹性。")
        }
        return Array(notes.prefix(3))
    }

    private static func formatAmount(_ value: Double) -> String {
        let absolute = abs(value)
        let sign = value < 0 ? "-" : ""
        if absolute >= 100_000_000 {
            return "\(sign)\(String(format: "%.2f", absolute / 100_000_000))亿"
        }
        if absolute >= 10_000 {
            return "\(sign)\(String(format: "%.0f", absolute / 10_000))万"
        }
        return "\(sign)\(String(format: "%.0f", absolute))"
    }

    private static func formatPercent(_ value: Double?) -> String {
        guard let value else { return "缺失" }
        return "\(String(format: "%.2f", value))%"
    }

    private static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = DateKeys.calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = DateKeys.calendar.timeZone
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}

private enum AIProviderError: LocalizedError {
    case badURL
    case emptyResponse
    case invalidJSON
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "AI 接口地址无效"
        case .emptyResponse: return "AI 返回为空"
        case .invalidJSON: return "AI 返回格式不是 JSON"
        case let .http(code, body): return "AI 接口 HTTP \(code)：\(body)"
        }
    }
}

private struct RemoteInsight: Decodable {
    var headline: String?
    var badge: String?
    var regime: String?
    var intensity: String?
    var nextNode: String?
    var holdingImpact: String?
    var filterRule: String?
    var mapSummary: String?
    var risks: [String]?
}

private struct GeminiRequest: Encodable {
    var contents: [GeminiContent]
    var generationConfig: GeminiGenerationConfig
}

private struct GeminiContent: Encodable, Decodable {
    var parts: [GeminiPart]
}

private struct GeminiPart: Encodable, Decodable {
    var text: String
}

private struct GeminiGenerationConfig: Encodable {
    var temperature: Double
    var responseMimeType: String

    enum CodingKeys: String, CodingKey {
        case temperature
        case responseMimeType = "responseMimeType"
    }
}

private struct GeminiResponse: Decodable {
    var candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Decodable {
    var content: GeminiContent
}

private struct ChatCompletionRequest: Encodable {
    var model: String
    var messages: [ChatMessage]
    var temperature: Double
}

private struct ChatMessage: Encodable, Decodable {
    var role: String
    var content: String
}

private struct ChatCompletionResponse: Decodable {
    var choices: [ChatChoice]
}

private struct ChatChoice: Decodable {
    var message: ChatMessage
}
