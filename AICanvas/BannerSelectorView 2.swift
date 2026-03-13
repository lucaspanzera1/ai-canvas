import SwiftUI

struct BannerSelectorView: View {
    @ObservedObject var store: NotebookStore
    let itemId: String
    @Binding var selectedBannerData: Data?
    @Environment(\.dismiss) private var dismiss
    
    @State private var banners: [URL] = []
    @State private var appear = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 12)
    ]
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                ScrollView {
                    if banners.isEmpty {
                        emptyState
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(banners, id: \.self) { url in
                                BannerThumbCard(url: url) {
                                    if let data = try? Data(contentsOf: url) {
                                        selectedBannerData = data
                                        dismiss()
                                    }
                                }
                                .scaleEffect(appear ? 1 : 0.95)
                                .opacity(appear ? 1 : 0)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .onAppear {
            banners = store.getAvailableBanners(for: itemId)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { appear = true }
        }
    }
    
    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Banners Pré-definidos")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Escolha um banner gerado automaticamente")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                // Clear button
                if selectedBannerData != nil {
                    Button(role: .destructive) {
                        selectedBannerData = nil
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                            Text("Remover banner")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(AppTheme.danger)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.danger.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                
                Button {
                    dismiss()
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
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
        .background(AppTheme.surface)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.surfaceElevated)
                    .frame(width: 80, height: 80)
                    .overlay(Circle().stroke(AppTheme.border, lineWidth: 1))
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Text("Nenhum banner disponível")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Crie o item primeiro para gerar os banners automáticos.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Banner Thumb Card

private struct BannerThumbCard: View {
    let url: URL
    let onSelect: () -> Void
    @State private var hovered = false
    @State private var image: UIImage? = nil
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            ZStack(alignment: .bottomLeading) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 110)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(AppTheme.surfaceElevated)
                        .frame(height: 110)
                        .overlay(ProgressView().scaleEffect(0.8))
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.system(size: 10))
                    Text(url.lastPathComponent)
                        .font(.system(size: 10))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.35))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .padding(8)
            }
            .frame(maxWidth: .infinity)
            .background(AppTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(hovered ? AppTheme.borderActive : AppTheme.border, lineWidth: hovered ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.15)) { hovered = h }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let img = UIImage(contentsOfFile: url.path)
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.image = img
                }
            }
        }
    }
}
