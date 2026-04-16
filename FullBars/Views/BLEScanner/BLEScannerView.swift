import SwiftUI

struct BLEScannerView: View {
    @State var viewModel = BLEScannerViewModel()
    @State private var sortOption: SortOption = .rssi
    @State private var showDeviceList = false
    @Environment(\.displayMode) private var displayMode

    enum SortOption {
        case rssi, name, lastSeen
    }

    let primaryColor = FullBars.Design.Colors.accentCyan

    var sortedDevices: [BLEDeviceInfo] {
        switch sortOption {
        case .rssi: return viewModel.devices.sorted { $0.rssi > $1.rssi }
        case .name: return viewModel.devices.sorted { $0.name < $1.name }
        case .lastSeen: return viewModel.devices.sorted { $0.lastSeen > $1.lastSeen }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FullBars.Design.Colors.primaryBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if displayMode == .basic {
                        basicCongestionView
                    } else {
                        technicalCongestionView
                    }

                    // Scan Button & Sort Menu
                    scanControls

                    // Device List
                    if displayMode == .basic {
                        basicDeviceArea
                    } else {
                        technicalDeviceList
                    }
                }
            }
            .navigationTitle(displayMode == .basic ? "Congestion" : "BLE Scanner")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Basic Mode

    private var basicCongestionView: some View {
        VStack(spacing: 16) {
            // Simple congestion visual
            ZStack {
                Circle()
                    .fill(congestionColor.opacity(0.15))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(congestionColor.opacity(0.3))
                    .frame(width: 80, height: 80)

                Image(systemName: congestionIcon)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(congestionColor)
            }

            VStack(spacing: 6) {
                Text("Your area has \(viewModel.congestionLevel.lowercased()) wireless congestion")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(congestionAdvice)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Expandable device count
            if viewModel.deviceCount > 0 {
                Button(action: { showDeviceList.toggle() }) {
                    HStack(spacing: 6) {
                        Text("\(viewModel.deviceCount) devices nearby")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.semibold)
                        Image(systemName: showDeviceList ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(primaryColor)
                }
            }
        }
        .padding(20)
        .background(FullBars.Design.Colors.primaryBackground)
    }

    private var basicDeviceArea: some View {
        Group {
            if showDeviceList && !sortedDevices.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(sortedDevices) { device in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(signalColor(device.rssi))
                                    .frame(width: 10, height: 10)
                                Text(device.name)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                            )
                        }
                    }
                    .padding(12)
                }
            } else if sortedDevices.isEmpty {
                emptyDeviceView
            } else {
                Spacer()
            }
        }
    }

    // MARK: - Technical Mode

    private var technicalCongestionView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(congestionColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(congestionColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Congestion Level")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(viewModel.congestionLevel)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(viewModel.deviceCount)")
                            .font(.system(.caption2, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(primaryColor.opacity(0.2))
                    .foregroundStyle(primaryColor)
                    .cornerRadius(6)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Strong Signals")
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("\(viewModel.strongDeviceCount)")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Interference Risk")
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(viewModel.interferenceRisk == "Low" ? "Low" : "High")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(viewModel.interferenceRisk == "Low" ? .green : .red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(FullBars.Design.Colors.primaryBackground)
    }

    private var technicalDeviceList: some View {
        Group {
            if sortedDevices.isEmpty {
                emptyDeviceView
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(sortedDevices) { device in
                            BLEDeviceRow(
                                device: device,
                                signalColor: signalColor(device.rssi),
                                timeAgo: timeAgo(device.lastSeen)
                            )
                            .accessibilityLabel("\(device.name), Signal: \(device.rssi) dBm")
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    // MARK: - Shared Components

    private var scanControls: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.toggleScan() }) {
                HStack(spacing: 8) {
                    if viewModel.isScanning {
                        ZStack {
                            Circle().fill(primaryColor).frame(width: 6, height: 6)
                                .scaleEffect(1.2)
                                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: viewModel.isScanning)
                            Circle().stroke(primaryColor, lineWidth: 1).frame(width: 10, height: 10)
                                .opacity(0.5).scaleEffect(1.5)
                                .animation(.easeOut(duration: 0.6).repeatForever(autoreverses: false), value: viewModel.isScanning)
                        }
                        Text("Stop Scan")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                    } else {
                        Image(systemName: "play.circle.fill").font(.system(size: 16))
                        Text("Start Scan")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(viewModel.isScanning ? primaryColor : Color.white.opacity(0.1), lineWidth: viewModel.isScanning ? 1.5 : 0)
                        )
                )
                .foregroundStyle(viewModel.isScanning ? primaryColor : .white)
                .shadow(color: viewModel.isScanning ? primaryColor.opacity(0.4) : .clear, radius: 8, x: 0, y: 4)
            }
            .sensoryFeedback(.selection, trigger: viewModel.isScanning)

            if displayMode == .technical {
                Menu {
                    Picker("Sort By", selection: $sortOption) {
                        Text("Signal (RSSI)").tag(SortOption.rssi)
                        Text("Name").tag(SortOption.name)
                        Text("Last Seen").tag(SortOption.lastSeen)
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        )
                        .foregroundStyle(primaryColor)
                }
            }
        }
        .padding(12)
        .background(FullBars.Design.Colors.primaryBackground)
    }

    private var emptyDeviceView: some View {
        VStack(spacing: 16) {
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(primaryColor.opacity(0.2), lineWidth: 1.5)
                        .frame(width: CGFloat(60 - index * 20), height: CGFloat(60 - index * 20))
                        .scaleEffect(viewModel.isScanning ? 1.2 : 0.8)
                        .opacity(viewModel.isScanning ? 0 : 1)
                        .animation(
                            Animation.easeOut(duration: 1.5).repeatForever(autoreverses: false).delay(Double(index) * 0.3),
                            value: viewModel.isScanning
                        )
                }
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(primaryColor)
            }
            Text(viewModel.isScanning ? "Scanning for devices..." : "No devices found")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FullBars.Design.Colors.primaryBackground)
    }

    // MARK: - Helpers

    private var congestionColor: Color {
        switch viewModel.congestionLevel {
        case "High": return .red
        case "Medium": return .orange
        default: return .green
        }
    }

    private var congestionIcon: String {
        switch viewModel.congestionLevel {
        case "High": return "wifi.exclamationmark"
        case "Medium": return "wifi"
        default: return "wifi"
        }
    }

    private var congestionAdvice: String {
        switch viewModel.congestionLevel {
        case "High": return "Many wireless devices nearby may be slowing your connection. Try changing your WiFi channel."
        case "Medium": return "Some wireless devices are nearby but shouldn't cause major issues."
        default: return "The wireless environment is clear. You should have minimal interference."
        }
    }

    private func signalColor(_ rssi: Int) -> Color {
        switch rssi {
        case -50...(-1): return primaryColor
        case -60...(-51): return .green
        case -70...(-61): return .amber
        default: return .red
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        else if interval < 3600 { return "\(Int(interval / 60))m ago" }
        else { return "\(Int(interval / 3600))h ago" }
    }
}

struct BLEDeviceRow: View {
    let device: BLEDeviceInfo
    let signalColor: Color
    let timeAgo: String

    var signalBars: Int {
        switch device.rssi {
        case -50...(-1): return 5
        case -60...(-51): return 4
        case -70...(-61): return 3
        case -80...(-71): return 2
        default: return 1
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(device.name)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { bar in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(bar <= signalBars ? signalColor : Color.white.opacity(0.2))
                                .frame(width: 3, height: CGFloat(6 + bar * 2))
                        }
                    }
                    Text("\(device.rssi) dBm")
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.7))
                    if device.isConnectable {
                        Text("Connectable")
                            .font(.system(.caption2, design: .rounded))
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .cornerRadius(4)
                    }
                }
            }
            Spacer()
            Text(timeAgo)
                .font(.system(.caption2, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(signalColor.opacity(0.2), lineWidth: 1))
        )
        .shadow(color: signalColor.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    BLEScannerView()
        .environment(\.displayMode, .technical)
}
