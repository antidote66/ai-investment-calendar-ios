import SwiftUI

struct CalendarScreen: View {
    @EnvironmentObject private var store: InvestmentCalendarStore
    @State private var showingAddStock = false
    @State private var selectedEvent: CalendarEvent?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    MonthHeader {
                        showingAddStock = true
                    }
                    CalendarGrid()
                    MajorMattersSection { event in
                        selectedEvent = event
                    }
                    SourceFootnote()
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle("投资日历")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        if store.isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(store.isRefreshing)
                    .accessibilityLabel("刷新")
                }
            }
            .tint(AppTheme.vermilion)
            .sheet(isPresented: $showingAddStock) {
                AddStockView()
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailView(event: event)
            }
        }
    }
}

struct AIWorkspaceScreen: View {
    @State private var showingAISettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("左滑第二页")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.mutedInk)
                        Text("AI 研判")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    AIProviderStatusCard {
                        showingAISettings = true
                    }
                    AIInsightCard()
                    ExposureCompassCard()
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle("AI 工作台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAISettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("AI 数据源")
                }
            }
            .sheet(isPresented: $showingAISettings) {
                AIProviderSettingsView()
            }
        }
    }
}

private struct MonthHeader: View {
    @EnvironmentObject private var store: InvestmentCalendarStore
    var onAddStock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI 投资日历")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.mutedInk)
                    Text(DateKeys.monthTitle.string(from: store.visibleMonth))
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                }

                Spacer()

                Button {
                    onAddStock()
                } label: {
                    Label("添加股票", systemImage: "plus")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(AppTheme.ink, in: Capsule())
                        .foregroundStyle(AppTheme.card)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Button {
                    shiftMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 34, height: 30)
                        .background(AppTheme.card, in: Capsule())
                        .overlay(Capsule().stroke(AppTheme.line.opacity(0.8), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    store.visibleMonth = Date()
                    store.selectedDate = Date()
                } label: {
                    Text("今日")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(AppTheme.card, in: Capsule())
                        .overlay(Capsule().stroke(AppTheme.line.opacity(0.8), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    shiftMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 34, height: 30)
                        .background(AppTheme.card, in: Capsule())
                        .overlay(Capsule().stroke(AppTheme.line.opacity(0.8), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Spacer()

                if store.isRefreshing {
                    Label("更新中", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.mutedInk)
                } else if let lastUpdated = store.lastUpdated {
                    Text("更新 \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }
            }
            .foregroundStyle(AppTheme.ink)

            VStack(alignment: .leading, spacing: 4) {
                if let message = store.statusMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.mutedInk)
                }
            }

            MonthCountStrip()
        }
    }

    private func shiftMonth(_ value: Int) {
        if let next = DateKeys.calendar.date(byAdding: .month, value: value, to: store.visibleMonth) {
            store.visibleMonth = next
            store.selectedDate = next
        }
    }
}

private struct MonthCountStrip: View {
    @EnvironmentObject private var store: InvestmentCalendarStore

    var body: some View {
        let counts = store.visibleMonthCounts()
        HStack(spacing: 8) {
            CountPill(title: "宏观", value: counts.macro, color: AppTheme.sumiBlue)
            CountPill(title: "公告", value: counts.stock, color: AppTheme.matcha)
            CountPill(title: "披露", value: counts.disclosure, color: AppTheme.vermilion)
        }
    }
}

private struct CountPill: View {
    var title: String
    var value: Int
    var color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
            Text("\(value)")
                .fontWeight(.semibold)
        }
        .font(.caption)
        .foregroundStyle(AppTheme.mutedInk)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(AppTheme.card, in: Capsule())
        .overlay(Capsule().stroke(AppTheme.line.opacity(0.7), lineWidth: 1))
    }
}

private struct FocusOverview: View {
    @EnvironmentObject private var store: InvestmentCalendarStore
    var onSelect: (CalendarEvent) -> Void

    var body: some View {
        let events = store.upcomingFocusEvents()
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("近期重点")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text("21日")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            if events.isEmpty {
                Text(store.isRefreshing ? "正在更新重点事项" : "未来三周暂无高优先级事项")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(events) { event in
                        Button {
                            onSelect(event)
                        } label: {
                            FocusEventRow(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.65), lineWidth: 1))
    }
}

private struct FocusEventRow: View {
    var event: CalendarEvent

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.category.tint)
                .frame(width: 4, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(shortDate(event.date))
                    Text(event.category.title)
                    if let relatedCode = event.relatedCode {
                        Text(relatedCode)
                    }
                }
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.mutedInk.opacity(0.8))
        }
        .padding(.vertical, 2)
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = DateKeys.calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = DateKeys.calendar.timeZone
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}

