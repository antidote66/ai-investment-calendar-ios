import SwiftUI

struct SourcesView: View {
    private let rows: [(String, String, String)] = [
        ("Federal Reserve", "FOMC 会议日程", "https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm"),
        ("U.S. BLS", "CPI、PPI、非农等发布时间", "https://www.bls.gov/schedule/2026/home.htm"),
        ("U.S. BLS API", "CPI 已公布数据", "https://api.bls.gov/publicAPI/v2/timeseries/data/"),
        ("国家统计局", "中国主要统计信息发布日程", "https://www.stats.gov.cn/sj/fbrc/bnxxfb/"),
        ("东方财富公告", "A股上市公司公告", "https://np-anotice-stock.eastmoney.com/"),
        ("东方财富预约披露", "A股财报披露日期", "https://data.eastmoney.com/bbsj/yysj.html"),
        ("HKEXnews", "港股上市公司公告", "https://www1.hkexnews.hk/search/titlesearch.xhtml")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(rows, id: \.0) { row in
                        if let url = URL(string: row.2) {
                            Link(destination: url) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(row.0)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(row.1)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("应用启动和手动刷新时抓取数据。宏观日程内置官方日程种子，并尝试在线补充；公告来源会随网页结构变化而需要维护。")
                }
            }
            .navigationTitle("数据来源")
        }
    }
}
