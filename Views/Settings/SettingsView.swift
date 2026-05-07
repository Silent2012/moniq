import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @ObservedObject var vm: SettingsViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Spacing.lg) {
                generalSection
                    .slideUpOnAppear(delay: 0)
                alertsSection
                    .slideUpOnAppear(delay: 0.06)
                dataSection
                    .slideUpOnAppear(delay: 0.1)
                privacyBadge
                    .slideUpOnAppear(delay: 0.14)
            }
            .padding(DS.Layout.contentPadding)
        }
        .background(DS.Colors.primaryBackground)
        .alert("Clear All History?", isPresented: $vm.showClearConfirmation) {
            Button("Clear Everything", role: .destructive) { vm.clearAllHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all app usage history, battery records, and analytics data. This cannot be undone.")
        }
    }

    // MARK: - General

    private var generalSection: some View {
        settingsSection(title: "General", icon: "gearshape.fill", color: DS.Colors.secondaryText) {
            SettingsRow(icon: "power", iconColor: DS.Colors.successGreen, title: "Launch at Login",
                        subtitle: "Start moniq when you log in") {
                Toggle("", isOn: $vm.launchAtLogin).labelsHidden().toggleStyle(.switch)
            }

            Divider().background(DS.Colors.cardBorder.opacity(0.5)).padding(.leading, 44)

            SettingsRow(icon: "timer", iconColor: DS.Colors.secondaryAccent, title: "Update Interval",
                        subtitle: "How often stats are refreshed") {
                Picker("", selection: $vm.updateIntervalIndex) {
                    ForEach(Array(vm.updateIntervalOptions.enumerated()), id: \.offset) { i, opt in
                        Text(opt.label).tag(i)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
                .background(DS.Colors.cardBorder.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Divider().background(DS.Colors.cardBorder.opacity(0.5)).padding(.leading, 44)

            SettingsRow(icon: "menubar.rectangle", iconColor: DS.Colors.primaryAccent, title: "Show in Menu Bar",
                        subtitle: "Display metrics in the menu bar") {
                Toggle("", isOn: $vm.showInMenuBar).labelsHidden().toggleStyle(.switch)
            }

            Divider().background(DS.Colors.cardBorder.opacity(0.5)).padding(.leading, 44)

            SettingsRow(icon: "square.grid.3x3.fill", iconColor: DS.Colors.pinkAccent, title: "Show in Dock",
                        subtitle: "Show moniq in the Dock") {
                Toggle("", isOn: $vm.showInDock).labelsHidden().toggleStyle(.switch)
            }

            Divider().background(DS.Colors.cardBorder.opacity(0.5)).padding(.leading, 44)

            SettingsRow(icon: "paintpalette.fill", iconColor: DS.Colors.primaryAccent,
                        title: "Coloured Menu Bar Icons",
                        subtitle: "Use accent colours in the menu bar, or plain white") {
                Toggle("", isOn: $vm.menuBarColoured).labelsHidden().toggleStyle(.switch)
            }

            Divider().background(DS.Colors.cardBorder.opacity(0.5)).padding(.leading, 44)

            SettingsRow(icon: "pin.fill", iconColor: DS.Colors.secondaryAccent,
                        title: "Pin Stats to Menu Bar",
                        subtitle: "Use the 􀎧 pin button on each Dashboard card") {
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Colors.tertiaryText)
            }
        }
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        settingsSection(title: "Alerts & Notifications", icon: "bell.badge.fill", color: DS.Colors.dangerRed) {
            SettingsRow(icon: "cpu", iconColor: DS.Colors.secondaryAccent, title: "CPU Alert Threshold",
                        subtitle: "Notify when CPU exceeds this level") {
                HStack(spacing: DS.Spacing.sm) {
                    Slider(value: $vm.cpuAlertThreshold, in: 50...95, step: 5)
                        .frame(width: 120).accentColor(DS.Colors.secondaryAccent)
                    Text(String(format: "%.0f%%", vm.cpuAlertThreshold))
                        .font(DS.Fonts.caption()).foregroundColor(DS.Colors.secondaryText)
                        .frame(width: 36).monospacedDigit()
                }
            }

            Divider().background(DS.Colors.cardBorder.opacity(0.5)).padding(.leading, 44)

            SettingsRow(icon: "memorychip", iconColor: DS.Colors.pinkAccent, title: "Memory Alert Threshold",
                        subtitle: "Notify when memory pressure is high") {
                HStack(spacing: DS.Spacing.sm) {
                    Slider(value: $vm.memAlertThreshold, in: 60...95, step: 5)
                        .frame(width: 120).accentColor(DS.Colors.pinkAccent)
                    Text(String(format: "%.0f%%", vm.memAlertThreshold))
                        .font(DS.Fonts.caption()).foregroundColor(DS.Colors.secondaryText)
                        .frame(width: 36).monospacedDigit()
                }
            }

            Divider().background(DS.Colors.cardBorder.opacity(0.5)).padding(.leading, 44)

            SettingsRow(icon: "battery.25percent", iconColor: DS.Colors.warningAmber, title: "Battery Low Alert",
                        subtitle: "Notify when battery drops below this") {
                HStack(spacing: DS.Spacing.sm) {
                    Slider(value: $vm.batteryAlertLevel, in: 5...40, step: 5)
                        .frame(width: 120).accentColor(DS.Colors.warningAmber)
                    Text(String(format: "%.0f%%", vm.batteryAlertLevel))
                        .font(DS.Fonts.caption()).foregroundColor(DS.Colors.secondaryText)
                        .frame(width: 36).monospacedDigit()
                }
            }

            Divider().background(DS.Colors.cardBorder.opacity(0.5)).padding(.leading, 44)

            SettingsRow(icon: "network", iconColor: DS.Colors.successGreen, title: "Network Spike Alert",
                        subtitle: "Notify on unusual network activity") {
                Toggle("", isOn: $vm.networkSpikeAlert).labelsHidden().toggleStyle(.switch)
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        settingsSection(title: "Data & Privacy", icon: "lock.shield.fill", color: DS.Colors.successGreen) {
            SettingsRow(icon: "calendar.badge.clock", iconColor: DS.Colors.primaryAccent, title: "Data Retention",
                        subtitle: "How long to keep historical data") {
                Picker("", selection: $vm.dataRetentionDays) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
                .labelsHidden()
                .frame(width: 100)
                .background(DS.Colors.cardBorder.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Divider().background(DS.Colors.cardBorder.opacity(0.5)).padding(.leading, 44)

            SettingsRow(icon: "square.and.arrow.up", iconColor: DS.Colors.secondaryAccent, title: "Export Data",
                        subtitle: "Save your analytics data to a file") {
                HStack(spacing: DS.Spacing.sm) {
                    exportButton("CSV",  format: .csv)
                    exportButton("JSON", format: .json)
                }
            }

            Divider().background(DS.Colors.cardBorder.opacity(0.5)).padding(.leading, 44)

            SettingsRow(icon: "trash.fill", iconColor: DS.Colors.dangerRed, title: "Clear All History",
                        subtitle: "Permanently delete all stored data") {
                Button("Clear") { vm.showClearConfirmation = true }
                    .font(DS.Fonts.caption())
                    .foregroundColor(DS.Colors.dangerRed)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(DS.Colors.dangerRed.opacity(0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(DS.Colors.dangerRed.opacity(0.3), lineWidth: 0.5))
                    .buttonStyle(.plain)
            }
        }
    }

    private func exportButton(_ label: String, format: ExportFormat) -> some View {
        Button(label) { vm.exportData(format: format) }
            .font(DS.Fonts.caption())
            .foregroundColor(DS.Colors.secondaryAccent)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(DS.Colors.secondaryAccent.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(DS.Colors.secondaryAccent.opacity(0.3), lineWidth: 0.5))
            .buttonStyle(.plain)
    }

    // MARK: - Privacy badge

    private var privacyBadge: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(DS.Colors.successGreen)
            Text("All data stays local. moniq never sends anything off your Mac.")
                .font(DS.Fonts.caption())
                .foregroundColor(DS.Colors.secondaryText)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(DS.Colors.successGreen.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(DS.Colors.successGreen.opacity(0.15), lineWidth: 0.5))
    }

    // MARK: - Section container

    private func settingsSection<C: View>(
        title: String, icon: String, color: Color,
        @ViewBuilder rows: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(DS.Fonts.metricLabel())
                    .foregroundColor(DS.Colors.secondaryText)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            GlowingCard(accentColor: color, padding: 0) {
                VStack(spacing: 0) { rows() }
                    .padding(.vertical, DS.Spacing.xs)
            }
        }
    }
}

// MARK: - SettingsRow

private struct SettingsRow<Control: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let control: Control

    init(icon: String, iconColor: Color, title: String, subtitle: String,
         @ViewBuilder control: () -> Control) {
        self.icon      = icon
        self.iconColor = iconColor
        self.title     = title
        self.subtitle  = subtitle
        self.control   = control()
    }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(DS.Fonts.metricLabel())
                    .foregroundColor(DS.Colors.primaryText)
                Text(subtitle)
                    .font(DS.Fonts.caption())
                    .foregroundColor(DS.Colors.tertiaryText)
                    .lineLimit(1)
            }
            Spacer()
            control
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }
}

// MARK: - Preview

#Preview {
    SettingsView(vm: SettingsViewModel())
        .frame(width: 800, height: 700)
        .background(DS.Colors.primaryBackground)
}
