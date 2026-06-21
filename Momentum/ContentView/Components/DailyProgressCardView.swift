//
//  DailyProgressCardView.swift
//  Momentum
//
//  Extracted from ContentView.swift — Daily progress card + weather/calendar helpers
//

import SwiftUI
import EventKit
import WeatherKit
import MomentumKit

// MARK: - Daily Progress Card

extension ContentView {
    
    var dailyProgressCard: some View {
        let size = 80.0
        let vm = progressViewModel
        let hasVisibleTiles = showProgressTile || showCalendarTile
        
        return Group {
            if hasVisibleTiles {
                HStack(spacing: 12) {
                    // Progress Ring
                    if showProgressTile {
                        CircularProgressView(progress: vm.dailyProgress, foregroundColor: .blue, backgroundColor: Color.blue.opacity(0.4))
                            .overlay {
                                VStack(spacing: 2) {
                                    Text("\(Int(vm.dailyProgress * 100))%")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text("done")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: size, height: size)
                            .glassCardStyle(shadowColor: .black)
                            .matchedTransitionSource(id: "dayOverviewCard", in: animation)
                            .onTapGesture {
                                navigation.showDayOverview = true
                            }
                    }

                    // Calendar Free Time Card
                    if showCalendarTile {
                        if nextCalendarEvent != nil {
                            VStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.title)
                                    .foregroundStyle(.orange)
                                
                                Text(freeTimeText)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .multilineTextAlignment(.center)
                                
                            }
                            .frame(width: size, height: size)
                            .glassCardStyle(shadowColor: .black)
                        } else {
                            VStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.title)
                                    .foregroundStyle(.green)
                                                
                                Text("Free")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: size, height: size)
                            .glassCardStyle(shadowColor: .black)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .animation(.spring(), value: showProgressTile)
                .animation(.spring(), value: showCalendarTile)
            }
        }
    }
    
    var progressViewModel: DailyProgressViewModel {
        DailyProgressViewModel(sessions: Array(sessions))
    }
    
    // MARK: - Weather & Calendar Helpers
    
    func weatherSymbol(for condition: WeatherKit.WeatherCondition) -> String {
        switch condition {
        case .clear, .mostlyClear:
            return "sun.max.fill"
        case .partlyCloudy:
            return "cloud.sun.fill"
        case .cloudy, .mostlyCloudy:
            return "cloud.fill"
        case .rain, .drizzle, .heavyRain:
            return "cloud.rain.fill"
        case .snow, .blizzard, .flurries, .heavySnow:
            return "cloud.snow.fill"
        case .sleet, .freezingDrizzle, .freezingRain:
            return "cloud.sleet.fill"
        case .strongStorms, .tropicalStorm, .hurricane:
            return "cloud.bolt.rain.fill"
        case .windy, .breezy:
            return "wind"
        case .haze, .smoky, .foggy:
            return "cloud.fog.fill"
        default:
            return "cloud.fill"
        }
    }
    
    var freeTimeText: String {
        // Use planner's selected time as the displayed free time
        let plannerMinutes = planningViewModel.availableTimeMinutes
        if plannerMinutes >= 60 {
            let h = plannerMinutes / 60
            let m = plannerMinutes % 60
            return m > 0 ? "\(h)h \(m)m free" : "\(h)h free"
        }
        return "\(plannerMinutes)m free"
    }
    
    func fetchNextCalendarEvent() {
        // Request authorization on MainActor, then move the synchronous
        // EventKit query off the main thread to avoid blocking UI.
        Task {
            do {
                let granted = try await calendarEventStore.requestFullAccessToEvents()
                guard granted else { return }
                
                let store = calendarEventStore
                let event: EKEvent? = await Task.detached(priority: .utility) {
                    let now = Date()
                    let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
                    
                    let predicate = store.predicateForEvents(
                        withStart: now,
                        end: endOfDay,
                        calendars: nil
                    )
                    
                    return store.events(matching: predicate)
                        .filter { !$0.isAllDay }
                        .sorted { $0.startDate < $1.startDate }
                        .first
                }.value
                
                // Update state on MainActor without triggering animations
                await MainActor.run {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        nextCalendarEvent = event
                    }
                }
            } catch {
                // Silently fail - calendar is optional
                await MainActor.run {
                    nextCalendarEvent = nil
                }
            }
        }
    }
}
