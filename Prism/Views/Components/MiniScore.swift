import SwiftUI

struct MiniScore: View {
    let domain: Domain
    let score: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: domain.systemImage)
            Text("\(score)")
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(domain.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(domain.backgroundColor)
        .clipShape(Capsule())
    }
}

struct MiniScore_Previews: PreviewProvider {
    static var previews: some View {
        MiniScore(domain: .health, score: 8)
            .padding()
    }
}