private struct AIProviderStatusCard: View {
    @EnvironmentObject private var store: InvestmentCalendarStore
    var onConfigure: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "cpu")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.sumiBlue)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.sumiBlue.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("AI 数据源")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text(store.aiProviderStatusText())
                        .font(.footnote)
                        .foregroundStyle(AppTheme.mutedInk)
                    if let message = store.aiStatusMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(AppTheme.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                Button {
                    onConfigure()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(AppTheme.paper.opacity(0.78), in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                AIChip(title: "数据", value: "免费源", color: AppTheme.matcha)
                AIChip(title: "模型", value: store.aiProviderKind.title, color: AppTheme.sumiBlue)
                if store.isAnalyzingAI {
                    ProgressView()
                        .frame(width: 24, height: 24)
                }
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.65), lineWidth: 1))
    }
}

private struct AIInsightCard: View {
    @EnvironmentObject private var store: InvestmentCalendarStore

    var body: some View {
        let insight = store.aiInsight
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI 研判", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                if store.isAnalyzingAI {
                    ProgressView()
                } else {
                    Text(insight.badge)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.amber)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.amber.opacity(0.12), in: Capsule())
                }
            }

            Text(insight.headline)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                AIChip(title: "状态", value: insight.regime, color: AppTheme.sumiBlue)
                AIChip(title: "强度", value: insight.intensity, color: AppTheme.vermilion)
            }

            Divider()
                .overlay(AppTheme.line.opacity(0.7))

            VStack(spacing: 10) {
                AIInsightLine(symbol: "mappin.and.ellipse", title: "下一节点", text: insight.nextNode)
                AIInsightLine(symbol: "arrow.triangle.branch", title: "对持仓", text: insight.holdingImpact)
                AIInsightLine(symbol: "line.3.horizontal.decrease.circle", title: "过滤规则", text: insight.filterRule)
                AIInsightLine(symbol: "antenna.radiowaves.left.and.right", title: "来源状态", text: insight.sourceNote)
                ForEach(Array(insight.risks.prefix(3)), id: \.self) { risk in
                    AIInsightLine(symbol: "exclamationmark.circle", title: "风险提示", text: risk)
                }
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.amber.opacity(0.30), lineWidth: 1))
    }
}

private struct AIChip: View {
    var title: String
    var value: String
    var color: Color

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .foregroundStyle(AppTheme.mutedInk)
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .font(.caption)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(AppTheme.paper.opacity(0.72), in: Capsule())
    }
}

private struct AIInsightLine: View {
    var symbol: String
    var title: String
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.amber)
                .frame(width: 20, height: 20)
                .background(AppTheme.amber.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ExposureCompassCard: View {
    @EnvironmentObject private var store: InvestmentCalendarStore

    var body: some View {
        let insight = store.aiInsight
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI 联动图谱", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text("轻量版")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.amber)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.amber.opacity(0.10), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("隐藏集中度：实际利率")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(insight.mapSummary)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(11)
            .background(AppTheme.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))

            VStack(spacing: 8) {
                ForEach(exposureRows()) { row in
                    ExposureRowView(row: row)
                }
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.65), lineWidth: 1))
    }

    private func exposureRows() -> [ExposureRow] {
        let rows = store.watchlist.map { stock -> ExposureRow in
            switch stock.name {
            case "腾讯控股":
                return ExposureRow(name: stock.name, code: stock.displayCode, driver: "港股β / 实际利率", tag: "STABLE-", note: "短线看南向和利率，基本面公告放第二层。")
            case "紫金矿业":
                return ExposureRow(name: stock.name, code: stock.displayCode, driver: "铜价 + 金价", tag: "STABLE+", note: "资源逻辑硬，但实际利率上行会压金价。")
            case "洛阳钼业":
                return ExposureRow(name: stock.name, code: stock.displayCode, driver: "铜价 / 钴价", tag: "STABLE+", note: "和铜价同向度高，宏观需求走弱时同步回撤。")
            case "宁德时代":
                return ExposureRow(name: stock.name, code: stock.displayCode, driver: "碳酸锂", tag: "UNSTABLE", note: "锂价既是成本也是需求信号，不能当单一方向边。")
            case "三美股份":
                return ExposureRow(name: stock.name, code: stock.displayCode, driver: "制冷剂价格", tag: "周期", note: "重点看配额、价格和分红安全垫。")
            default:
                return ExposureRow(name: stock.name, code: stock.displayCode, driver: "公告 / 财报", tag: "跟踪", note: "先接入披露日期，再逐步补宏观驱动。")
            }
        }
        return Array(rows.prefix(6))
    }
}

