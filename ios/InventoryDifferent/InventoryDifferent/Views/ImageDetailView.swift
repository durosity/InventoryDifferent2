//
//  ImageDetailView.swift
//  InventoryDifferent
//
//  Created by Michael Wottle on 2/2/26.
//

import SwiftUI

struct ImageDetailView: View {
    let image: DeviceImage
    let allImages: [DeviceImage]
    
    @State private var currentIndex: Int = 0
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    
    init(image: DeviceImage, allImages: [DeviceImage]) {
        self.image = image
        self.allImages = allImages
        _currentIndex = State(initialValue: allImages.firstIndex(where: { $0.id == image.id }) ?? 0)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(Array(allImages.enumerated()), id: \.element.id) { index, img in
                    ZoomableImageView(
                        imageURL: APIService.shared.imageURL(for: img.path),
                        isCurrentPage: index == currentIndex,
                        onNavigateNext: { if currentIndex < allImages.count - 1 { currentIndex += 1 } },
                        onNavigatePrevious: { if currentIndex > 0 { currentIndex -= 1 } }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text("\(currentIndex + 1) of \(allImages.count)")
                        .font(.headline)
                        .foregroundColor(.white)
                    if let caption = allImages[safe: currentIndex]?.caption, !caption.isEmpty {
                        Text(caption)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

struct ZoomableImageView: View {
    let imageURL: URL?
    var isCurrentPage: Bool = true
    var onNavigateNext: (() -> Void)? = nil
    var onNavigatePrevious: (() -> Void)? = nil

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var imageSize: CGSize = .zero

    private func clampedOffset(_ proposed: CGSize, in container: CGSize) -> CGSize {
        guard imageSize != .zero else { return proposed }
        let maxX = max(0, (imageSize.width * scale - container.width) / 2)
        let maxY = max(0, (imageSize.height * scale - container.height) / 2)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { imageSize = $0 }
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1), 6)
                                    offset = clampedOffset(offset, in: geometry.size)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    withAnimation {
                                        if scale < 1 {
                                            scale = 1
                                            offset = .zero
                                        } else {
                                            offset = clampedOffset(offset, in: geometry.size)
                                        }
                                        lastOffset = offset
                                    }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    let proposed = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                    offset = clampedOffset(proposed, in: geometry.size)
                                }
                                .onEnded { value in
                                    let proposed = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                    lastOffset = offset
                                    // Edge navigation: if the drag overshoots the clamped boundary,
                                    // treat it as a swipe to the next/previous image.
                                    let maxX = max(0, (imageSize.width * scale - geometry.size.width) / 2)
                                    let swipeThreshold: CGFloat = 225
                                    if proposed.width < -(maxX + swipeThreshold) {
                                        onNavigateNext?()
                                    } else if proposed.width > maxX + swipeThreshold {
                                        onNavigatePrevious?()
                                    }
                                },
                            including: scale > 1 ? .gesture : .none
                        )
                case .failure:
                    VStack {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("Failed to load image")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                withAnimation {
                    if scale > 1 {
                        scale = 1
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = 2
                    }
                }
            }
            .onChange(of: isCurrentPage) { _, nowCurrent in
                if nowCurrent {
                    scale = 1.0
                    offset = .zero
                    lastOffset = .zero
                    lastScale = 1.0
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        scale = 1.0
                        offset = .zero
                        lastOffset = .zero
                        lastScale = 1.0
                    }
                }
            }
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        ImageDetailView(
            image: DeviceImage(
                id: 1,
                path: "/uploads/devices/1/photo.jpg",
                thumbnailPath: nil,
                originalPath: nil,
                rotation: nil,
                cropLeft: nil,
                cropTop: nil,
                cropWidth: nil,
                cropHeight: nil,
                dateTaken: nil,
                caption: "Front view",
                isShopImage: false,
                isThumbnail: true,
                thumbnailMode: "BOTH",
                isListingImage: false,
                mediaType: "IMAGE",
                duration: nil
            ),
            allImages: []
        )
    }
}
