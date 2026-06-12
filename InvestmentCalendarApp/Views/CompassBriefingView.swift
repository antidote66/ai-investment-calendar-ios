import SwiftUI

struct CompassBriefingSection: View {
    @EnvironmentObject private var store: InvestmentCalendarStore
    var onSelect: (CompassSignal) -> Void

    var body: some View {
        let briefing = CompassKernelProvider.briefing(
            events: store.events,
            watchlist: store.watchlist,
            marginSnapshots: store.marginSnapshots
        )

        VStack(alignment: .leading, spacing: 14) {
            RegimeBriefingCard(regime: briefing.regime)

            ForEach([CompassDeliveryTier.mustDeliver, .majorRelevant, .watchNode]) { tier in
                let signals = Array(briefing.signals(in: tier).prefix(tier == .watchNode ? 4 : 5))
                if !signals.isEmpty {
                    CompassSignalTierBlock(tier: tier, signals: signals, onSelect: onSelect)
                }
            }

            MutedSignalsBlock(signals: Array(briefing.signals(in: .muted).prefix(8)), onSelect: onSelect)
        }
    }
}

private struct RegimeBriefingCard: View {
    var regime: CompassRegime

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("罗盘状态")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.mutedInk)
                    Text(regime.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                }
                Spacer()
                CompassScorePill(title: "置信", value: "\(Int(regime.confidence * 100))", color: confidenceColor)
            }

            Text(regime.thesis)
                .font(.subheadline)
                .foregroundStyle(AppTheme.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("下一决定节点")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                    Spacer()
                }
                Text(regime.nextNode)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(11)
            .background(AppTheme.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))

            if !regime.activeDrivers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(regime.activeDrivers) { driver in
                            Label(driver.title, systemImage: driver.symbolName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(driver.direction.tint)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(driver.direction.tint.opacity(0.08), in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.amber.opacity(0.28), lineWidth: 1))
    }

    private var confidenceColor: Color {
        if regime.confidence >= 0.72 { return AppTheme.vermilion }
        if regime.confidence >= 0.62 { return AppTheme.amber }
        return AppTheme.sumiBlue
    }
}

private struct CompassSignalTierBlock: View {
    var tier: CompassDeliveryTier
    var signals: [CompassSignal]
    var onSelect: (CompassSignal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: tier.title, count: "\(signals.count) 项", color: tier.tint)
            VStack(spacing: 9) {
                ForEach(signals) { signal in
                    Button {
                        onSelect(signal)
                    } label: {
                        CompassSignalRow(signal: signal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct MutedSignalsBlock: View {
    @State private var isExpanded = false
    var signals: [CompassSignal]
    var onSelect: (CompassSignal) -> Void

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 8) {
                if signals.isEmpty {
                    Text("当前没有低信号事项。")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.mutedInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(signals) { signal in
                        Button {
                            onSelect(signal)
                        } label: {
                            CompactSignalRow(signal: signal)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("折叠不等于删除：低信号仍留在日历里，只是不抢主屏注意力。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
            }
            .padding(.top, 9)
        } label: {
            HStack {
                Text(CompassDeliveryTier.muted.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text("\(signals.count) 项")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.65), lineWidth: 1))
        .tint(AppTheme.mutedInk)
    }
}

private struct CompassSignalRow: View {
    var signal: CompassSignal

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(signal.tier.tint)
                    .frame(width: 32, height: 32)
                    .background(signal.tier.tint.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(signal.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(2)
                        Text(signal.tier.shortTitle)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(signal.tier.tint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(signal.tier.tint.opacity(0.10), in: Capsule())
                    }
                    Text(signal.detail)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.mutedInk)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(signal.score))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(signal.tier.tint)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedInk)
                }
            }

            Text(signal.reason)
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)

            if !signal.drivers.isEmpty || !signal.holdings.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(signal.holdings) { stock in
                            CompassTextChip(text: stock.name, color: AppTheme.matcha)
                        }
                        ForEach(signal.drivers) { driver in
                            CompassTextChip(text: driver.title, color: driver.direction.tint)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(signal.tier.tint.opacity(signal.tier == .mustDeliver ? 0.35 : 0.16), lineWidth: 1))
    }

    private var iconName: String {
        if let event = signal.event { return event.category.symbolName }
        return signal.drivers.first?.symbolName ?? "smallcircle.filled.circle"
    }
}

private struct CompactSignalRow: View {
    var signal: CompassSignal

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(signal.tier.tint.opacity(0.65))
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(signal.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)
                Text(signal.reason)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.mutedInk)
                    .lineLimit(2)
            }
            Spacer()
            Text(shortDate(signal.date))
                .font(.caption2)
                .foregroundStyle(AppTheme.mutedInk)
        }
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

