import SwiftUI
import UIKit

struct AnnouncementImageView: View {
    let url: URL?
    let width: CGFloat?
    let height: CGFloat
    var cornerRadius: CGFloat = 16
    var expandWidth: Bool = false

    var body: some View {
        content
            .frame(maxWidth: expandWidth ? .infinity : nil)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.7))
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.ColorToken.turquoise.opacity(0.12), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var content: some View {
        if let url, url.isFileURL, let image = UIImage(contentsOfFile: url.path) {
            render(image: Image(uiImage: image))
        } else if let url {
            AsyncImage(
                url: url,
                transaction: Transaction(animation: .easeInOut(duration: 0.2))
            ) { phase in
                switch phase {
                case .success(let image):
                    render(image: image)
                case .empty, .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private func render(image: Image) -> some View {
        image
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Theme.ColorToken.milk,
                    Color.white.opacity(0.95),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "photo")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

struct AnnouncementGalleryView: View {
    let announcement: AnnouncementDTO
    var height: CGFloat = 220
    var cornerRadius: CGFloat = 20

    private var urls: [URL] {
        announcement.imageURLs
    }

    var body: some View {
        Group {
            if urls.count > 1 {
                TabView {
                    ForEach(urls, id: \.absoluteString) { url in
                        AnnouncementImageView(
                            url: url,
                            width: nil,
                            height: height,
                            cornerRadius: cornerRadius,
                            expandWidth: true
                        )
                        .padding(.horizontal, 1)
                    }
                }
                .frame(height: height)
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            } else if let url = urls.first {
                AnnouncementImageView(
                    url: url,
                    width: nil,
                    height: height,
                    cornerRadius: cornerRadius,
                    expandWidth: true
                )
            }
        }
    }
}
