//
//  FeatureCardView.swift
//  GlassQR
//

import SwiftUI

public struct FeatureCardView: View {
    public let feature: FeatureHighlight
    @State private var iconBounce: Int = 0

    public init(feature: FeatureHighlight) {
        self.feature = feature
    }

    public var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Image(systemName: feature.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .symbolEffect(.bounce, value: iconBounce)
            }
            .frame(width: 48, height: 48)
            .background(Circle().fill(Color.white.opacity(0.1)))

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(feature.subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .contentShape(Rectangle())
        .onTapGesture {
            iconBounce += 1
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: iconBounce)
    }
}
