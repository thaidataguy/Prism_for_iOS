import Charts
import SwiftUI

struct ProgressScreen: View {
    @EnvironmentObject private var store: CheckInStore
    @EnvironmentObject private var feedback: FeedbackManager
    @State private var selectedRange = 14
    @State private var editorDate = Date()
    @State private var editorMode = CheckInEditorSheet.Mode.flexibleDate
    @State private var isEditorPresented = false

    private let ranges = [7, 14, 30]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    pageHeader
                        .orbitEntrance(delay: 0.02)
                    Picker("Range", selection: $selectedRange) {
                        ForEach(ranges, id: \.self) { range in
                            Text("\(range)d").tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .orbitEntrance(delay: 0.08)

                    summaryCards
                        .orbitEntrance(delay: 0.14)
                    trendChart
                        .orbitEntrance(delay: 0.2)
                    averagesCard
                        .orbitEntrance(delay: 0.26)
                    entriesCard
                        .orbitEntrance(delay: 0.32)
                }
                .padding()
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isEditorPresented) {
                CheckInEditorSheet(initialDate: editorDate, mode: editorMode)
                    .environmentObject(store)
            }
            .onChange(of: selectedRange) { _ in
                feedback.perform(.selection)
            }
        }
    }

    private var pageHeader: some View {
        HStack {
            Text("Trends")
                .font(.largeTitle.bold())
                .foregroundStyle(PrismColors.heading)

            Spacer()

            Button {
                feedback.perform(.tap)
                presentFlexibleEntryEditor(for: .now)
            } label: {
                Label("Add/Edit Entry", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(PrismColors.heading.opacity(0.14))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(PrismColors.heading.opacity(0.18), lineWidth: 1)
                    )
                    .clipShape(Capsule(style: .continuous))
            }
            .buttonStyle(PrismPressableButtonStyle())
            .tint(PrismColors.heading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedEntries: [DailyCheckIn] {
        store.recentCheckIns(days: selectedRange)
    }

    private var recentBackfilledEntries: [DailyCheckIn] {
        let dateWindow = Set(selectedEntries.map(\.id))
        let cutoff = recentActivityCutoff

        return store.checkIns
            .filter { !dateWindow.contains($0.id) && $0.updatedAt >= cutoff }
            .sorted { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.date > rhs.date
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    private var recentEntryItems: [RecentEntryItem] {
        let entriesByDate = Dictionary(
            uniqueKeysWithValues: selectedEntries.map { (calendar.startOfDay(for: $0.date), $0) }
        )

        return recentDates.map { date in
            RecentEntryItem(date: date, entry: entriesByDate[calendar.startOfDay(for: date)])
        }
    }

    private var recentDates: [Date] {
        let today = calendar.startOfDay(for: .now)
        let effectiveStart = max(recentActivityCutoff, calendar.startOfDay(for: store.firstUseDate))

        var dates: [Date] = []
        var cursor = today

        while cursor >= effectiveStart {
            dates.append(cursor)
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }

        return dates
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            ForEach(Domain.allCases) { domain in
                StatChip(
                    title: domain.rawValue,
                    value: String(format: "%.1f/10", store.average(for: domain, last: selectedRange)),
                    systemImage: domain.systemImage,
                    tint: domain.color,
                    valueTint: domain.color
                )
            }
        }
    }

    private var recentActivityCutoff: Date {
        let today = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: -(selectedRange - 1), to: today) ?? today
    }

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend line")
                .font(.headline)

            Chart(store.chartPoints(days: selectedRange)) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Score", point.score)
                )
                .foregroundStyle(PrismColors.heading)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Score", point.score)
                )
                .foregroundStyle(PrismColors.heading)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 260)
            .chartYScale(domain: 1...10)
            .animation(PrismMotion.entrance, value: selectedRange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PrismColors.career.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: PrismColors.career.opacity(0.14), radius: 18, x: 0, y: 10)
    }

    private var averagesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Average balance")
                .font(.headline)

            Chart(Domain.allCases) { domain in
                BarMark(
                    x: .value("Domain", domain.rawValue),
                    y: .value("Score", store.average(for: domain, last: selectedRange))
                )
                .foregroundStyle(chartBarColor(for: domain).gradient)
            }
            .frame(height: 220)
            .chartYScale(domain: 0...10)
            .animation(PrismMotion.entrance, value: selectedRange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PrismColors.health.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: PrismColors.health.opacity(0.14), radius: 18, x: 0, y: 10)
    }

    private var entriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent entries")
                .font(.headline)

            if !recentBackfilledEntries.isEmpty {
                Text("Recently logged past entries")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(Array(recentBackfilledEntries.enumerated()), id: \.element.id) { index, entry in
                    CheckInHistoryCard(
                        entry: entry,
                        detailText: "Logged \(entry.updatedAt.formatted(date: .abbreviated, time: .shortened))"
                    ) {
                        presentLockedDateEditor(for: entry.date)
                    }
                    .padding(.vertical, 8)

                    if index < recentBackfilledEntries.count - 1 || !recentEntryItems.isEmpty {
                        Divider()
                    }
                }
            }

            ForEach(Array(recentEntryItems.enumerated()), id: \.element.id) { index, item in
                Group {
                    if let entry = item.entry {
                        CheckInHistoryCard(entry: entry) {
                            presentLockedDateEditor(for: entry.date)
                        }
                    } else {
                        MissingCheckInCard(date: item.date)
                    }
                }
                .padding(.vertical, 8)

                if index < recentEntryItems.count - 1 {
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PrismColors.social.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: PrismColors.social.opacity(0.12), radius: 16, x: 0, y: 10)
    }

    private func presentFlexibleEntryEditor(for date: Date) {
        editorDate = date
        editorMode = .flexibleDate
        isEditorPresented = true
    }

    private func presentLockedDateEditor(for date: Date) {
        editorDate = date
        editorMode = .lockedDate
        isEditorPresented = true
    }

    private var calendar: Calendar {
        .current
    }

    private func chartBarColor(for domain: Domain) -> Color {
        switch domain {
        case .career:
            return Color(red: 156 / 255, green: 112 / 255, blue: 255 / 255)
        case .health:
            return Color(red: 22 / 255, green: 214 / 255, blue: 144 / 255)
        case .social:
            return Color(red: 255 / 255, green: 102 / 255, blue: 84 / 255)
        }
    }
}

