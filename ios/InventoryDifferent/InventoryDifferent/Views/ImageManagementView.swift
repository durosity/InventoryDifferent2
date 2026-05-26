//
//  ImageManagementView.swift
//  InventoryDifferent
//
//  Created by Michael Wottle on 2/3/26.
//

import SwiftUI

struct ImageManagementView: View {
    let image: DeviceImage
    let onUpdate: (DeviceImage) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var lm: LocalizationManager

    @State private var isUpdating = false
    @State private var showDeleteConfirmation = false
    @State private var showEditPhoto = false
    @State private var error: String?

    var body: some View {
        let t = lm.t
        NavigationStack {
            VStack(spacing: 0) {
                AsyncImage(url: APIService.shared.imageURL(for: image.thumbnailPath ?? image.path)) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay { ProgressView() }
                    case .success(let img):
                        img
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxHeight: 300)
                .background(Color.black)

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 12) {
                            Text(t.imageManagement.imageSettings)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if image.mediaType != "VIDEO" {
                                Button {
                                    Task {
                                        await updateImage(isThumbnail: true)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: image.isThumbnail ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(image.isThumbnail ? .blue : .secondary)
                                        Text(t.imageManagement.setThumbnail)
                                        Spacer()
                                        Image(systemName: "photo")
                                    }
                                    .foregroundColor(.primary)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .disabled(isUpdating || image.isThumbnail)

                                Button {
                                    Task {
                                        await updateImage(isShopImage: !image.isShopImage)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: image.isShopImage ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(image.isShopImage ? .green : .secondary)
                                        Text(image.isShopImage ? t.imageManagement.removeFromShop : t.imageManagement.addToShop)
                                        Spacer()
                                        Image(systemName: "bag")
                                    }
                                    .foregroundColor(.primary)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .disabled(isUpdating)

                                Button {
                                    Task {
                                        await updateImage(isListingImage: true)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: image.isListingImage ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(image.isListingImage ? .orange : .secondary)
                                        Text(t.imageManagement.setListingImage)
                                        Spacer()
                                        Image(systemName: "storefront")
                                    }
                                    .foregroundColor(.primary)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .disabled(isUpdating || image.isListingImage)

                                Button {
                                    showEditPhoto = true
                                } label: {
                                    HStack {
                                        Image(systemName: "crop.rotate")
                                        Text(t.imageManagement.editPhoto)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .foregroundColor(.primary)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .disabled(isUpdating)
                            }

                            if image.mediaType == "VIDEO", let secs = image.duration {
                                let mins = secs / 60
                                let remaining = secs % 60
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%d:%02d", mins, remaining))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding()

                        Divider()

                        VStack(spacing: 12) {
                            Button {
                                showDeleteConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text(t.imageManagement.deleteImage)
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(isUpdating)

                            if showDeleteConfirmation {
                                VStack(spacing: 12) {
                                    Text(t.imageManagement.deleteTitle)
                                        .font(.headline)
                                    Text(t.imageManagement.deleteMessage)
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    HStack(spacing: 12) {
                                        Button(t.common.cancel) {
                                            showDeleteConfirmation = false
                                        }
                                        .buttonStyle(.bordered)

                                        Button(t.common.delete) {
                                            onDelete()
                                            dismiss()
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.red)
                                    }
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(radius: 4)
                            }
                        }
                        .padding()

                        if let error = error {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding()
                        }
                    }
                }
            }
            .navigationTitle(t.imageManagement.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t.imageManagement.done) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEditPhoto) {
                EditPhotoView(image: image) { updated in
                    onUpdate(updated)
                    dismiss()
                }
                .environmentObject(lm)
            }
        }
    }
    
    private func updateImage(isThumbnail: Bool? = nil, isShopImage: Bool? = nil, isListingImage: Bool? = nil) async {
        isUpdating = true
        error = nil
        
        do {
            let updatedImage = try await DeviceService.shared.updateImage(
                id: image.id,
                isThumbnail: isThumbnail,
                isShopImage: isShopImage,
                isListingImage: isListingImage
            )
            onUpdate(updatedImage)
            dismiss()
        } catch {
            self.error = error.localizedDescription
            isUpdating = false
        }
    }
}

#Preview {
    ImageManagementView(
        image: DeviceImage(
            id: 1,
            path: "/uploads/devices/1/image.jpg",
            thumbnailPath: nil,
            originalPath: nil,
            rotation: nil,
            cropLeft: nil,
            cropTop: nil,
            cropWidth: nil,
            cropHeight: nil,
            dateTaken: nil,
            caption: nil,
            isShopImage: false,
            isThumbnail: false,
            thumbnailMode: nil,
            isListingImage: false,
            mediaType: "IMAGE",
            duration: nil
        ),
        onUpdate: { _ in },
        onDelete: {}
    )
}