struct CompassSignalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    var signal: CompassSignal

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label(signal.tier.title, systemImage: signal.event?.category.symbolName ?? signal.drivers.first?.symbolName ?? "sparkles")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(signal.tier.tint)
                            Spacer()
                            CompassScorePill(title: "分数", value: "\(Int(signal.score))", color: signal.tier.tint)
                        }

                        Text(signal.title)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(signal.dayText)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                    .padding(16)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.65), lineWidth: 1))

                    CompassDetailPanel(title: "为什么推给你", symbol: "dot.radiowaves.left.and.right", text: signal.reason)
                    CompassDetailPanel(title: "事件内容", symbol: "doc.text", text: signal.detail)

                    if !signal.drivers.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("传导节点")
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)
                            ForEach(signal.drivers) { driver in
                                DriverImpactLine(driver: driver, signal: signal)
                            }
                        }
                    }

                    if !signal.holdings.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("命中持仓")
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)
                            ForEach(signal.holdings) { stock in
                                HStack {
                                    Text(stock.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.ink)
                                    Spacer()
                                    Text(stock.displayCode)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.mutedInk)
                                }
                                .padding(11)
                                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        CompassMetaRow(title: "来源", value: signal.sourceName)
                        if let relatedCode = signal.relatedCode {
                            CompassMetaRow(title: "代码", value: relatedCode)
                        }
                        if let url = signal.event?.sourceURL {
                            Link(destination: url) {
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
                .padding(.bottom, 20)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle("罗盘详情")
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
}

private struct CompassMetaRow: View {
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
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

private struct DriverImpactLine: View {
    var driver: ExposureDriver
    var signal: CompassSignal

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label(driver.title, systemImage: driver.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text(driver.hasHiddenConcentration ? "集中" : "\(driver.reliableEdgeCount) 边")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(driver.hasHiddenConcentration ? AppTheme.amber : AppTheme.mutedInk)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background((driver.hasHiddenConcentration ? AppTheme.amber : AppTheme.line).opacity(0.12), in: Capsule())
            }
            Text(driver.aiNote)
                .font(.footnote)
                .foregroundStyle(AppTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(driver.edges) { edge in
                        CompassTextChip(text: "\(edge.stockName) \(edge.kind.title)", color: edge.kind.tint)
                    }
                }
            }
        }
        .padding(12)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.65), lineWidth: 1))
    }
}

private struct CompassDetailPanel: View {
    var title: String
    var symbol: String
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
            Text(text)
                .font(.body)
                .foregroundStyle(AppTheme.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.65), lineWidth: 1))
    }
}

private struct SectionLabel: View {
    var title: String
    var count: String
    var color: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(color)
            Rectangle()
                .fill(AppTheme.line.opacity(0.8))
                .frame(height: 1)
            Text(count)
                .font(.caption)
                .foregroundStyle(AppTheme.mutedInk)
        }
    }
}

private struct CompassScorePill: View {
    var title: String
    var value: String
    var color: Color

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .foregroundStyle(AppTheme.mutedInk)
            Text(value)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .font(.caption)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(AppTheme.paper.opacity(0.78), in: Capsule())
    }
}

private struct CompassTextChip: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(color.opacity(0.09), in: Capsule())
    }
}
