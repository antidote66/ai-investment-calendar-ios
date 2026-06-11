import SwiftUI

struct AIProviderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: InvestmentCalendarStore
    @State private var selectedProvider: AIProviderKind = .gemini
    @State private var apiKey = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("AI 来源", selection: $selectedProvider) {
                        ForEach(AIProviderKind.allCases) { provider in
                            Text(provider.displayTitle).tag(provider)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedProvider.detail)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.mutedInk)
                        Text(providerStateText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(selectedProvider.requiresAPIKey && !store.hasAIAPIKey(for: selectedProvider) ? AppTheme.amber : AppTheme.matcha)
                    }
                    .padding(.vertical, 3)
                } header: {
                    Text("模型")
                }

                if selectedProvider.requiresAPIKey {
                    Section {
                        SecureField("粘贴 \(selectedProvider.title) API Key", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Button {
                            Task { await saveKeyAndProvider() }
                        } label: {
                            HStack {
                                Text(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "只切换来源" : "保存 Key 并切换")
                                Spacer()
                                if isSaving {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isSaving)

                        if store.hasAIAPIKey(for: selectedProvider) {
                            Button(role: .destructive) {
                                Task {
                                    await store.deleteAIAPIKey(for: selectedProvider)
                                    apiKey = ""
                                }
                            } label: {
                                Text("删除已保存 Key")
                            }
                        }
                    } header: {
                        Text("API Key")
                    } footer: {
                        Text("Key 只保存在这台 iPhone 的 Keychain，不写进代码仓库。没有 Key 时自动回落到本地规则。")
                    }
                } else {
                    Section {
                        Button {
                            Task { await saveKeyAndProvider() }
                        } label: {
                            HStack {
                                Text("使用本地规则")
                                Spacer()
                                if isSaving {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isSaving)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        SourceRow(name: "宏观日历", value: "Fed、U.S. BLS、国家统计局")
                        SourceRow(name: "A股公告", value: "东方财富公告、预约披露")
                        SourceRow(name: "港股公告", value: "HKEXnews")
                        SourceRow(name: "AI 兜底", value: "本地规则引擎")
                    }
                    .padding(.vertical, 3)
                } header: {
                    Text("数据管道")
                }
            }
            .navigationTitle("AI 数据源")
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        Task { await saveKeyAndProvider() }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                selectedProvider = store.aiProviderKind == .localRule ? .gemini : store.aiProviderKind
            }
        }
    }

    private var providerStateText: String {
        if selectedProvider == .localRule {
            return "当前不依赖外部模型。"
        }
        return store.hasAIAPIKey(for: selectedProvider) ? "已保存 Key。" : "未保存 Key。"
    }

    private func saveKeyAndProvider() async {
        isSaving = true
        defer { isSaving = false }

        if selectedProvider.requiresAPIKey {
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                await store.saveAIAPIKey(trimmed, for: selectedProvider)
            }
        }
        await store.setAIProvider(selectedProvider)
        dismiss()
    }
}

private struct SourceRow: View {
    var name: String
    var value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(name)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.footnote)
                .foregroundStyle(AppTheme.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
