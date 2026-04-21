import SwiftUI

struct StatChip: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = PrismColors.heading
    var valueTint: Color = PrismColors.heading

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(tint)

            Text(value)
                .font(.headline)
                .foregroundStyle(valueTint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.2), lineWidth: 1)
        )
    }
}

struct StatChip_Previews: PreviewProvider {
    static var previews: some View {
        StatChip(title: "Streak", value: "4 days", systemImage: "flame.fill")
            .padding()
    }
}
