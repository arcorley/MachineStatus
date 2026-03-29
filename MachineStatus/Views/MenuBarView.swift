import SwiftUI

struct MenuBarView: View {
    @Environment(SystemMonitorViewModel.self) private var viewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Machine Status")
                .font(.headline)

            Divider()

            // CPU
            HStack {
                Image(systemName: "cpu")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text("CPU")
                Spacer()
                Text(Format.percentage(viewModel.cpuMetrics.overallUsage / 100))
                    .monospacedDigit()
                    .foregroundStyle(colorForUsage(viewModel.cpuMetrics.overallUsage / 100))
            }

            // Memory
            HStack {
                Image(systemName: "memorychip")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text("Memory")
                Spacer()
                if viewModel.memoryMetrics.total > 0 {
                    let usage = Double(viewModel.memoryMetrics.used) / Double(viewModel.memoryMetrics.total)
                    Text(Format.percentage(usage))
                        .monospacedDigit()
                        .foregroundStyle(colorForUsage(usage))
                } else {
                    Text("--")
                }
            }

            Divider()

            Button("Open Dashboard") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first(where: { $0.title == "Machine Status" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 220)
    }

    private func colorForUsage(_ value: Double) -> Color {
        switch value {
        case 0..<0.6: return .green
        case 0.6..<0.85: return .yellow
        default: return .red
        }
    }
}
