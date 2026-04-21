import SwiftUI

struct DomainSlider: View {
    let title: String
    @Binding var value: Double
    let domain: Domain

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: domain.systemImage)
                    .foregroundStyle(domain.color)

                Spacer()

                Text("\(Int(value.rounded()))")
                    .font(.headline.monospacedDigit())
            }

            Slider(value: $value, in: 1...10, step: 1)
                .tint(domain.color)
        }
    }
}

struct DomainSlider_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var value = 7.0

        var body: some View {
            DomainSlider(title: "Career", value: $value, domain: .career)
                .padding()
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
