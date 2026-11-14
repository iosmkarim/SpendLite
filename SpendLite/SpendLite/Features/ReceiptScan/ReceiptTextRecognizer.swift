//
//  ReceiptTextRecognizer.swift
//  SpendLite
//

import UIKit
import Vision

/// Reads the text on a receipt photo with Apple's on-device text recognition (Vision).
/// Nothing leaves the phone.
enum ReceiptTextRecognizer {

    enum RecognitionError: LocalizedError {
        case unreadableImage

        var errorDescription: String? { "That image couldn't be read." }
    }

    /// Text lines, top to bottom. Words on the same row (e.g. "TOTAL ........ 12.50") are joined.
    static func lines(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { throw RecognitionError.unreadableImage }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            try handler.perform([request])
            let observations = request.results ?? []
            return Self.joinRows(observations.compactMap { observation in
                observation.topCandidates(1).first.map { (text: $0.string, box: observation.boundingBox) }
            })
        }.value
    }

    /// Groups recognised pieces that sit on the same row, then orders rows top to bottom
    /// and pieces left to right. (Vision's y axis starts at the bottom.)
    nonisolated static func joinRows(_ pieces: [(text: String, box: CGRect)]) -> [String] {
        var rows: [(midY: CGFloat, height: CGFloat, pieces: [(text: String, box: CGRect)])] = []
        for piece in pieces.sorted(by: { $0.box.midY > $1.box.midY }) {
            if let index = rows.firstIndex(where: { abs($0.midY - piece.box.midY) < max($0.height, piece.box.height) * 0.5 }) {
                rows[index].pieces.append(piece)
            } else {
                rows.append((piece.box.midY, piece.box.height, [piece]))
            }
        }
        return rows.map { row in
            row.pieces.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ")
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
