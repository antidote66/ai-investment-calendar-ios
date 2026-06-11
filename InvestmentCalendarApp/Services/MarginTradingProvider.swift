import Foundation

enum MarginTradingProvider {
    static func fetch(for stocks: [WatchStock]) async -> [String: MarginSnapshot] {
        let aShares = stocks.filter { $0.market == .aShare }
        guard !aShares.isEmpty else { return [:] }

        return await withTaskGroup(of: (String, MarginSnapshot?).self) { group in
            for stock in aShares {
                group.addTask {
                    (stock.code, await fetch(stock: stock))
                }
            }

            var result: [String: MarginSnapshot] = [:]
            for await (code, snapshot) in group {
                if let snapshot {
                    result[code] = snapshot
                }
            }
            return result
        }
    }

    private static func fetch(stock: WatchStock) async -> MarginSnapshot? {
        var components = URLComponents(string: "https://datacenter-web.eastmoney.com/api/data/v1/get")
        components?.queryItems = [
            URLQueryItem(name: "reportName", value: "RPTA_WEB_RZRQ_GGMX"),
            URLQueryItem(name: "columns", value: "ALL"),
            URLQueryItem(name: "source", value: "WEB"),
            URLQueryItem(name: "sortColumns", value: "DATE"),
            URLQueryItem(name: "sortTypes", value: "-1"),
            URLQueryItem(name: "pageNumber", value: "1"),
            URLQueryItem(name: "pageSize", value: "240"),
            URLQueryItem(name: "filter", value: "(scode=\"\(stock.code)\")")
        ]
        guard let url = components?.url,
              let data = try? await WebClient.shared.data(from: url, timeout: 10),
              let response = try? JSONDecoder().decode(EastMoneyMarginResponse.self, from: data),
              let rows = response.result?.data,
              let latest = rows.first,
              let date = parseDate(latest.date) else {
            return nil
        }

        let ratios = rows.compactMap(\.financingBalanceRatio)
        let ratioPercentile = latest.financingBalanceRatio.flatMap { percentile(of: $0, in: ratios) }
        let score = temperatureScore(latest: latest, ratioPercentile: ratioPercentile)

        return MarginSnapshot(
            code: stock.code,
            name: stock.name,
            date: date,
            financingBalance: latest.financingBalance ?? 0,
            marginBalance: latest.marginBalance ?? 0,
            shortBalance: latest.shortBalance ?? 0,
            shortVolume: latest.shortVolume ?? 0,
            financingBuy: latest.financingBuy ?? 0,
            financingRepay: latest.financingRepay ?? 0,
            financingNetBuy: latest.financingNetBuy ?? 0,
            financingNetBuy5D: latest.financingNetBuy5D ?? 0,
            financingNetBuy10D: latest.financingNetBuy10D ?? 0,
            financingBalanceRatio: latest.financingBalanceRatio,
            financingBalanceRatioPercentile: ratioPercentile,
            closingPrice: latest.closingPrice,
            priceChangePercent: latest.priceChangePercent,
            temperatureScore: score,
            sourceName: "东方财富融资融券",
            sourceURL: URL(string: "https://data.eastmoney.com/rzrq/stock/\(stock.code).html"),
            updatedAt: Date()
        )
    }

    private static func temperatureScore(latest: EastMoneyMarginRow, ratioPercentile: Double?) -> Double {
        let ratio = latest.financingBalanceRatio ?? 0
        let ratioScore = min(max(ratio / 6.0, 0), 1) * 36
        let percentileScore = (ratioPercentile ?? 0) * 34
        let net10D = latest.financingNetBuy10D ?? 0
        let balance = max(latest.financingBalance ?? 0, 1)
        let netBuyIntensity = max(net10D / balance, 0)
        let netBuyScore = min(netBuyIntensity / 0.08, 1) * 22
        let pricePenalty = ((latest.priceChangePercent ?? 0) < -3 && net10D > 0) ? 8.0 : 0.0
        return min(max(ratioScore + percentileScore + netBuyScore + pricePenalty, 0), 100)
    }

    private static func percentile(of value: Double, in values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let lessOrEqual = sorted.filter { $0 <= value }.count
        return Double(lessOrEqual) / Double(sorted.count)
    }

    private static func parseDate(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = DateKeys.calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: raw)
    }
}

private struct EastMoneyMarginResponse: Decodable {
    var result: EastMoneyMarginResult?
}

private struct EastMoneyMarginResult: Decodable {
    var data: [EastMoneyMarginRow]
}

private struct EastMoneyMarginRow: Decodable {
    var date: String
    var code: String?
    var name: String?
    var financingBalance: Double?
    var shortVolume: Double?
    var marginBalance: Double?
    var shortBalance: Double?
    var shortSellVolume: Double?
    var financingBuy: Double?
    var financingRepay: Double?
    var financingNetBuy: Double?
    var financingNetBuy3D: Double?
    var financingNetBuy5D: Double?
    var financingNetBuy10D: Double?
    var shortNetSell: Double?
    var shortNetSell5D: Double?
    var shortNetSell10D: Double?
    var financingBalanceRatio: Double?
    var closingPrice: Double?
    var priceChangePercent: Double?

    enum CodingKeys: String, CodingKey {
        case date = "DATE"
        case code = "SCODE"
        case name = "SECNAME"
        case financingBalance = "RZYE"
        case shortVolume = "RQYL"
        case marginBalance = "RZRQYE"
        case shortBalance = "RQYE"
        case shortSellVolume = "RQMCL"
        case financingBuy = "RZMRE"
        case financingRepay = "RZCHE"
        case financingNetBuy = "RZJME"
        case financingNetBuy3D = "RZJME3D"
        case financingNetBuy5D = "RZJME5D"
        case financingNetBuy10D = "RZJME10D"
        case shortNetSell = "RQJMG"
        case shortNetSell5D = "RQJMG5D"
        case shortNetSell10D = "RQJMG10D"
        case financingBalanceRatio = "RZYEZB"
        case closingPrice = "SPJ"
        case priceChangePercent = "ZDF"
    }
}
