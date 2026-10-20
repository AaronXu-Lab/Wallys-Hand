import Charts
import SwiftUI

/// Discrete kernel pressure samples, not an invented percentage or interpolated history.
struct MemoryPressureHistoryView: View {
    let samples: [MemorySnapshot]
    let end: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近 5 分钟").font(.caption).foregroundStyle(SettingsAppearance.muted)
            Chart(Array(samples.enumerated()), id: \.offset) { entry in
                if let level = level(entry.element.pressure) {
                    PointMark(x: .value("时间", entry.element.date), y: .value("压力", level))
                        .foregroundStyle(color(entry.element.pressure))
                        .symbolSize(28)
                }
            }
            .chartXScale(domain: end.addingTimeInterval(-300)...end)
            .chartYScale(domain: -0.3...2.3)
            .chartXAxis {
                AxisMarks(values: [end.addingTimeInterval(-300), end.addingTimeInterval(-150), end]) {
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 1, 2]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let number = value.as(Int.self) {
                            Text(["正常", "偏高", "严重"][number])
                        }
                    }
                }
            }
            .frame(height: 100)
            .accessibilityLabel("最近五分钟内存压力趋势")
            Text("每个点代表一次采样；仅记录本次打开页面后的数据，空白表示未采集或读取失败。")
                .font(.caption).foregroundStyle(SettingsAppearance.muted)
        }
    }

    private func level(_ pressure: MemorySnapshot.Pressure) -> Int? {
        switch pressure {
        case .normal: 0
        case .warning: 1
        case .critical: 2
        case .unknown: nil
        }
    }

    private func color(_ pressure: MemorySnapshot.Pressure) -> Color {
        switch pressure {
        case .normal: .green
        case .warning: .orange
        case .critical: .red
        case .unknown: .secondary
        }
    }
}
