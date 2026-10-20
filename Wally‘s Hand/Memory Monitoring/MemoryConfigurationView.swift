import AaronUI
import SwiftUI

struct MemoryConfigurationView: View {
    @State private var sampler = MemorySampler()
    @State private var snapshot: MemorySnapshot?
    @State private var error: String?
    @State private var history: [MemorySnapshot] = []
    @State private var rate: MemorySwapRate?

    var body: some View {
        SettingsForm {
            HStack {
                Text("每 10 秒自动刷新").foregroundStyle(SettingsAppearance.muted)
                Spacer()
                if let snapshot {
                    Text(snapshot.date, style: .time).monospacedDigit()
                        .foregroundStyle(SettingsAppearance.muted)
                        .accessibilityLabel("上次更新 \(snapshot.date.formatted(date: .omitted, time: .standard))")
                }
            }
            .font(.caption)

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                if snapshot != nil {
                    Text("以下为上次成功读取的数据。")
                        .font(.caption).foregroundStyle(SettingsAppearance.muted)
                }
            }
            if let snapshot {
                overview(snapshot)
                processes(snapshot)
            } else if error == nil {
                ProgressView("正在读取内存信息…").frame(maxWidth: .infinity)
            }
        }
        .task {
            history = []
            rate = nil
            snapshot = nil
            while !Task.isCancelled {
                do {
                    let next = try await sampler.sample()
                    guard !Task.isCancelled else { return }
                    rate = snapshot.flatMap { MemorySwapRate(previous: $0, current: next) }
                    history.removeAll { next.date.timeIntervalSince($0.date) > 300 }
                    history.append(next)
                    snapshot = next
                    error = nil
                } catch {
                    guard !Task.isCancelled else { return }
                    rate = nil
                    self.error = error.localizedDescription
                }
                do { try await Task.sleep(for: .seconds(10)) }
                catch { return }
            }
        }
    }

    private func overview(_ data: MemorySnapshot) -> some View {
        SettingsSection("内存概况") {
            VStack(alignment: .leading, spacing: 12) {
                Text("内存压力").font(.subheadline).foregroundStyle(SettingsAppearance.muted)
                Label(pressureTitle(data.pressure), systemImage: pressureSymbol(data.pressure))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(pressureColor(data.pressure))
                Text(pressureDescription(data.pressure))
                    .font(.callout).foregroundStyle(SettingsAppearance.muted)
                MemoryPressureHistoryView(samples: history, end: data.date)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Swap 实时活动").font(.headline)
                HStack(spacing: 24) {
                    swapActivity("换入", value: rate?.incoming, detail: "从磁盘读回")
                    swapActivity("换出", value: rate?.outgoing, detail: "写入磁盘以腾出内存")
                }
                Text(rate.map { "最近 \(Int($0.interval.rounded())) 秒的平均速率" }
                     ?? "等待下一次采样，约 10 秒后显示速率")
                    .font(.caption).foregroundStyle(SettingsAppearance.muted)
            }
            Text("容量明细").font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("物理内存")
                    Spacer()
                    Text("\(bytes(data.used)) / \(bytes(data.total))").monospacedDigit()
                }
                ProgressView(value: data.fraction)
                    .tint(SettingsAppearance.muted)
                    .accessibilityLabel("物理内存使用率")
                    .accessibilityValue(data.fraction.formatted(.percent.precision(.fractionLength(0))))
                Text("已使用 \(data.fraction.formatted(.percent.precision(.fractionLength(0)))) · 不含可回收文件缓存")
                    .font(.caption).foregroundStyle(SettingsAppearance.muted)
            }
            metric("其中已压缩", value: bytes(data.compressed), detail: "已包含在物理内存占用中")
            metric("Swap 已用", value: data.swapUsed.map(bytes) ?? "无法读取",
                   detail: "磁盘交换空间，不计入物理内存容量")
        }
    }

    private func swapActivity(_ title: String, value: Double?, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.subheadline)
            Text(value.map { "\(($0 / 1_000_000).formatted(.number.precision(.fractionLength(2)))) MB/s" } ?? "—")
                .font(.title3.weight(.medium)).monospacedDigit()
            Text(detail).font(.caption).foregroundStyle(SettingsAppearance.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pressureDescription(_ pressure: MemorySnapshot.Pressure) -> String {
        switch pressure {
        case .normal: "当前内存资源能够满足使用需求。"
        case .warning: "内存资源偏紧张，建议关闭不用的应用。"
        case .critical: "内存资源严重不足，请关闭不用的应用以释放内存。"
        case .unknown: "暂时无法读取系统内存压力。"
        }
    }

    private func processes(_ data: MemorySnapshot) -> some View {
        SettingsSection("内存占用前五的进程") {
            if data.processes.isEmpty {
                Text("暂无可读取的进程信息").foregroundStyle(SettingsAppearance.muted)
            }
            ForEach(data.processes) { process in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(process.name).lineLimit(1).help(process.name)
                        Text("PID \(String(process.id))").font(.caption)
                            .foregroundStyle(SettingsAppearance.muted)
                    }
                    Spacer()
                    Text(bytes(process.bytes)).monospacedDigit().fontWeight(.medium)
                }
            }
            Text("按进程内存足迹排序，包含压缩内存；不按应用合并，也不可直接相加为物理内存用量。"
                 + (data.unreadableProcesses > 0 ? "本次有 \(data.unreadableProcesses) 个进程无法读取或已退出。" : ""))
                .font(.caption).foregroundStyle(SettingsAppearance.muted)
        }
    }

    private func metric(_ title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text(value).monospacedDigit()
            }
            Text(detail).font(.caption).foregroundStyle(SettingsAppearance.muted)
        }
    }

    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .memory)
    }

    private func pressureColor(_ pressure: MemorySnapshot.Pressure) -> Color {
        switch pressure {
        case .normal: .green
        case .warning: .orange
        case .critical: .red
        case .unknown: .secondary
        }
    }

    private func pressureTitle(_ pressure: MemorySnapshot.Pressure) -> String {
        switch pressure {
        case .normal: "正常"
        case .warning: "偏高"
        case .critical: "严重"
        case .unknown: "无法读取"
        }
    }

    private func pressureSymbol(_ pressure: MemorySnapshot.Pressure) -> String {
        switch pressure {
        case .normal: "checkmark.circle.fill"
        case .warning, .critical: "exclamationmark.triangle.fill"
        case .unknown: "questionmark.circle"
        }
    }
}
