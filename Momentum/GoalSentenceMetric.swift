//
//  GoalSentenceMetric.swift
//  Momentum
//
//  Metric catalog + layout for the Goal & target "sentence builder".
//
//  The goal target is authored as an editable sentence whose shape follows the
//  chosen metric. Two families:
//    • .session — discrete blocks you repeat (Time): "count × amount sessions a period".
//    • .tally   — a cumulative total you accrue (Steps, Calories, Screen Time):
//                 "target unit a period" with no session count.
//
//  This maps the design's metric model onto the app's `Goal.TargetUnit` set. Weekly
//  totals are always derived (see `SentenceRollup`), never stored — the editor keeps
//  the canonical per-day targets in sync on save.
//

import SwiftUI
import MomentumKit

// MARK: - Metric family

enum MetricFamily {
    case session   // Time — count × per-session amount
    case tally     // Steps / Calories / Screen Time — a running total
}

// MARK: - Metric descriptor

/// Presentation + math describing one target metric, keyed off `Goal.TargetUnit`.
struct SentenceMetric {
    let unit: Goal.TargetUnit
    let family: MetricFamily
    let pickerLabel: String   // metric-picker chip label
    let sfSymbol: String      // metric-picker + goal-head glyph
    let noun: String          // session-metric noun ("session"); empty for tally

    /// The amount the primary stepper edits — the per-session amount for session
    /// metrics, or the tally target for tally metrics — with its bounds/presets.
    let amountStep: Int
    let amountMin: Int
    let amountMax: Int
    let amountPresets: [Int]
    let amountUnitLabel: String   // "min", "steps", "kcal"
    let menuSubtitle: String      // shown under the metric name in the unit picker

    var isSession: Bool { family == .session }

    static let countRange = 1...10
    static let countPresets = [1, 2, 3, 4]

    func clampAmount(_ v: Int) -> Int { min(amountMax, max(amountMin, v)) }
    func clampCount(_ v: Int) -> Int { min(Self.countRange.upperBound, max(Self.countRange.lowerBound, v)) }

    /// Sentence/stepper display — thousands get separators, e.g. "10,000".
    func format(_ v: Int) -> String {
        v >= 1000 ? v.formatted(.number.grouping(.automatic)) : "\(v)"
    }

    /// Compact preset-chip label, e.g. 8000 -> "8k".
    func chip(_ v: Int) -> String {
        guard v >= 1000 else { return "\(v)" }
        let k = Double(v) / 1000
        return k == k.rounded() ? "\(Int(k))k" : "\(k)k"
    }

    /// Weekly session-amount phrase: time as a duration, otherwise a counted unit.
    func amountPhrase(_ v: Int) -> String {
        switch unit {
        case .seconds, .screenTime: return SentenceMetric.formatDuration(v)
        default: return "\(format(v)) \(amountUnitLabel)"
        }
    }

    static func formatDuration(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes)m" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    // MARK: Catalog

    static let time = SentenceMetric(
        unit: .seconds, family: .session, pickerLabel: "Time", sfSymbol: "clock",
        noun: "session", amountStep: 5, amountMin: 5, amountMax: 180,
        amountPresets: [10, 15, 25, 45, 60], amountUnitLabel: "min",
        menuSubtitle: "Minutes per session")

    static let steps = SentenceMetric(
        unit: .steps, family: .tally, pickerLabel: "Steps", sfSymbol: "figure.walk",
        noun: "", amountStep: 500, amountMin: 1000, amountMax: 30000,
        amountPresets: [5000, 8000, 10000, 12000], amountUnitLabel: "steps",
        menuSubtitle: "Step count from Health")

    static let calories = SentenceMetric(
        unit: .kilocalories, family: .tally, pickerLabel: "Calories", sfSymbol: "flame",
        noun: "", amountStep: 50, amountMin: 100, amountMax: 2000,
        amountPresets: [200, 300, 500, 800], amountUnitLabel: "kcal",
        menuSubtitle: "Active energy burned")

    static let screenTime = SentenceMetric(
        unit: .screenTime, family: .tally, pickerLabel: "Screen Time", sfSymbol: "hourglass",
        noun: "", amountStep: 5, amountMin: 15, amountMax: 1440,
        amountPresets: [30, 60, 90, 120, 180, 240], amountUnitLabel: "min",
        menuSubtitle: "Limit daily app usage")

    /// Picker order, matching the app's supported target units.
    static let all: [SentenceMetric] = [time, steps, calories, screenTime]

    static func named(_ unit: Goal.TargetUnit) -> SentenceMetric {
        all.first { $0.unit == unit } ?? time
    }
}

// MARK: - Derived rollup

/// Weekly totals derived from the current sentence — never stored.
struct SentenceRollup {
    let sessionsPerWeek: Int   // 0 for tally metrics
    let weeklyAmount: Int      // weekly minutes / steps / kcal
}

// MARK: - Sentence flow layout

/// A wrapping baseline layout so the sentence's tokens + connective words flow and
/// wrap like inline text. Separate from the app's `FlowLayout` because the sentence
/// wants a tight horizontal gap and a looser line gap.
struct SentenceFlowLayout: Layout {
    var spacing: CGFloat = 3
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxLineWidth: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                maxLineWidth = max(maxLineWidth, x - spacing)
                x = 0; y += lineHeight + lineSpacing; lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        maxLineWidth = max(maxLineWidth, x - spacing)
        return CGSize(width: min(maxLineWidth, maxWidth), height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxWidth = bounds.width
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += lineHeight + lineSpacing; lineHeight = 0
            }
            view.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                       anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