private struct ExposureRow: Identifiable {
    var id: String { "\(name)-\(code)-\(driver)" }
    var name: String
    var code: String
    var driver: String
    var tag: String
    var note: String
}

private struct ExposureRowView: View {
    var row: ExposureRow

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(row.code)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }
            .frame(width: 76, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.driver)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(row.note)
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(row.tag)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tagColor(row.tag))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(tagColor(row.tag).opacity(0.10), in: Capsule())
        }
    }

    private func tagColor(_ tag: String) -> Color {
        if tag.contains("UNSTABLE") { return AppTheme.amber }
        if tag.contains("-") { return AppTheme.vermilion }
        if tag.contains("+") { return AppTheme.matcha }
        return AppTheme.mutedInk
    }
}

private struct WatchlistInline: View {
    @EnvironmentObject private var store: InvestmentCalendarStore
    var onAdd: () -> Void
    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("自选股")
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Button {
                    onAdd()
                } label: {
                    Label("添加", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(AppTheme.ink, in: Capsule())
                        .foregroundStyle(AppTheme.card)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(store.watchlist.prefix(6)) { stock in
                    MiniStockCard(stock: stock, nextEvent: store.nextEvent(for: stock))
                }
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.65), lineWidth: 1))
    }
}

private struct MiniStockCard: View {
    var stock: WatchStock
    var nextEvent: CalendarEvent?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(stock.name)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Spacer()
                Text(stock.market.rawValue)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
            Text(stock.displayCode)
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
            if let nextEvent {
                Text("\(shortDate(nextEvent.date)) \(nextEvent.category.title)")
                    .font(.caption)
                    .foregroundStyle(nextEvent.category.tint)
                    .lineLimit(1)
            } else {
                Text("等待披露")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = DateKeys.calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = DateKeys.calendar.timeZone
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}

private struct SourceFootnote: View {
    var body: some View {
        Text("数据来源：Fed、U.S. BLS、国家统计局、东方财富公告/预约披露、HKEXnews。启动和手动刷新时更新；网页结构变化时需要维护。")
            .font(.caption)
            .foregroundStyle(AppTheme.mutedInk)
            .lineSpacing(3)
            .padding(.horizontal, 4)
            .padding(.top, 2)
    }
}

private struct CalendarGrid: View {
    @EnvironmentObject private var store: InvestmentCalendarStore
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.mutedInk)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(daysForVisibleMonth(), id: \.self) { date in
                    DayCell(date: date)
                }
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.7), lineWidth: 1))
    }

    private func daysForVisibleMonth() -> [Date?] {
        let calendar = DateKeys.calendar
        guard let interval = calendar.dateInterval(of: .month, for: store.visibleMonth) else { return [] }
        let days = calendar.range(of: .day, in: .month, for: interval.start) ?? 1..<1
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday + 5) % 7
        let dates = days.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: interval.start)
        }
        let blanks = Array<Date?>(repeating: nil, count: leading)
        let total = blanks.count + dates.count
        let trailing = (7 - total % 7) % 7
        return blanks + dates.map(Optional.some) + Array<Date?>(repeating: nil, count: trailing)
    }
}

private struct DayCell: View {
    @EnvironmentObject private var store: InvestmentCalendarStore
    var date: Date?

