//
//  SampleReceipt.swift
//  SpendLite
//

import UIKit

/// A realistic receipt drawn as an image. Used by UI tests (the simulator has no camera)
/// and SwiftUI previews to run the real text recognition end to end.
enum SampleReceipt {
    static let lines = [
        "BLUE BOTTLE COFFEE",
        "123 Market Street",
        "Tel 415-555-0199",
        "",
        "Date: 11/09/2026  08:42",
        "",
        "Latte                 5.50",
        "Croissant             4.25",
        "Oat milk              0.75",
        "",
        "Subtotal             10.50",
        "Tax                   0.92",
        "TOTAL                11.42",
        "",
        "Thank you!",
    ]

    static func image() -> UIImage {
        let font = UIFont.monospacedSystemFont(ofSize: 28, weight: .medium)
        let lineHeight: CGFloat = 40
        let size = CGSize(width: 640, height: CGFloat(lines.count) * lineHeight + 80)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (index, line) in lines.enumerated() {
                (line as NSString).draw(
                    at: CGPoint(x: 40, y: 40 + CGFloat(index) * lineHeight),
                    withAttributes: [.font: font, .foregroundColor: UIColor.black]
                )
            }
        }
    }
}
