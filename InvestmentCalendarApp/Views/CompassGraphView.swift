import SwiftUI

struct CompassGraphCard: View {
    @EnvironmentObject private var store: InvestmentCalendarStore
    @State private var selectedDriver: ExposureDriver?

    var body: some View {
        let drivers = ExposureGraphProvider.drivers(for: store.watchlist, marginSnapshots: store.marginSnapshots)
        let concentration = ExposureGraphProvider.hiddenConcentration(for: drivers)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Label("AI 联动图谱", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text("稳定边计入集中度；符号翻转边只保留解释，不做结论")
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }
                Spacer()
                Text("\(drivers.count) 节点")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedInk)
            }

            if let concentration {
                Button {
                    selectedDriver = concentration.driver
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.amber)
                            .frame(width: 28, height: 28)
                            .background(AppTheme.amber.opacity(0.10), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(concentration.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                            Text(concentration.detail)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.mutedInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                    .padding(11)
                    .background(AppTheme.amber.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.amber.opacity(0.30), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            ExposureLegend()

            if drivers.isEmpty {
                Text("添加自选股后，图谱会自动映射到利率、商品、产业价格、港股流动性和两融杠杆。")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(11)
                    .background(AppTheme.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 9) {
                    ForEach(drivers.prefix(7)) { driver in
                        Button {
                            selectedDriver = driver
                        } label: {
                            DriverNodeRow(driver: driver)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.65), lineWidth: 1))
        .sheet(item: $selectedDriver) { driver in
            DriverDetailView(driver: driver)
        }
    }
}

private struct ExposureLegend: View {
    var body: some View {
        HStack(spacing: 8) {
            LegendPill(title: "STABLE+", color: AppTheme.matcha)
            LegendPill(title: "STABLE-", color: AppTheme.vermilion)
            LegendPill(title: "UNSTABLE", color: AppTheme.amber)
            LegendPill(title: "LEVERAGE", color: AppTheme.sumiBlue)
        }
    }
}

private struct LegendPill: View {
    var title: String
    var color: Color

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 3)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DriverNodeRow: View {
    var driver: ExposureDriver

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: driver.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(driver.direction.tint)
                    .frame(width: 32, height: 32)
                    .background(driver.direction.tint.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(driver.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        if driver.hasHiddenConcentration {
                            Text("集中")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppTheme.amber)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.amber.opacity(0.12), in: Capsule())
                        }
                    }
                    Text(driver.subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(driver.level)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(driver.move)
                        .font(.caption2)
                        .foregroundStyle(driver.direction.tint)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(driver.edges) { edge in
                        HStack(spacing: 4) {
                            Text(edge.stockName)
                            Text("ρ \(edge.rhoText)")
                                .foregroundStyle(edge.kind.tint)
                            Text(edge.kind.title)
                                .fontWeight(.bold)
                        }
                        .font(.caption2)
                        .foregroundStyle(AppTheme.mutedInk)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(edge.kind.tint.opacity(0.08), in: Capsule())
                    }
                }
            }
        }
        .padding(11)
        .background(AppTheme.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct DriverDetailView: View {
    @Environment(\.dismiss) private var dismiss
    var driver: ExposureDriver

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(driver.category, systemImage: driver.symbolName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(driver.direction.tint)
                        Text(driver.title)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        HStack(spacing: 8) {
                            GraphMetricChip(title: "水平", value: driver.level, color: driver.direction.tint)
                            GraphMetricChip(title: "状态", value: driver.move, color: driver.direction.tint)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.65), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("持仓边")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        ForEach(driver.edges) { edge in
                            EdgeDetailCard(edge: edge)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Label("AI 节点解读", systemImage: "sparkles")
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        Text(driver.aiNote)
                            .font(.body)
                            .foregroundStyle(AppTheme.ink)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.amber.opacity(0.30), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(driver.eventTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        Text(driver.eventDetail)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(AppTheme.paper.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))

                    Text("相关系数和稳定性区块目前来自罗盘框架的本地规则层；后续可替换为每日 rolling linkage 计算结果。不构成投资建议。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                        .lineSpacing(3)
                }
                .padding(18)
                .padding(.bottom, 20)
            }
            .background(AppTheme.paper.ignoresSafeArea())
            .navigationTitle("节点详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct EdgeDetailCard: View {
    var edge: ExposureHoldingEdge

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(edge.stockName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(edge.code)
                        .font(.caption)
                        .foregroundStyle(AppTheme.mutedInk)
                }
                Spacer()
                Text(edge.kind.title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(edge.kind.tint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(edge.kind.tint.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 8) {
                GraphMetricChip(title: "ρ/温度", value: edge.rhoText, color: edge.kind.tint)
                GraphMetricChip(title: "可信度", value: edge.reliabilityText, color: edge.kind.tint)
            }

            CorrelationBlocks(edge: edge)

            Text(edge.note)
                .font(.footnote)
                .foregroundStyle(AppTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line.opacity(0.65), lineWidth: 1))
    }
}

private struct GraphMetricChip: View {
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
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .font(.caption)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(AppTheme.paper.opacity(0.72), in: Capsule())
    }
}

private struct CorrelationBlocks: View {
    var edge: ExposureHoldingEdge

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(edge.blocks.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: value))
                        .frame(height: max(5, CGFloat(abs(value)) * 34))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 38, alignment: .bottom)

            Text("不重叠区块相关性 · 左旧右新")
                .font(.caption2)
                .foregroundStyle(AppTheme.mutedInk)
        }
    }

    private func color(for value: Double) -> Color {
        if abs(value) < 0.15 { return AppTheme.line }
        return value > 0 ? AppTheme.matcha : AppTheme.vermilion
    }
}
