import AppKit
import SwiftUI

struct MenuBarExtraView: View {
    @ObservedObject var viewModel: WindowListViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: viewModel.activePiPControllers.isEmpty ? "pip" : "pip.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                Text("PiPWindow")
                    .font(.system(size: 13, weight: .bold))

                if !viewModel.activePiPControllers.isEmpty {
                    Text("\(viewModel.activePiPControllers.count) LIVE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green, in: Capsule())
                }

                Spacer()

                Button {
                    Task {
                        await viewModel.refreshWindows()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderless)
                .help("Refresh Windows")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Search filter
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Filter windows…", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            // Window List with Thumbnails
            if !viewModel.hasPermission, viewModel.errorMessage != nil {
                VStack(spacing: 8) {
                    Text("Screen Recording Permission Required")
                        .font(.system(size: 12, weight: .semibold))
                    Button("Grant Access") {
                        viewModel.requestPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
            } else if viewModel.filteredWindows.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "macwindow")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("No matching windows")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(viewModel.filteredWindows) { item in
                            MenuBarWindowRow(
                                item: item,
                                thumbnail: viewModel.thumbnails[item.id],
                                isActivePiP: viewModel.activePiPControllers[item.id] != nil,
                                onTogglePiP: {
                                    viewModel.togglePiP(for: item)
                                }
                            )
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 320)
            }

            Divider()

            // Footer Actions
            HStack(spacing: 8) {
                Button {
                    NSApp.activate()
                    openWindow(id: "main-picker")
                } label: {
                    Label("Open Picker Window", systemImage: "macwindow.badge.plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderless)

                Spacer()

                if !viewModel.activePiPControllers.isEmpty {
                    Button("Close All PiP") {
                        viewModel.closeAllPiP()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                }

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 11))
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 340)
        .onAppear {
            Task {
                await viewModel.refreshWindows()
            }
        }
    }
}

struct MenuBarWindowRow: View {
    let item: WindowItem
    let thumbnail: NSImage?
    let isActivePiP: Bool
    let onTogglePiP: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTogglePiP) {
            HStack(spacing: 10) {
                // Mini Window Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.black.opacity(0.8))

                    if let thumbnail = thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .padding(2)
                    } else if let icon = item.appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                }
                .frame(width: 64, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if let icon = item.appIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 12, height: 12)
                        }
                        Text(item.appName)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("• \(item.dimensionsText)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: isActivePiP ? "pip.exit" : "pip.enter")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isActivePiP ? .red : Color.accentColor)
                    .padding(6)
                    .background(
                        (isActivePiP ? Color.red : Color.accentColor).opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isActivePiP ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
