import Foundation

enum ExposureGraphProvider {
    static func drivers(for watchlist: [WatchStock], marginSnapshots: [String: MarginSnapshot]) -> [ExposureDriver] {
        let stocksByName = Dictionary(uniqueKeysWithValues: watchlist.map { ($0.name, $0) })
        var drivers: [ExposureDriver] = []

        addCopperDriver(stocksByName: stocksByName, into: &drivers)
        addRealYieldDriver(stocksByName: stocksByName, into: &drivers)
        addHongKongLiquidityDriver(stocksByName: stocksByName, into: &drivers)
        addGoldDriver(stocksByName: stocksByName, into: &drivers)
        addLithiumDriver(stocksByName: stocksByName, into: &drivers)
        addRefrigerantDriver(stocksByName: stocksByName, into: &drivers)
        addMarginDriver(marginSnapshots: marginSnapshots, into: &drivers)

        return drivers.sorted {
            if $0.hasHiddenConcentration != $1.hasHiddenConcentration {
                return $0.hasHiddenConcentration
            }
            if $0.reliableEdgeCount != $1.reliableEdgeCount {
                return $0.reliableEdgeCount > $1.reliableEdgeCount
            }
            return $0.order < $1.order
        }
    }

    static func hiddenConcentration(for drivers: [ExposureDriver]) -> ExposureConcentration? {
        guard let driver = drivers.first(where: { $0.hasHiddenConcentration }) else { return nil }
        let names = driver.edges
            .filter(\.kind.countsForConcentration)
            .map(\.stockName)
            .prefix(3)
            .joined(separator: "、")
        return ExposureConcentration(
            driver: driver,
            title: "隐藏集中度：\(driver.title)",
            detail: "\(names) 同时挂在「\(driver.title)」节点上。它们看起来分散，但遇到同一个驱动反向时会一起波动。"
        )
    }

    private static func addCopperDriver(stocksByName: [String: WatchStock], into drivers: inout [ExposureDriver]) {
        var edges: [ExposureHoldingEdge] = []
        if let stock = stocksByName["洛阳钼业"] {
            edges.append(edge(stock, rho: "+0.71", kind: .stablePositive, stability: 1.00, blocks: [0.60, 0.70, 0.65, 0.72, 0.68, 0.70, 0.74, 0.71], note: "铜 beta 高，需求走弱时回撤会更同步。"))
        }
        if let stock = stocksByName["紫金矿业"] {
            edges.append(edge(stock, rho: "+0.64", kind: .stablePositive, stability: 0.88, blocks: [0.50, 0.55, 0.62, 0.58, 0.66, 0.60, 0.64, 0.63], note: "紫金同时受铜与金影响，顺周期和避险是合成暴露。"))
        }
        guard !edges.isEmpty else { return }
        drivers.append(ExposureDriver(
            id: "copper",
            symbolName: "circle.hexagongrid.fill",
            category: "工业金属 · 驱动节点",
            title: "铜价",
            level: "LME",
            move: "供需敏感",
            direction: .up,
            subtitle: "影响 \(edges.count) 只持仓",
            edges: edges,
            aiNote: "铜是资源股里最容易形成同涨同跌的节点。它可以独立于货币宽松运行，但一旦全球需求下修，洛钼和紫金会一起回撤。",
            eventTitle: "关联事件 · 中国宏观 / 海外库存 / 地缘冲突",
            eventDetail: "铜价上行要区分供给冲击和需求复苏；两者对持仓持续性的含义不同。",
            order: 1
        ))
    }

