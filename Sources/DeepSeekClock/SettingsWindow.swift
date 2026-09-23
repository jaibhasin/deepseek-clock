//
//  SettingsWindow.swift
//  DeepSeek Clock
//
//  ┌──────────────────────────────── PURPOSE ─────────────────────────────────────┐
//  │ The standalone settings window.                                              │
//  │                                                                              │
//  │ For now it holds a single preference: which time zone the app displays        │
//  │ transition times in. DeepSeek always bills in UTC, so this never changes      │
//  │ peak/off-peak — only the wall-clock time the user reads.                      │
//  │                                                                              │
//  │ Kept separate from the dropdown panel so the panel can stay a fixed-size      │
//  │ popover and the settings window can be a normal, roomy macOS window.          │
//  └──────────────────────────────────────────────────────────────────────────────┘
//
import AppKit
import SwiftUI

/// Presentation for the settings window. Binds directly to `ClockModel`, which
/// owns and persists the preference.
struct SettingsView: View {
    @ObservedObject var clock: ClockModel
    @State private var query = ""

    private var filteredIdentifiers: [String] {
        let all = DisplayTimeZone.selectableIdentifiers
        guard !query.isEmpty else { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    private var nowText: String {
        let formatter = DateFormatter()
        formatter.timeZone = clock.displayTimeZone.timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            searchField
            timeZoneList
        }
        .padding(16)
        .frame(width: 360, height: 460)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Time zone")
                .font(.system(size: 15, weight: .semibold))
            Text("Peak and off-peak always follow DeepSeek's UTC schedule. "
                 + "Choose which time zone the countdown is shown in.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(clock.displayTimeZone.displayName) · now \(nowText)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search time zones", text: $query)
                .textFieldStyle(.plain)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .font(.system(size: 12))
        .padding(7)
        .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
    }

    private var timeZoneList: some View {
        List {
            row(title: "System",
                subtitle: "Follow your Mac",
                isSelected: clock.displayTimeZone.isSystem) {
                select(nil)
            }

            ForEach(filteredIdentifiers, id: \.self) { identifier in
                row(title: identifier.replacingOccurrences(of: "_", with: " "),
                    subtitle: offsetLabel(for: identifier),
                    isSelected: clock.displayTimeZone.identifier == identifier) {
                    select(identifier)
                }
            }
        }
        .listStyle(.inset)
        .frame(maxHeight: .infinity)
    }

    private func row(title: String,
                     subtitle: String,
                     isSelected: Bool,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12))
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func offsetLabel(for identifier: String) -> String {
        guard let zone = TimeZone(identifier: identifier) else { return "" }
        return DisplayTimeZone.offsetLabel(zone)
    }

    private func select(_ identifier: String?) {
        clock.displayTimeZone = DisplayTimeZone(identifier: identifier)
    }
}

/// Owns the settings `NSWindow`, creating it lazily and reusing it afterwards so
/// the window keeps its position between visits.
final class SettingsWindowController {
    private let clock: ClockModel
    private var window: NSWindow?

    init(clock: ClockModel) {
        self.clock = clock
    }

    /// Brings the settings window to the front, creating it on first use.
    func show() {
        if window == nil { window = makeWindow() }
        // The app is an accessory (no Dock icon), so explicitly activate to make
        // sure the new window actually comes forward.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: SettingsView(clock: clock))
        let window = NSWindow(contentViewController: hosting)
        window.title = "DeepSeek Clock Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