private struct RecentEntryItem: Identifiable {
    let date: Date
    let entry: DailyCheckIn?

    var id: Date { date }
}

private struct CheckInHistoryCard: View {
    let entry: DailyCheckIn
    var detailText: String?
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PrismColors.heading)

                    Text(detailText ?? String(format: "%.1f avg", entry.averageScore))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                CompactScoreStack(entry: entry)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PrismPressableButtonStyle())
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct MissingCheckInCard: View {
    let date: Date

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("No entry logged")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text("Missed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.quaternarySystemFill))
                .clipShape(Capsule(style: .continuous))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundStyle(Color(.systemGray4))
        )
        .opacity(0.9)
    }
}

private struct CompactScoreStack: View {
    let entry: DailyCheckIn

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Domain.allCases) { domain in
                CompactScoreBar(domain: domain, score: entry.score(for: domain))
            }
        }
        .frame(maxWidth: 400, alignment: .leading)
    }
}

private struct CompactScoreBar: View {
    let domain: Domain
    let score: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: domain.systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(domain.color)
                .frame(width: 12)

            GeometryReader { proxy in
                let width = max(proxy.size.width * CGFloat(score) / 10.0, 10)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(domain.backgroundColor.opacity(0.4))

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(domain.color.gradient)
                        .frame(width: width)
                        .animation(PrismMotion.pulse, value: score)
                }
            }
            .frame(height: 10)

            Text("\(score)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)
        }
    }
}

struct ProgressScreen_Previews: PreviewProvider {
    static var previews: some View {
        ProgressScreen()
            .environmentObject(CheckInStore.preview)
            .environmentObject(FeedbackManager())
    }
}
