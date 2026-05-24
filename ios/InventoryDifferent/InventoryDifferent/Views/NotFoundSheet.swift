//
//  NotFoundSheet.swift
//  InventoryDifferent
//

import SwiftUI

struct NotFoundSheet: View {
    @EnvironmentObject var lm: LocalizationManager

    let serial: String
    let modelName: String?
    let factory: String?
    let year: Int?
    let onAddDevice: () -> Void
    let onScanAgain: () -> Void

    var body: some View {
        let t = lm.t
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(t.barcodeScanner.notInInventory)
                    .font(.headline)
                Text(t.barcodeScanner.serialNotFound)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            VStack(spacing: 4) {
                Text(serial)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)

                if let name = modelName {
                    HStack(spacing: 4) {
                        Text(t.barcodeScanner.identifiedAs)
                            .foregroundColor(.secondary)
                        Text(name)
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                } else {
                    Text(t.barcodeScanner.unknownDevice)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let year {
                    Text(t.barcodeScanner.manufacturedIn + " " + String(year))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)

            VStack(spacing: 12) {
                Button(action: onAddDevice) {
                    Label(t.barcodeScanner.addNewDevice, systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: onScanAgain) {
                    Text(t.barcodeScanner.scanAgain)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 20)
    }
}
