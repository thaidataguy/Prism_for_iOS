import SwiftUI

struct CheckInEditorSheet: View {
    enum Mode {
        case flexibleDate
        case lockedDate
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: CheckInStore
    @EnvironmentObject private var feedback: FeedbackManager

    let initialDate: Date
    let mode: Mode

    @State private var selectedDate: Date
    @State private var career = 5.0
    @State private var health = 5.0
    @State private var social = 5.0
    @State private var careerNote = ""
    @State private var healthNote = ""
    @State private var socialNote = ""
    @State private var hasLoadedInitialState = false
    @State private var isSaving = false

    init(initialDate: Date, mode: Mode = .flexibleDate) {
        self.initialDate = initialDate
        self.mode = mode
        let calendar = Calendar.current
        let normalizedInitialDate = calendar.startOfDay(for: initialDate)
        let latestEntryDate = calendar.startOfDay(for: .now)
        let earliestEntryDate = calendar.date(byAdding: .day, value: -7, to: latestEntryDate) ?? latestEntryDate
        let clampedInitialDate = min(max(normalizedInitialDate, earliestEntryDate), latestEntryDate)
        _selectedDate = State(initialValue: clampedInitialDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    dateCard
                        .orbitEntrance(delay: 0.02)

                    domainCard(
                        title: Domain.career.rawValue,
                        value: $career,
                        note: $careerNote,
                        domain: .career,
                        placeholder: "What shaped your career score that day?"
                    )
                    .orbitEntrance(delay: 0.08)

                    domainCard(
                        title: Domain.health.rawValue,
                        value: $health,
                        note: $healthNote,
                        domain: .health,
                        placeholder: "What shaped your health score that day?"
                    )
                    .orbitEntrance(delay: 0.14)

                    domainCard(
                        title: Domain.social.rawValue,
                        value: $social,
                        note: $socialNote,
                        domain: .social,
                        placeholder: "What shaped your social score that day?"
                    )
                    .orbitEntrance(delay: 0.2)

                    saveButton
                        .orbitEntrance(delay: 0.26)
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [
                        PrismColors.heading.opacity(0.10),
                        Color(.systemBackground),
                        PrismColors.social.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        feedback.perform(.tap)
                        dismiss()
                    }
                }
            }
            .onAppear {
                guard !hasLoadedInitialState else { return }
                loadEntry(for: selectedDate)
                hasLoadedInitialState = true
            }
            .onChange(of: selectedDate) { _ in
                loadEntry(for: selectedDate)
            }
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .flexibleDate:
            return "Add/Edit Entry"
        case .lockedDate:
            return calendar.isDateInToday(selectedDate) ? "Edit Today" : "Edit Entry"
        }
    }

    private var existingEntryText: String {
        switch mode {
        case .flexibleDate:
            return "Pick today or a recent date, then add a new entry or revise what is already there."
        case .lockedDate:
            return "Editing existing entry for \(selectedDate.formatted(date: .abbreviated, time: .omitted))."
        }
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(mode == .flexibleDate ? "You can log today or up to 7 days prior." : "Edit your check-in clearly.")
                .font(.title2.weight(.bold))
                .foregroundStyle(PrismColors.heading)

            Text(existingEntryText)
                .foregroundStyle(.secondary)

            if mode == .flexibleDate {
                HStack {
                    Label("Entry Date", systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PrismColors.heading)

                    Spacer()

                    DatePicker(
                        "Entry Date",
                        selection: $selectedDate,
                        in: earliestEntryDate...latestEntryDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }
            } else {
                Label(selectedDate.formatted(date: .complete, time: .omitted), systemImage: "calendar")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PrismColors.heading)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PrismColors.heading.opacity(0.15), lineWidth: 1)
        )
    }

    private var saveButton: some View {
        Button(action: saveEntry) {
            Text(saveButtonTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [PrismColors.heading, PrismColors.career],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .disabled(isSaving)
        .opacity(isSaving ? 0.72 : 1)
        .buttonStyle(PrismPressableButtonStyle())
    }

    private var saveButtonTitle: String {
        switch mode {
        case .flexibleDate:
            return "Save entry"
        case .lockedDate:
            return "Update entry"
        }
    }

    private func domainCard(
        title: String,
        value: Binding<Double>,
        note: Binding<String>,
        domain: Domain,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(title, systemImage: domain.systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(domain.color)

                Spacer()

                Text("\(Int(value.wrappedValue.rounded()))/10")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(PrismColors.heading)
                    .orbitValuePulse(value: Int(value.wrappedValue.rounded()), tint: domain.color)
            }

            Slider(value: value, in: 1...10, step: 1)
                .tint(domain.color)
                .onChange(of: value.wrappedValue) { _ in
                    feedback.perform(.step)
                }

            TextField(placeholder, text: note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...5)
        }
        .padding(18)
        .background(domain.backgroundColor.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(domain.color.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: domain.color.opacity(0.14), radius: 16, x: 0, y: 10)
    }

    private func saveEntry() {
        guard !isSaving else { return }
        isSaving = true

        Task {
            feedback.perform(.success)
            store.upsert(
                date: selectedDate,
                career: Int(career.rounded()),
                health: Int(health.rounded()),
                social: Int(social.rounded()),
                careerNote: careerNote.trimmingCharacters(in: .whitespacesAndNewlines),
                healthNote: healthNote.trimmingCharacters(in: .whitespacesAndNewlines),
                socialNote: socialNote.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            await store.flushCloudSyncNow()
            isSaving = false
            dismiss()
        }
    }

    private func loadEntry(for date: Date) {
        if let entry = store.checkIn(on: date) {
            career = Double(entry.career)
            health = Double(entry.health)
            social = Double(entry.social)
            careerNote = entry.careerNote
            healthNote = entry.healthNote
            socialNote = entry.socialNote
        } else {
            career = 5
            health = 5
            social = 5
            careerNote = ""
            healthNote = ""
            socialNote = ""
        }
    }

    private var calendar: Calendar {
        .current
    }

    private var earliestEntryDate: Date {
        calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: .now)) ?? latestEntryDate
    }

    private var latestEntryDate: Date {
        calendar.startOfDay(for: .now)
    }
}

struct CheckInEditorSheet_Previews: PreviewProvider {
    static var previews: some View {
        CheckInEditorSheet(initialDate: .now)
            .environmentObject(CheckInStore.preview)
            .environmentObject(FeedbackManager())
    }
}
