import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: WindowListViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 250, maximum: 340), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            if !viewModel.activePiPControllers.isEmpty {
                activePiPBanner
                Divider()
            }

            if !viewModel.hasPermission, viewModel.errorMessage != nil {
                permissionRequiredView
            } else if viewModel.isLoading && viewModel.windows.isEmpty {
                ProgressView("Scanning application windows…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredWindows.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.filteredWindows) { item in
                            WindowCardView(
                                item: item,
                                thumbnail: viewModel.thumbnails[item.id],
                                isActivePiP: viewModel.activePiPControllers[item.id] != nil,
                                onTogglePiP: {
                                    viewModel.togglePiP(for: item)
                                }
                            )
                        }
                    }
                    .padding(18)
                }
            }
        }
        .frame(minWidth: 680, minHeight: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "pip.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("PiPWindow")
                    .font(.system(size: 16, weight: .bold))
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter windows or apps…", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 180)
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )

            Toggle("On-screen only", isOn: $viewModel.onScreenOnly)
                .toggleStyle(.checkbox)
                .font(.system(size: 12))
                .onChange(of: viewModel.onScreenOnly) {
                    Task {
                        await viewModel.refreshWindows()
                    }
                }

            Button {
                Task {
                    await viewModel.refreshWindows()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: [.command])
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var activePiPBanner: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)

            Text("\(viewModel.activePiPControllers.count) active Picture-in-Picture \(viewModel.activePiPControllers.count == 1 ? "window" : "windows")")
                .font(.system(size: 12, weight: .medium))

            Spacer()

            Button("Close All PiP") {
                viewModel.closeAllPiP()
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.08))
    }

    private var permissionRequiredView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.dashed.badge.record")
                .font(.system(size: 46))
                .foregroundStyle(Color.accentColor)

            Text("Screen Recording Permission Required")
                .font(.title3.bold())

            Text("PiPWindow uses macOS ScreenCaptureKit to stream any application window at 60 FPS into a floating Picture-in-Picture window.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)

            HStack(spacing: 12) {
                Button("Grant Permission") {
                    viewModel.requestPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Open System Settings") {
                    viewModel.openScreenRecordingSettings()
                }
                .controlSize(.large)

                Button("Retry") {
                    Task {
                        await viewModel.refreshWindows()
                    }
                }
                .controlSize(.large)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "macwindow.on.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(viewModel.searchText.isEmpty ? "No Capturable Windows Found" : "No Matching Windows")
                .font(.headline)

            Text(viewModel.searchText.isEmpty
                 ? "Open an application window on your desktop and click Refresh."
                 : "Try clearing your search filter.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WindowCardView: View {
    let item: WindowItem
    let thumbnail: NSImage?
    let isActivePiP: Bool
    let onTogglePiP: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Thumbnail Preview Area
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.82))

                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .padding(4)
                } else {
                    VStack(spacing: 6) {
                        if let icon = item.appIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 40, height: 40)
                        } else {
                            Image(systemName: "macwindow")
                                .font(.title)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Text(item.dimensionsText)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                // Dimensions badge
                VStack {
                    HStack {
                        if isActivePiP {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 6, height: 6)
                                Text("LIVE PiP")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.75), in: Capsule())
                        }
                        Spacer()
                        Text(item.dimensionsText)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.65), in: Capsule())
                    }
                    Spacer()
                }
                .padding(8)
            }
            .frame(height: 148)

            // Window Info + Action Button
            HStack(spacing: 10) {
                if let icon = item.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "app.fill")
                        .font(.title2)
                        .frame(width: 28, height: 28)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(item.appName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Button(action: onTogglePiP) {
                    HStack(spacing: 4) {
                        Image(systemName: isActivePiP ? "pip.exit" : "pip.enter")
                        Text(isActivePiP ? "Stop" : "PiP")
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(isActivePiP ? .red : .accentColor)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isActivePiP
                        ? Color.accentColor.opacity(0.8)
                        : (isHovered ? Color.primary.opacity(0.25) : Color.primary.opacity(0.08)),
                    lineWidth: isActivePiP ? 2 : 1
                )
        )
        .shadow(color: .black.opacity(isHovered ? 0.12 : 0.05), radius: isHovered ? 8 : 4, y: 2)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
