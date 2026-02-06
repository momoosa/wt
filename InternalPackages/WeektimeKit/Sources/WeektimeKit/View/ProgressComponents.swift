//
//  ProgressComponents.swift
//  WeektimeKit
//
//  Reusable progress view components
//

import SwiftUI

// MARK: - Time Progress View

/// Displays elapsed time vs target time with optional progress indicator
public struct TimeProgressView: View {
    let elapsed: TimeInterval
    let target: TimeInterval
    let showTarget: Bool
    let textAlignment: HorizontalAlignment
    let font: Font
    let showProgressBar: Bool
    let progressColor: Color

    public init(
        elapsed: TimeInterval,
        target: TimeInterval,
        showTarget: Bool = true,
        textAlignment: HorizontalAlignment = .leading,
        font: Font = .headline,
        showProgressBar: Bool = false,
        progressColor: Color = .accentColor
    ) {
        self.elapsed = elapsed
        self.target = target
        self.showTarget = showTarget
        self.textAlignment = textAlignment
        self.font = font
        self.showProgressBar = showProgressBar
        self.progressColor = progressColor
    }

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(elapsed / target, 1.0)
    }

    public var body: some View {
        VStack(alignment: textAlignment, spacing: 8) {
            HStack(spacing: 4) {
                Text(elapsed.formatted(style: .hmmss))
                    .font(font)
                    .fontWeight(.semibold)

                if showTarget {
                    Text("/ \(target.formatted(style: .hmmss))")
                        .font(font.weight(.regular))
                        .foregroundStyle(.secondary)
                }
            }

            if showProgressBar {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(progressColor.opacity(0.3))
                            .frame(height: 6)

                        Capsule()
                            .fill(progressColor)
                            .frame(width: geo.size.width * progress, height: 6)
                            .animation(.spring(response: 0.6), value: progress)
                    }
                }
                .frame(height: 6)
            }
        }
    }
}

// MARK: - Metric Info Row

/// Displays a metric with icon, title, and value
public struct MetricInfoRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    public init(
        title: String,
        value: String,
        icon: String,
        color: Color = .secondary
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(color)

                    Text(value)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            Spacer()
        }
    }
}

// MARK: - Progress Percentage Badge

/// Displays a progress percentage with optional completion indicator
public struct ProgressBadge: View {
    let progress: Double
    let showCheckmark: Bool

    public init(
        progress: Double,
        showCheckmark: Bool = true
    ) {
        self.progress = progress
        self.showCheckmark = showCheckmark
    }

    private var isComplete: Bool {
        progress >= 1.0
    }

    public var body: some View {
        HStack(spacing: 4) {
            Text("\(Int(min(progress, 1.0) * 100))%")
                .font(.subheadline)
                .fontWeight(.medium)

            if showCheckmark && isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .foregroundStyle(isComplete ? .green : .primary)
    }
}

// MARK: - Compact Progress Row

/// A compact row showing title, elapsed/target time, and progress percentage
public struct CompactProgressRow: View {
    let title: String
    let elapsed: TimeInterval
    let target: TimeInterval
    let themeColor: Color

    public init(
        title: String,
        elapsed: TimeInterval,
        target: TimeInterval,
        themeColor: Color = .accentColor
    ) {
        self.title = title
        self.elapsed = elapsed
        self.target = target
        self.themeColor = themeColor
    }

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(elapsed / target, 1.0)
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    Text(elapsed.formatted(style: .hourMinute))
                        .font(.caption)

                    Text("/ \(target.formatted(style: .hourMinute))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            ProgressBadge(progress: progress)
        }
        .padding(.vertical, 8)
    }
}
