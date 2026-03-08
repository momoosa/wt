//
//  MomentumComplication.swift
//  MomentumWatch Watch App
//
//  Created by Claude on 08/03/2026.
//

import SwiftUI
import WidgetKit
import SwiftData
import MomentumKit

struct MomentumComplication: Widget {
    let kind: String = "MomentumComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Momentum")
        .description("Track your goal progress")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let activeTimerTitle: String?
    let activeTimerElapsed: TimeInterval?
    let activeTimerTarget: TimeInterval?
    let dailyProgressPercent: Double
    let totalMinutesLogged: Int
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(
            date: Date(),
            activeTimerTitle: "Reading",
            activeTimerElapsed: 1800,
            activeTimerTarget: 3600,
            dailyProgressPercent: 0.65,
            totalMinutesLogged: 120
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        let entry = placeholder(in: context)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        // Get active timer state from WatchConnectivityManager
        let connectivityManager = WatchConnectivityManager.shared
        let timerState = connectivityManager.activeTimerState
        
        // Calculate daily progress
        // TODO: Fetch actual data from SwiftData
        let dailyProgress = 0.0
        let totalMinutes = 0
        
        let entry = ComplicationEntry(
            date: Date(),
            activeTimerTitle: timerState?.goalTitle,
            activeTimerElapsed: timerState?.elapsedTime,
            activeTimerTarget: timerState?.dailyTarget,
            dailyProgressPercent: dailyProgress,
            totalMinutesLogged: totalMinutes
        )
        
        // Update every minute when timer is active, otherwise every hour
        let updateInterval: TimeInterval = timerState != nil ? 60 : 3600
        let nextUpdate = Date().addingTimeInterval(updateInterval)
        
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct ComplicationEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: ComplicationEntry
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            circularComplication
        case .accessoryRectangular:
            rectangularComplication
        case .accessoryInline:
            inlineComplication
        default:
            EmptyView()
        }
    }
    
    private var circularComplication: some View {
        ZStack {
            // Progress ring
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 4)
            
            if let elapsed = entry.activeTimerElapsed,
               let target = entry.activeTimerTarget {
                Circle()
                    .trim(from: 0, to: elapsed / target)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(elapsed / 60))m")
                    .font(.system(size: 14, weight: .semibold))
            } else {
                Text("\(Int(entry.dailyProgressPercent * 100))%")
                    .font(.system(size: 16, weight: .bold))
            }
        }
    }
    
    private var rectangularComplication: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = entry.activeTimerTitle {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                
                if let elapsed = entry.activeTimerElapsed {
                    Text("\(Int(elapsed / 60)) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Momentum")
                    .font(.headline)
                
                Text("\(entry.totalMinutesLogged) min today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var inlineComplication: some View {
        if let title = entry.activeTimerTitle,
           let elapsed = entry.activeTimerElapsed {
            Text("\(title): \(Int(elapsed / 60))m")
        } else {
            Text("Momentum: \(entry.totalMinutesLogged)m")
        }
    }
}
