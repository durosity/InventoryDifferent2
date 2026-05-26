//
//  EditPhotoView.swift
//  InventoryDifferent
//

import SwiftUI

struct EditPhotoView: View {
    let image: DeviceImage
    let onSaved: (DeviceImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var lm: LocalizationManager

    @State private var rotation: Int = 0
    @State private var cropRect: CGRect = .zero      // normalized 0-1 in rotated image space
    @State private var hasCrop = false
    @State private var rotatedUIImage: UIImage? = nil
    @State private var isSaving = false
    @State private var isResetting = false
    @State private var errorMessage: String? = nil

    private var sourceURL: URL? {
        APIService.shared.imageURL(for: image.originalPath ?? image.path)
    }
    private var busy: Bool { isSaving || isResetting }
    private var isEdited: Bool { image.originalPath != nil }

    var body: some View {
        let t = lm.t
        NavigationStack {
            VStack(spacing: 0) {
                // Rotate controls
                HStack(spacing: 12) {
                    Button {
                        applyRotation(-90)
                    } label: {
                        Label(t.editPhoto.rotateLeft, systemImage: "rotate.left")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .disabled(busy)

                    Button {
                        applyRotation(90)
                    } label: {
                        Label(t.editPhoto.rotateRight, systemImage: "rotate.right")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .disabled(busy)

                    Spacer()
                    Text("\(rotation)°")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                // Crop editor
                if let ui = rotatedUIImage {
                    CropView(image: ui, cropRect: $cropRect, hasCrop: $hasCrop)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Divider()

                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .padding(.top, 6)
                }

                // Action buttons
                HStack(spacing: 12) {
                    if isEdited {
                        Button(t.editPhoto.resetToOriginal) {
                            Task { await handleReset() }
                        }
                        .foregroundColor(.red)
                        .disabled(busy)
                    }

                    Spacer()

                    Button(t.common.cancel) {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .disabled(busy)

                    Button {
                        Task { await handleSave() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(t.editPhoto.saveEdits)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(busy)
                }
                .padding()
            }
            .navigationTitle(t.editPhoto.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t.common.cancel) { dismiss() }
                        .disabled(busy)
                }
            }
        }
        .task { await loadImage() }
    }

    private func loadImage() async {
        guard let url = sourceURL else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let original = UIImage(data: data) else { return }
            // Initialize rotation from existing edit
            let initialRotation = image.rotation ?? 0
            rotation = initialRotation
            let rotated = rotateImage(original, degrees: initialRotation)
            await MainActor.run {
                rotatedUIImage = rotated
                // Initialize crop from existing edit
                if let cl = image.cropLeft, let ct = image.cropTop,
                   let cw = image.cropWidth, let ch = image.cropHeight {
                    cropRect = CGRect(x: cl, y: ct, width: cw, height: ch)
                    hasCrop = true
                }
            }
        } catch {}
    }

    private func applyRotation(_ delta: Int) {
        guard let url = sourceURL else { return }
        let nextRotation = ((rotation + delta) % 360 + 360) % 360
        rotation = nextRotation
        hasCrop = false
        cropRect = .zero
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let original = UIImage(data: data) else { return }
                let rotated = rotateImage(original, degrees: nextRotation)
                await MainActor.run { rotatedUIImage = rotated }
            } catch {}
        }
    }

    private func handleSave() async {
        isSaving = true
        errorMessage = nil
        let oldPath = image.path
        let oldThumb = image.thumbnailPath
        do {
            let updated = try await DeviceService.shared.editImage(
                id: image.id,
                rotation: rotation,
                cropLeft:   hasCrop ? cropRect.origin.x : nil,
                cropTop:    hasCrop ? cropRect.origin.y : nil,
                cropWidth:  hasCrop ? cropRect.width    : nil,
                cropHeight: hasCrop ? cropRect.height   : nil
            )
            // Invalidate old display copy and thumbnail from cache
            if let url = APIService.shared.imageURL(for: oldPath) {
                ImageCacheService.shared.removeImage(for: url)
            }
            if let thumb = oldThumb, let url = APIService.shared.imageURL(for: thumb) {
                ImageCacheService.shared.removeImage(for: url)
            }
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    private func handleReset() async {
        isResetting = true
        errorMessage = nil
        let oldPath = image.path
        let oldThumb = image.thumbnailPath
        let origPath = image.originalPath
        do {
            let updated = try await DeviceService.shared.resetImageEdits(id: image.id)
            for p in [oldPath, oldThumb, origPath].compactMap({ $0 }) {
                if let url = APIService.shared.imageURL(for: p) {
                    ImageCacheService.shared.removeImage(for: url)
                }
            }
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isResetting = false
        }
    }

    // Pre-rotate UIImage via Core Graphics so crop handle coordinates are correct
    private func rotateImage(_ image: UIImage, degrees: Int) -> UIImage {
        guard degrees != 0 else { return image }
        let radians = CGFloat(degrees) * .pi / 180
        let swap = degrees == 90 || degrees == 270
        let newSize = swap
            ? CGSize(width: image.size.height, height: image.size.width)
            : image.size

        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return image }

        ctx.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        ctx.rotate(by: radians)
        image.draw(in: CGRect(
            x: -image.size.width / 2,
            y: -image.size.height / 2,
            width: image.size.width,
            height: image.size.height
        ))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
}

// MARK: - Crop View

private struct CropView: View {
    let image: UIImage
    @Binding var cropRect: CGRect     // normalized 0-1
    @Binding var hasCrop: Bool

    @State private var dragStart: CGPoint? = nil
    @State private var dragEnd: CGPoint? = nil

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)

                if hasCrop {
                    let imgSize = fittedSize(image: image, in: size)
                    let offset = CGPoint(
                        x: (size.width  - imgSize.width)  / 2,
                        y: (size.height - imgSize.height) / 2
                    )
                    let r = CGRect(
                        x: offset.x + cropRect.origin.x * imgSize.width,
                        y: offset.y + cropRect.origin.y * imgSize.height,
                        width: cropRect.width  * imgSize.width,
                        height: cropRect.height * imgSize.height
                    )
                    // Semi-transparent overlay
                    Color.black.opacity(0.45)
                        .mask(
                            Rectangle()
                                .overlay(
                                    Rectangle()
                                        .frame(width: r.width, height: r.height)
                                        .offset(x: r.midX - size.width  / 2,
                                                y: r.midY - size.height / 2)
                                        .blendMode(.destinationOut)
                                )
                        )
                        .allowsHitTesting(false)

                    Rectangle()
                        .stroke(Color.white, lineWidth: 1.5)
                        .frame(width: r.width, height: r.height)
                        .offset(x: r.midX - size.width  / 2,
                                y: r.midY - size.height / 2)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        let imgSize = fittedSize(image: image, in: size)
                        let offset = CGPoint(
                            x: (size.width  - imgSize.width)  / 2,
                            y: (size.height - imgSize.height) / 2
                        )
                        dragStart = value.startLocation
                        dragEnd   = value.location
                        let rawRect = CGRect(
                            x: min(value.startLocation.x, value.location.x),
                            y: min(value.startLocation.y, value.location.y),
                            width:  abs(value.location.x - value.startLocation.x),
                            height: abs(value.location.y - value.startLocation.y)
                        )
                        cropRect = normalizedCrop(rawRect, imageOffset: offset, imageSize: imgSize)
                        hasCrop = cropRect.width > 0.01 && cropRect.height > 0.01
                    }
                    .onEnded { _ in
                        dragStart = nil
                        dragEnd   = nil
                    }
            )
        }
    }

    private func fittedSize(image: UIImage, in size: CGSize) -> CGSize {
        let scale = min(size.width / image.size.width, size.height / image.size.height)
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }

    private func normalizedCrop(_ raw: CGRect, imageOffset: CGPoint, imageSize: CGSize) -> CGRect {
        let x = max(0, (raw.origin.x - imageOffset.x) / imageSize.width)
        let y = max(0, (raw.origin.y - imageOffset.y) / imageSize.height)
        let w = min(1 - x, raw.width  / imageSize.width)
        let h = min(1 - y, raw.height / imageSize.height)
        return CGRect(x: x, y: y, width: max(0, w), height: max(0, h))
    }
}
