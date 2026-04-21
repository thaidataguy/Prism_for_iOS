import SceneKit
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: CheckInStore
    @StateObject private var sceneController = ApexSceneController()
    private let trendRange = 14

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                pageHeader

                Spacer(minLength: 0)

                sceneShowcase

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .background(screenBackground)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: syncTrend)
            .onChange(of: store.checkIns) { _ in
                syncTrend()
            }
        }
    }

    private var pageHeader: some View {
        HStack {
            Text("Life Prism")
                .font(.largeTitle.bold())
                .foregroundStyle(PrismColors.heading)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sceneShowcase: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.82),
                            PrismColors.heading.opacity(0.12),
                            PrismColors.career.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            PrismColors.health.opacity(0.18),
                            PrismColors.social.opacity(0.10),
                            Color.clear
                        ],
                        center: .bottomTrailing,
                        startRadius: 20,
                        endRadius: 260
                    )
                )

            ApexSceneView(
                scene: sceneController.scene,
                allowsCameraControl: true
            )
            .frame(maxWidth: .infinity)
            .frame(height: 540)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: PrismColors.heading.opacity(0.12), radius: 34, x: 0, y: 18)
        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
    }

    private var screenBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    PrismColors.heading.opacity(0.14),
                    Color(.systemBackground),
                    PrismColors.career.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(PrismColors.social.opacity(0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 50)
                .offset(x: 140, y: 220)

            Circle()
                .fill(PrismColors.health.opacity(0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: -130, y: -260)
        }
        .ignoresSafeArea()
    }

    private func syncTrend() {
        sceneController.updateTrend(checkIns: store.recentCheckIns(days: trendRange))
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}

private struct ApexSceneView: UIViewRepresentable {
    let scene: SCNScene
    let allowsCameraControl: Bool

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene
        view.allowsCameraControl = allowsCameraControl
        view.backgroundColor = .clear
        view.isOpaque = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = true
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.scene = scene
        uiView.allowsCameraControl = allowsCameraControl
        uiView.backgroundColor = .clear
        uiView.isOpaque = false
        uiView.antialiasingMode = .multisampling4X
    }
}
