import SwiftUI

struct WatchlistView: View {
    @EnvironmentObject private var store: InvestmentCalendarStore
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showingAdd = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus")
                                .font(.headline.weight(.semibold))
                                .frame(width: 34, height: 34)
                                .background(AppTheme.ink, in: Circle())
                                .foregroundStyle(AppTheme.card)
                            Text("添加自选股")
                                .font(.headline)
                                .foregroundStyle(AppTheme.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.mutedInk)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(AppTheme.card)
                }

                Section {
                    ForEach(store.watchlist) { stock in
                        StockWatchRow(stock: stock)
                        .listRowBackground(AppTheme.card)
                    }
                    .onDelete(perform: store.deleteStocks)
                }
            }
            .navigationTitle("自选股")
            .scrollContentBackground(.hidden)
            .background(AppTheme.paper)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("新增股票")
                }
            }
            .tint(AppTheme.vermilion)
            .sheet(isPresented: $showingAdd) {
                AddStockView()
            }
        }
    }
}

private struct StockWatchRow: View {
    @EnvironmentObject private var store: InvestmentCalendarStore
    var stock: WatchStock

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stock.name)
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text(stock.displayCode)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.mutedInk)
                }

                Spacer()

                Text(stock.market.rawValue)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppTheme.paper, in: Capsule())
                    .foregroundStyle(AppTheme.mutedInk)
            }

            if let nextEvent = store.nextEvent(for: stock) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: nextEvent.category.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(nextEvent.category.tint)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(nextEvent.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(2)
                        Text("\(DateKeys.displayDay.string(from: nextEvent.date)) · \(nextEvent.category.title)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.paper.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
            } else {
                Text(store.isRefreshing ? "正在抓取日程" : "暂无未来披露日程")
                    .font(.caption)
                    .foregroundStyle(AppTheme.mutedInk)
            }
        }
        .padding(.vertical, 5)
    }
}

struct AddStockView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: InvestmentCalendarStore
    @State private var name = ""
    @State private var code = ""
    @State private var market: Market = .aShare
    @State private var hkexStockId = ""
    @State private var isResolving = false
    @State private var note: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名称，例如 中际旭创", text: $name)
                    TextField("代码，例如 600519 或 00700", text: $code)
                        .keyboardType(.numbersAndPunctuation)
                    Picker("市场", selection: $market) {
                        ForEach(Market.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    if market == .hk {
                        TextField("HKEX stockId，可选", text: $hkexStockId)
                            .keyboardType(.numbersAndPunctuation)
                    }
                    if market == .aShare {
                        Button {
                            Task { await resolveAStock() }
                        } label: {
                            HStack {
                                Text(isResolving ? "识别中" : "自动识别A股")
                                Spacer()
                                if isResolving {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isResolving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if let note {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.mutedInk)
                    }
                }

                Section {
                    Button("保存并抓取日程") {
                        Task { await save() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isResolving)
                }
                .listRowBackground(AppTheme.card)
            }
            .navigationTitle("新增股票")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(AppTheme.paper)
            .tint(AppTheme.vermilion)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func resolveAStock() async {
        isResolving = true
        defer { isResolving = false }
        let keyword = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let stock = await store.resolveAStock(keyword: keyword) else {
            note = "未识别到A股代码"
            return
        }
        name = stock.name
        code = stock.code
        note = "已识别：\(stock.name) \(stock.code)"
    }

    private func save() async {
        var normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        if market == .aShare, normalizedCode.isEmpty, let stock = await store.resolveAStock(keyword: normalizedName) {
            normalizedName = stock.name
            normalizedCode = stock.code
        }

        guard !normalizedName.isEmpty, !normalizedCode.isEmpty else {
            note = "请填写名称和代码"
            return
        }

        let stock = WatchStock(
            name: normalizedName,
            code: normalizedCode,
            market: market,
            hkexStockId: hkexStockId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : hkexStockId
        )
        store.addStock(stock)
        await store.refresh()
        dismiss()
    }
}