    private static func addRealYieldDriver(stocksByName: [String: WatchStock], into drivers: inout [ExposureDriver]) {
        var edges: [ExposureHoldingEdge] = []
        if let stock = stocksByName["紫金矿业"] {
            edges.append(edge(stock, rho: "-0.41", kind: .stableNegative, stability: 0.86, blocks: [-0.30, -0.40, -0.35, -0.45, -0.38, -0.42, -0.50, -0.41], note: "金价端受实际利率压制。"))
        }
        if let stock = stocksByName["腾讯控股"] {
            edges.append(edge(stock, rho: "-0.47", kind: .stableNegative, stability: 0.83, blocks: [-0.35, -0.30, -0.44, -0.40, -0.52, -0.46, -0.50, -0.47], note: "久期资产对实际利率和港股流动性同时敏感。"))
        }
        if let stock = stocksByName["宁德时代"] {
            edges.append(edge(stock, rho: "-0.32", kind: .stableNegative, stability: 0.72, blocks: [-0.18, -0.25, -0.31, -0.28, -0.36, -0.40, -0.29, -0.33], note: "高利率更久会压估值久期，但产业链因素也很强。"))
        }
        guard !edges.isEmpty else { return }
        drivers.append(ExposureDriver(
            id: "real-yield",
            symbolName: "chart.line.downtrend.xyaxis",
            category: "货币环境 · 驱动节点",
            title: "美债实际利率",
            level: "高利率更久",
            move: "active",
            direction: .up,
            subtitle: "影响 \(edges.count) 只持仓 · 隐蔽集中",
            edges: edges,
            aiNote: "这是罗盘里最重要的共享空头之一。资源股的黄金端、港股久期资产和新能源龙头，看起来行业不同，但都会被实际利率上行压制。",
            eventTitle: "关联事件 · CPI / FOMC / SEP 点阵图",
            eventDetail: "单点 CPI 只是输入，FOMC 把它翻译成利率路径。",
            order: 2
        ))
    }

    private static func addHongKongLiquidityDriver(stocksByName: [String: WatchStock], into drivers: inout [ExposureDriver]) {
        guard let stock = stocksByName["腾讯控股"] else { return }
        drivers.append(ExposureDriver(
            id: "hk-liquidity",
            symbolName: "arrow.left.arrow.right.circle.fill",
            category: "港股流动性 · 驱动节点",
            title: "恒指 / 南向资金",
            level: "港股 beta",
            move: "择时变量",
            direction: .flat,
            subtitle: "影响 1 只持仓",
            edges: [edge(stock, rho: "+0.79", kind: .stablePositive, stability: 1.00, blocks: [0.70, 0.75, 0.80, 0.72, 0.78, 0.82, 0.76, 0.79], note: "腾讯短线更像港股 beta 的表达，南向资金比普通新闻更关键。")],
            aiNote: "腾讯的基本面当然重要，但短周期里南向和恒指 beta 往往先决定波动方向。",
            eventTitle: "关联节点 · 实际利率与港股风险偏好",
            eventDetail: "两节点同向时波动会放大。",
            order: 3
        ))
    }

    private static func addGoldDriver(stocksByName: [String: WatchStock], into drivers: inout [ExposureDriver]) {
        guard let stock = stocksByName["紫金矿业"] else { return }
        drivers.append(ExposureDriver(
            id: "gold",
            symbolName: "sun.max.fill",
            category: "避险资产 · 驱动节点",
            title: "金价",
            level: "伦敦金",
            move: "实际利率镜像",
            direction: .down,
            subtitle: "影响 1 只持仓",
            edges: [edge(stock, rho: "+0.58", kind: .stablePositive, stability: 0.86, blocks: [0.45, 0.50, 0.60, 0.55, 0.62, 0.52, 0.58, 0.58], note: "紫金同挂铜金两节点，顺周期和避险之间有对冲。")],
            aiNote: "金价不是单独看涨跌，而要和实际利率一起看。实际利率上行时，黄金端会拖累资源股弹性。",
            eventTitle: "关联节点 · 实际利率反向联动",
            eventDetail: "高利率更久时，黄金需要独立避险催化。",
            order: 4
        ))
    }

    private static func addLithiumDriver(stocksByName: [String: WatchStock], into drivers: inout [ExposureDriver]) {
        guard let stock = stocksByName["宁德时代"] else { return }
        drivers.append(ExposureDriver(
            id: "lithium",
            symbolName: "bolt.batteryblock.fill",
            category: "新能源上游 · 驱动节点",
            title: "碳酸锂",
            level: "产业链价格",
            move: "符号翻转",
            direction: .flat,
            subtitle: "影响 1 只持仓 · 边不可信",
            edges: [edge(stock, rho: "-0.40", kind: .unstable, stability: 0.50, blocks: [0.49, 0.48, 0.45, 0.57, -0.54, -0.27, -0.60, -0.34], note: "锂价既是成本也是需求信号，静态相关会把两个 regime 平均成假象。")],
            aiNote: "这是典型 UNSTABLE 边。锂价上涨有时是成本压力，有时是需求恢复，不能把单一相关系数当结论。",
            eventTitle: "引擎判定 · UNSTABLE",
            eventDetail: "符号不稳定的边不贡献共享暴露，只作为解释变量保留。",
            order: 5
        ))
    }

