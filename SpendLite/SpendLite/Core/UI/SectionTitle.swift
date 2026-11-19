//
//  SectionTitle.swift
//  SpendLite
//

import SwiftUI

/// A list / form section header in the primary text color (black, white in Dark Mode)
/// instead of iOS's default grey, so section titles are easy to spot.
struct SectionTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) { self.title = title }

    var body: some View {
        Text(title)
            .foregroundStyle(Color.primary) // a fixed color; `.primary` would be relative to the header's grey
    }
}

extension Section where Parent == SectionTitle, Content: View, Footer == EmptyView {
    /// `Section(title: "Budget") { ... }`: a section with a `SectionTitle` header.
    init(title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(content: content, header: { SectionTitle(title) })
    }
}
