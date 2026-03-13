import SwiftUI

struct BannerSelectorView: View {
    @ObservedObject var store: NotebookStore
    let itemId: String
    @Binding var selectedBannerData: Data?
    @Environment(\.dismiss) var dismiss
    
    @State private var availableBanners: [URL] = []
    @State private var selectedBannerURL: URL?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Escolha um Banner")
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                    .padding(.vertical, 0)
                
                // Banners Grid
                ScrollView {
                    VStack(spacing: 12) {
                        // Nenhum banner
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppTheme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            selectedBannerURL == nil ? AppTheme.accent : AppTheme.cardBorder,
                                            lineWidth: selectedBannerURL == nil ? 2 : 1
                                        )
                                )
                                .frame(height: 120)
                                .overlay(
                                    VStack(spacing: 4) {
                                        Image(systemName: "xmark.circle")
                                            .font(.system(size: 24))
                                            .foregroundColor(AppTheme.textSecondary)
                                        Text("Sem Banner")
                                            .font(.caption)
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                )
                                .onTapGesture {
                                    selectedBannerURL = nil
                                    selectedBannerData = nil
                                }
                        }
                        
                        // Preset banners
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 150), spacing: 12)
                        ], spacing: 12) {
                            ForEach(availableBanners, id: \.self) { bannerURL in
                                VStack(spacing: 0) {
                                    if let bannerImage = UIImage(contentsOfFile: bannerURL.path) {
                                        Image(uiImage: bannerImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 120)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(
                                                        selectedBannerURL == bannerURL ? AppTheme.accent : AppTheme.cardBorder,
                                                        lineWidth: selectedBannerURL == bannerURL ? 2 : 1
                                                    )
                                            )
                                            .onTapGesture {
                                                selectedBannerURL = bannerURL
                                                if let imageData = bannerImage.pngData() {
                                                    selectedBannerData = imageData
                                                }
                                            }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .background(AppTheme.background)
            .onAppear {
                loadBanners()
            }
        }
    }
    
    private func loadBanners() {
        availableBanners = store.getAvailableBanners(for: itemId)
    }
}

#Preview {
    @State var bannerData: Data?
    
    return BannerSelectorView(
        store: NotebookStore(),
        itemId: UUID().uuidString,
        selectedBannerData: $bannerData
    )
    .preferredColorScheme(.dark)
}
