import SwiftUI

@main
struct MachineStatusApp: App {
    @State private var viewModel = SystemMonitorViewModel()

    var body: some Scene {
        Window("Machine Status", id: "main") {
            DashboardView()
                .environment(viewModel)
                .onAppear { viewModel.start() }
                .onDisappear { viewModel.stop() }
        }
        .defaultSize(width: 900, height: 700)

        MenuBarExtra {
            MenuBarView()
                .environment(viewModel)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
            Text(Format.percentage(viewModel.cpuMetrics.overallUsage / 100))
                .monospacedDigit()
        }
    }
}
