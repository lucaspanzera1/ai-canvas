// ModelComparisonView.swift
import SwiftUI

struct ModelComparisonView: View {
    let models: [ModelInfo]
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Comparar Modelos")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.surface)
                .overlay(Rectangle().fill(AppTheme.border).frame(height: 1), alignment: .bottom)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(models) { info in
                            HStack(spacing: 12) {
                                ProviderLogoView(provider: info.provider, size: 36, cornerRadius: 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(info.displayName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(info.provider.displayName)
                                        .font(.system(size: 11))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }

                                Spacer()

                                // Simple pill metrics
                                metricPill(title: "Velocidade", value: info.speed)
                                metricPill(title: "Qualidade", value: info.quality)
                                metricPill(title: "Custo", value: info.cost)

                                if info.visionCapable {
                                    Image(systemName: "eye.fill")
                                        .foregroundStyle(info.provider.brandColor)
                                }
                            }
                            .padding(12)
                            .background(AppTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1))
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private func metricPill(title: String, value: Int) -> some View {
        let clamped = max(1, min(5, value))
        return HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
            Text(String(repeating: "●", count: clamped))
                .font(.system(size: 9))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.border.opacity(0.3))
        .clipShape(Capsule())
    }
}
