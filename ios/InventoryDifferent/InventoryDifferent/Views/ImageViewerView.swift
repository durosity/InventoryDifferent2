//
//  ImageViewerView.swift
//  InventoryDifferent
//
//  Created by Michael Wottle on 2/3/26.
//

import AVKit
import SwiftUI

private struct VideoPlayerContainerView: UIViewControllerRepresentable {
    let url: URL
    let isActive: Bool

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = AVPlayer(url: url)
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if isActive {
            uiViewController.player?.play()
        } else {
            uiViewController.player?.pause()
        }
    }
}

struct ImageViewerView: View {
    let images: [DeviceImage]
    let initialIndex: Int
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    
    init(images: [DeviceImage], initialIndex: Int) {
        self.images = images
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                    if image.mediaType == "VIDEO",
                       let videoURL = APIService.shared.imageURL(for: image.path) {
                        VideoPlayerContainerView(url: videoURL, isActive: index == currentIndex)
                            .tag(index)
                    } else {
                        ZoomableImageView(
                            imageURL: APIService.shared.imageURL(for: image.path),
                            isCurrentPage: index == currentIndex,
                            onNavigateNext: { if currentIndex < images.count - 1 { currentIndex += 1 } },
                            onNavigatePrevious: { if currentIndex > 0 { currentIndex -= 1 } }
                        )
                        .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .padding()
                    
                    Spacer()
                    
                    Text("\(currentIndex + 1) of \(images.count)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding()
                }
                
                Spacer()
            }
        }
    }
}