    private static func addRefrigerantDriver(stocksByName: [String: WatchStock], into drivers: inout [ExposureDriver]) {
        guard let stock = stocksByName["三美股份"] else { return }
        drivers.append(ExposureDriver(
            id: "refrigerant",
            symbolName: "wind.circle.fill",
            category: "制冷剂 · 驱动节点",
            title: "制冷剂价格",
            level: "配额周期",
            move: "利润弹性",
            direction: .up,
            subtitle: "影响 1 只持仓",
            edges: [edge(stock, rho: "+0.62", kind: .stablePositive, stability: 0.80, blocks: [0.35, 0.42, 0.55, 0.60, 0.66, 0.61, 0.58, 0.62], note: "三美重点看配额、价格和分红安全垫。")],
            aiNote: "三美的主线不应被普通公告淹没，真正关键的是制冷剂价格、配额和利润弹性。",
            eventTitle: "关联事件 · 配额政策 / 价格跟踪",
            eventDetail: "定期报告前后重点验证价格能否进入利润。",
            order: 6
        ))
    }

    private static func addMarginDriver(marginSnapshots: [String: MarginSnapshot], into drivers: inout [ExposureDriver]) {
        let hot = marginSnapshots.values
            .sorted { $0.temperatureScore > $1.temperatureScore }
            .prefix(4)
        let edges = hot.map { snapshot in
            ExposureHoldingEdge(
                stockName: snapshot.name,
                code: snapshot.code,
                rhoText: String(format: "%.0f", snapshot.temperatureScore),
                kind: .leverage,
                stability: min(max((snapshot.financingBalanceRatioPercentile ?? 0.5), 0), 1),
                blocks: leverageBlocks(from: snapshot),
                note: "融资余额占流通市值 \(formatPercent(snapshot.financingBalanceRatio))，近10日融资净买入 \(formatAmount(snapshot.financingNetBuy10D))。"
            )
        }
        guard !edges.isEmpty else { return }
        drivers.append(ExposureDriver(
            id: "margin-leverage",
            symbolName: "gauge.with.dots.needle.67percent",
            category: "资金拥挤 · 驱动节点",
            title: "融资融券杠杆",
            level: "两融温度",
            move: "每日更新",
            direction: .flat,
            subtitle: "覆盖 \(edges.count) 只 A 股",
            edges: edges,
            aiNote: "两融不是方向预测，而是脆弱性变量。事件日前融资净买入推高、股价没有同步确认时，要警惕反向波动。",
            eventTitle: "关联事件 · 公告 / 财报 / 宏观节点前",
            eventDetail: "把两融和日历事件叠加看，避免只看单日价格。",
            order: 0
        ))
    }

    private static func edge(
        _ stock: WatchStock,
        rho: String,
        kind: ExposureEdgeKind,
        stability: Double,
        blocks: [Double],
        note: String
    ) -> ExposureHoldingEdge {
        ExposureHoldingEdge(
            stockName: stock.name,
            code: stock.displayCode,
            rhoText: rho,
            kind: kind,
            stability: stability,
            blocks: blocks,
            note: note
        )
    }

    private static func leverageBlocks(from snapshot: MarginSnapshot) -> [Double] {
        let ratio = min(max((snapshot.financingBalanceRatio ?? 0) / 6.0, 0), 1)
        let net = max(min(snapshot.financingNetBuy10D / max(snapshot.financingBalance, 1) / 0.08, 1), -1)
        return [ratio * 0.45, ratio * 0.55, ratio * 0.60, ratio * 0.65, net * 0.55, net * 0.65, net * 0.75, net * 0.85]
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
}
