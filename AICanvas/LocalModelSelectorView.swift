import SwiftUI

// MARK: - Local Model Selector

struct LocalModelSelectorView: View {
    @ObservedObject var aiConfig: AIConfiguration
    @Binding var isPresented: Bool
    @StateObject private var manager = LocalModelManager.shared

    private let localColor = AIProvider.local.brandColor

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    LazyVStack(spacing: 14) {
                        // Installed models section
                        if manager.hasInstalledModels {
                            installedSection
                        }

                        // Available to download
                        downloadSection

                        // Storage note
                        storageNote
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(localColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(localColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Modelos Locais")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Roda no iPad · 100% offline · Sem API Key")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Button { isPresented = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
        .background(AppTheme.surface)
    }

    // MARK: - Installed Section

    private var installedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("INSTALADOS", icon: "checkmark.circle.fill", color: .green)

            VStack(spacing: 8) {
                ForEach(manager.catalog.filter { manager.isInstalled($0) }) { info in
                    InstalledModelRow(
                        info: info,
                        isActive: aiConfig.selectedModel.id == info.filename,
                        onSelect: {
                            aiConfig.setSelectedModel(AIModel(id: info.filename, name: info.name, provider: .local))
                            isPresented = false
                        },
                        onDelete: {
                            manager.deleteModel(info)
                            aiConfig.updateAvailableModels()
                        }
                    )
                }
            }
        }
    }

    // MARK: - Download Section

    private var downloadSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("DISPONÍVEIS PARA DOWNLOAD", icon: "arrow.down.circle", color: localColor)

            VStack(spacing: 8) {
                ForEach(manager.catalog.filter { !manager.isInstalled($0) }) { info in
                    DownloadModelRow(
                        info: info,
                        isDownloading: manager.downloadingModelId == info.id,
                        progress: manager.downloadingModelId == info.id ? manager.downloadProgress : 0,
                        downloadError: manager.downloadingModelId == info.id ? manager.downloadError : nil,
                        onDownload: { manager.download(info) },
                        onCancel: { manager.cancelDownload() }
                    )
                }
            }
        }
    }

    // MARK: - Storage Note

    private var storageNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textMuted)
            Text("Modelos são salvos no armazenamento do iPad e ficam disponíveis offline. Requerem Wi-Fi para download.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textMuted)
                .lineSpacing(2)
        }
        .padding(12)
        .background(AppTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border.opacity(0.5), lineWidth: 1))
    }

    private func sectionLabel(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(color)
            Text(text).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Installed Model Row

private struct InstalledModelRow: View {
    let info: LocalModelInfo
    let isActive: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirm = false

    private let localColor = AIProvider.local.brandColor

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Selection dot
                ZStack {
                    Circle()
                        .stroke(isActive ? localColor : AppTheme.border, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if isActive {
                        Circle().fill(localColor).frame(width: 11, height: 11)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(info.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    HStack(spacing: 6) {
                        paramBadge(info.parametersLabel)
                        paramBadge(info.quantization)
                        paramBadge(info.sizeLabel)
                    }
                }

                Spacer()

                if isActive {
                    Text("EM USO")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(localColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(localColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.danger)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.danger.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(isActive ? localColor.opacity(0.06) : AppTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? localColor.opacity(0.35) : AppTheme.border, lineWidth: isActive ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .alert("Remover modelo?", isPresented: $showDeleteConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Remover", role: .destructive, action: onDelete)
        } message: {
            Text("O arquivo \(info.filename) será deletado do iPad.")
        }
    }

    private func paramBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Download Model Row

private struct DownloadModelRow: View {
    let info: LocalModelInfo
    let isDownloading: Bool
    let progress: Double
    let downloadError: String?
    let onDownload: () -> Void
    let onCancel: () -> Void

    private let localColor = AIProvider.local.brandColor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                // Model icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(localColor.opacity(0.1))
                        .frame(width: 44, height: 44)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(localColor.opacity(0.2), lineWidth: 1))
                    Text(modelEmoji)
                        .font(.system(size: 22))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(info.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(info.description)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        paramBadge(info.parametersLabel)
                        paramBadge(info.quantization)
                        Text(info.sizeLabel)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(localColor)
                    }
                }

                Spacer()

                downloadButton
            }

            if isDownloading {
                downloadProgressBar
            }

            if let err = downloadError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text(err)
                        .font(.system(size: 11))
                        .lineLimit(2)
                }
                .foregroundStyle(AppTheme.danger)
            }
        }
        .padding(14)
        .background(AppTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1))
    }

    private var downloadButton: some View {
        Group {
            if isDownloading {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.danger)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(localColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var downloadProgressBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Baixando...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(localColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(AppTheme.border).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(localColor)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.linear(duration: 0.2), value: progress)
                }
            }
            .frame(height: 6)
        }
    }

    private var modelEmoji: String {
        switch info.promptFormat {
        case .llama3: return "🦙"
        case .chatml: return "🤖"
        case .phi3: return "🔷"
        }
    }

    private func paramBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    LocalModelSelectorView(
        aiConfig: AIConfiguration(),
        isPresented: .constant(true)
    )
}