    var body: some View {
        Group {
            if let date {
                Button {
                    store.selectedDate = date
                } label: {
                    VStack(spacing: 5) {
                        Text("\(DateKeys.calendar.component(.day, from: date))")
                            .font(.callout.weight(isSelected(date) ? .bold : .regular))
                            .foregroundStyle(dayForeground(for: date))
                            .frame(height: 19)

                        HStack(spacing: 2) {
                            ForEach(Array(events.prefix(4))) { event in
                                Circle()
                                    .fill(event.category.tint)
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .frame(height: 7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(background(for: date), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(minHeight: 48)
            }
        }
    }

    private var events: [CalendarEvent] {
        guard let date else { return [] }
        return store.events(on: date)
    }

    private func isSelected(_ date: Date) -> Bool {
        DateKeys.day.string(from: date) == DateKeys.day.string(from: store.selectedDate)
    }

    private func isToday(_ date: Date) -> Bool {
        DateKeys.day.string(from: date) == DateKeys.day.string(from: Date())
    }

    private func background(for date: Date) -> Color {
        if isSelected(date) {
            return AppTheme.vermilion.opacity(0.12)
        }
        if !events.isEmpty {
            return AppTheme.paper.opacity(0.7)
        }
        return Color.clear
    }

    private func dayForeground(for date: Date) -> Color {
        if isSelected(date) {
            return AppTheme.vermilion
        }
        if isToday(date) {
            return AppTheme.sumiBlue
        }
        return AppTheme.ink
    }
}

private struct MajorMattersSection: View {
    @EnvironmentObject private var store: InvestmentCalendarStore
    var onSelect: (CalendarEvent) -> Void

    var body: some View {
        let selectedEvents = store.majorEvents(on: store.selectedDate)
        let events = selectedEvents.isEmpty ? store.upcomingFocusEvents(limit: 8) : selectedEvents
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("重大事项")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text(sectionSubtitle(hasSelectedEvents: !selectedEvents.isEmpty))
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }
                Spacer()
                Text(selectedEvents.isEmpty ? "21日" : "\(events.count) 项")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }

            if events.isEmpty {
                Text(store.isRefreshing ? "正在筛选重大事项" : "暂无重大事项")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.65), lineWidth: 1))
            } else {
                VStack(spacing: 10) {
                    ForEach(events) { event in
                        Button {
                            onSelect(event)
                        } label: {
                            EventRow(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sectionSubtitle(hasSelectedEvents: Bool) -> String {
        if hasSelectedEvents {
            return DateKeys.displayDay.string(from: store.selectedDate)
        }
        return "筛掉担保、关联交易和普通材料，仅保留合同、业绩、定期报告、分红、重组等"
    }
}

private struct SelectedDateEvents: View {
    @EnvironmentObject private var store: InvestmentCalendarStore
    var onSelect: (CalendarEvent) -> Void

    @ViewBuilder
    var body: some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(DateKeys.displayDay.string(from: store.selectedDate))
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Text("\(events.count) 项")
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                VStack(spacing: 10) {
                    ForEach(events) { event in
                        Button {
                            onSelect(event)
                        } label: {
                            EventRow(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var events: [CalendarEvent] {
        store.events(on: store.selectedDate)
    }
}

struct EventRow: View {
    var event: CalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: event.category.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(event.category.tint)
                    .frame(width: 30, height: 30)
                    .background(event.category.tint.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(event.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(3)
                        if event.importance == .high {
                            Text(event.importance.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.vermilion, in: Capsule())
                        }
                    }

                    Text(event.detail)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Text(event.sourceName)
                        if let relatedCode = event.relatedCode {
                            Text(relatedCode)
                        }
                        Text(eventTime(event.date))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.mutedInk.opacity(0.75))
                    }
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
                }
            }
        }
        .padding(12)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.65), lineWidth: 1))
    }

    private func eventTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

private struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    var event: CalendarEvent

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Label(event.category.title, systemImage: event.category.symbolName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(event.category.tint)
                            Spacer()
                            Text(event.importance.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(event.importance == .high ? AppTheme.vermilion : AppTheme.mutedInk)
                        }

                        Text(event.title)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(fullDate(event.date))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                    .padding(16)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.65), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("内容")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        Text(event.detail)
                            .font(.body)
                            .foregroundStyle(AppTheme.ink)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.65), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 9) {
                        DetailMetaRow(title: "来源", value: event.sourceName)
                        if let relatedCode = event.relatedCode {
                            DetailMetaRow(title: "代码", value: relatedCode)
                        }
                        if let sourceURL = event.sourceURL {
                            Link(destination: sourceURL) {
                                Label("打开原始来源", systemImage: "safari")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(AppTheme.ink, in: RoundedRectangle(cornerRadius: 8))
                                    .foregroundStyle(AppTheme.card)
                            }
                        }
                    }
                    .padding(16)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.65), lineWidth: 1))
                }
                .padding(18)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle("事项详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .tint(AppTheme.vermilion)
        }
    }

    private func fullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = DateKeys.calendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = DateKeys.calendar.timeZone
        formatter.dateFormat = "yyyy年M月d日 EEEE HH:mm"
        return formatter.string(from: date)
    }
}

private struct DetailMetaRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.mutedInk)
                .frame(width: 42, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.ink)
            Spacer()
        }
    }
}
