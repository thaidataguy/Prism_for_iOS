import Combine
import SceneKit
import SwiftUI
import UIKit
import simd

@MainActor
final class ApexSceneController: ObservableObject {
    let scene = SCNScene()

    private let trendContentNode = SCNNode()
    private let pyramidGlassNode = SCNNode()
    private let pyramidEdgesNode = SCNNode()
    private let baseVertices: [(domain: Domain, position: SIMD3<Float>)] = [
        (.career, SIMD3(-1.35, 0.0, -0.95)),
        (.health, SIMD3(1.35, 0.0, -0.95)),
        (.social, SIMD3(0.0, 0.0, 1.35))
    ]

    private let apexPosition = SIMD3<Float>(0.0, 2.55, -0.05)

    init() {
        configureScene()
    }

    func updateTrend(checkIns: [DailyCheckIn]) {
        let points = checkIns.map(trendPosition(for:))

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.28
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        rebuildTrendNodes(points: points)
        SCNTransaction.commit()
    }

    private func configureScene() {
        scene.background.contents = UIColor.clear
        scene.lightingEnvironment.contents = UIColor(
            red: 0.16,
            green: 0.19,
            blue: 0.27,
            alpha: 1.0
        )
        scene.lightingEnvironment.intensity = 0.2
        scene.fogColor = UIColor(
            red: 0.92,
            green: 0.95,
            blue: 1.0,
            alpha: 0.14
        )
        scene.fogStartDistance = 11
        scene.fogEndDistance = 22

        let cameraNode = SCNNode()
        cameraNode.camera = {
            let camera = SCNCamera()
            camera.fieldOfView = 30
            camera.wantsHDR = false
            camera.wantsExposureAdaptation = false
            camera.bloomIntensity = 0.05
            camera.bloomThreshold = 1.0
            camera.bloomBlurRadius = 6
            camera.zFar = 100
            return camera
        }()
        cameraNode.position = SCNVector3(0, 2.6, 9.6)
        cameraNode.look(at: SCNVector3(0, 1.14, 0.18))
        scene.rootNode.addChildNode(cameraNode)

        let ambientLight = SCNNode()
        ambientLight.light = {
            let light = SCNLight()
            light.type = .ambient
            light.intensity = 180
            light.color = UIColor(
                red: 0.72,
                green: 0.77,
                blue: 0.86,
                alpha: 1.0
            )
            return light
        }()
        scene.rootNode.addChildNode(ambientLight)

        let keyLight = SCNNode()
        keyLight.light = {
            let light = SCNLight()
            light.type = .omni
            light.intensity = 900
            light.color = UIColor(red: 0.86, green: 0.91, blue: 0.97, alpha: 1.0)
            return light
        }()
        keyLight.position = SCNVector3(3.8, 6.2, 7.4)
        scene.rootNode.addChildNode(keyLight)

        let fillLight = SCNNode()
        fillLight.light = {
            let light = SCNLight()
            light.type = .omni
            light.intensity = 320
            light.color = UIColor(red: 0.96, green: 0.93, blue: 0.92, alpha: 1.0)
            return light
        }()
        fillLight.position = SCNVector3(-4.6, 1.9, -1.4)
        scene.rootNode.addChildNode(fillLight)

        let spotlight = SCNNode()
        spotlight.light = {
            let light = SCNLight()
            light.type = .spot
            light.intensity = 420
            light.spotInnerAngle = 34
            light.spotOuterAngle = 72
            light.castsShadow = true
            light.shadowRadius = 6
            light.shadowColor = UIColor.black.withAlphaComponent(0.12)
            light.color = UIColor(red: 0.84, green: 0.88, blue: 0.95, alpha: 1.0)
            return light
        }()
        spotlight.position = SCNVector3(0.25, 6.8, 5.8)
        spotlight.eulerAngles = SCNVector3(-1.18, 0.05, 0)
        scene.rootNode.addChildNode(spotlight)

        pyramidGlassNode.geometry = makePyramidGlassGeometry()
        scene.rootNode.addChildNode(pyramidGlassNode)

        scene.rootNode.addChildNode(pyramidEdgesNode)
        rebuildPyramidEdges()

        scene.rootNode.addChildNode(trendContentNode)

        for vertex in baseVertices {
            let markerNode = SCNNode(geometry: makeMarkerGeometry(color: vertex.domain.uiColor))
            markerNode.position = SCNVector3(vertex.position.x, vertex.position.y, vertex.position.z)
            scene.rootNode.addChildNode(markerNode)

            let labelNode = makeLabelNode(
                text: dominantLabelText(for: vertex.domain),
                color: vertex.domain.uiColor,
                fontSize: 0.64,
                scale: 0.36
            )
            labelNode.position = baseLabelPosition(for: vertex.domain)
            scene.rootNode.addChildNode(labelNode)
        }

        let apexMarkerNode = SCNNode(geometry: makeMarkerGeometry(color: UIColor(PrismColors.heading)))
        apexMarkerNode.position = SCNVector3(apexPosition.x, apexPosition.y, apexPosition.z)
        scene.rootNode.addChildNode(apexMarkerNode)

        let apexLabelNode = makeLabelNode(
            text: "10/10",
            color: UIColor(PrismColors.heading),
            fontSize: 0.82,
            scale: 0.42
        )
        apexLabelNode.position = SCNVector3(apexPosition.x, apexPosition.y + 0.52, apexPosition.z)
        scene.rootNode.addChildNode(apexLabelNode)

        let baseCenter = SIMD3<Float>(
            (baseVertices[0].position.x + baseVertices[1].position.x + baseVertices[2].position.x) / 3,
            baseVertices[0].position.y,
            (baseVertices[0].position.z + baseVertices[1].position.z + baseVertices[2].position.z) / 3
        )
        let baseLabelNode = makeLabelNode(
            text: "0/10",
            color: UIColor(PrismColors.heading),
            fontSize: 0.82,
            scale: 0.42
        )
        baseLabelNode.position = SCNVector3(baseCenter.x, baseCenter.y - 0.24, baseCenter.z)
        scene.rootNode.addChildNode(baseLabelNode)
    }

    private func rebuildPyramidEdges() {
        pyramidEdgesNode.childNodes.forEach { $0.removeFromParentNode() }

        let career = baseVertices[0].position
        let health = baseVertices[1].position
        let social = baseVertices[2].position
        let edges: [(SIMD3<Float>, SIMD3<Float>)] = [
            (career, health),
            (health, social),
            (social, career),
            (career, apexPosition),
            (health, apexPosition),
            (social, apexPosition)
        ]

        for edge in edges {
            pyramidEdgesNode.addChildNode(makeEdgeNode(from: edge.0, to: edge.1))
        }
    }

    private func makeEdgeNode(from start: SIMD3<Float>, to end: SIMD3<Float>) -> SCNNode {
        let vector = end - start
        let length = simd_length(vector)
        let cylinder = SCNCylinder(radius: 0.024, height: CGFloat(length))
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(
            red: 0.93,
            green: 0.96,
            blue: 1.0,
            alpha: 0.92
        )
        material.emission.contents = UIColor(
            red: 0.65,
            green: 0.80,
            blue: 1.0,
            alpha: 0.18
        )
        material.specular.contents = UIColor.white
        material.shininess = 0.9
        material.metalness.contents = 0.16
        material.roughness.contents = 0.28
        material.lightingModel = .physicallyBased
        cylinder.materials = [material]

        let node = SCNNode(geometry: cylinder)
        node.position = SCNVector3(
            (start.x + end.x) * 0.5,
            (start.y + end.y) * 0.5,
            (start.z + end.z) * 0.5
        )
        node.simdOrientation = simd_quatf(
            from: SIMD3<Float>(0, 1, 0),
            to: simd_normalize(vector)
        )
        return node
    }

    private func makePyramidGlassGeometry() -> SCNGeometry {
        let career = baseVertices[0].position
        let health = baseVertices[1].position
        let social = baseVertices[2].position
        let apex = apexPosition

        let vertices = [
            career, health, social,
            career, health, apex,
            health, social, apex,
            social, career, apex
        ]

        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: vertices.map { SCNVector3($0.x, $0.y, $0.z) })
            ],
            elements: [
                SCNGeometryElement(indices: Array(0..<vertices.count), primitiveType: .triangles)
            ]
        )

        let material = SCNMaterial()
        material.diffuse.contents = UIColor(
            red: 0.56,
            green: 0.58,
            blue: 0.60,
            alpha: 0.48
        )
        material.specular.contents = UIColor(
            white: 0.92,
            alpha: 0.12
        )
        material.emission.contents = UIColor(
            white: 0.25,
            alpha: 0.03
        )
        material.transparent.contents = UIColor(
            red: 0.56,
            green: 0.58,
            blue: 0.60,
            alpha: 0.48
        )
        material.transparency = 0.58
        material.metalness.contents = 0.0
        material.roughness.contents = 0.34
        material.fresnelExponent = 0.95
        material.blendMode = .alpha
        material.transparencyMode = .dualLayer
        material.writesToDepthBuffer = true
        material.readsFromDepthBuffer = true
        material.lightingModel = .physicallyBased
        material.isDoubleSided = true
        geometry.materials = [material]

        return geometry
    }

    private func makeMarkerGeometry(color: UIColor) -> SCNGeometry {
        let sphere = SCNSphere(radius: 0.22)
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = UIColor.clear
        material.specular.contents = UIColor.clear
        material.shininess = 0
        material.metalness.contents = 0.0
        material.roughness.contents = 0.95
        material.lightingModel = .physicallyBased
        sphere.materials = [material]
        return sphere
    }

    private func makeTrendMarkerGeometry() -> SCNGeometry {
        let sphere = SCNSphere(radius: 0.062)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(PrismColors.heading)
        material.emission.contents = UIColor(PrismColors.heading).withAlphaComponent(0.28)
        material.metalness.contents = 0.04
        material.roughness.contents = 0.22
        material.lightingModel = .physicallyBased
        sphere.materials = [material]
        return sphere
    }

    private func makeLabelNode(text: String, color: UIColor, fontSize: CGFloat, scale: Float) -> SCNNode {
        let textGeometry = SCNText(string: text, extrusionDepth: 0.02)
        textGeometry.font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        textGeometry.flatness = 0.2
        textGeometry.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        textGeometry.firstMaterial = {
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.emission.contents = UIColor.clear
            material.lightingModel = .constant
            material.isDoubleSided = true
            return material
        }()

        let textNode = SCNNode(geometry: textGeometry)
        let (minBounds, maxBounds) = textNode.boundingBox
        textNode.pivot = SCNMatrix4MakeTranslation(
            (maxBounds.x - minBounds.x) * 0.5 + minBounds.x,
            minBounds.y,
            0
        )
        textNode.scale = SCNVector3(scale, scale, scale)
        textNode.constraints = [SCNBillboardConstraint()]
        return textNode
    }

    private func baseLabelPosition(for domain: Domain) -> SCNVector3 {
        switch domain {
        case .career:
            return SCNVector3(baseVertices[0].position.x - 1.05, baseVertices[0].position.y - 0.10, baseVertices[0].position.z - 0.34)
        case .health:
            return SCNVector3(baseVertices[1].position.x + 1.05, baseVertices[1].position.y - 0.10, baseVertices[1].position.z - 0.34)
        case .social:
            return SCNVector3(baseVertices[2].position.x, baseVertices[2].position.y - 0.10, baseVertices[2].position.z + 1.02)
        }
    }

    private func dominantLabelText(for domain: Domain) -> String {
        switch domain {
        case .career:
            return "Career\nDominant"
        case .health:
            return "Health\nDominant"
        case .social:
            return "Social\nDominant"
        }
    }

    private func trendPosition(for checkIn: DailyCheckIn) -> SIMD3<Float> {
        let career = Float(checkIn.career)
        let health = Float(checkIn.health)
        let social = Float(checkIn.social)
        let total = career + health + social

        let weights: SIMD3<Float>
        if total == 0 {
            weights = SIMD3<Float>(repeating: 1.0 / 3.0)
        } else {
            weights = SIMD3<Float>(career / total, health / total, social / total)
        }

        let x =
            (weights.x * baseVertices[0].position.x) +
            (weights.y * baseVertices[1].position.x) +
            (weights.z * baseVertices[2].position.x)
        let z =
            (weights.x * baseVertices[0].position.z) +
            (weights.y * baseVertices[1].position.z) +
            (weights.z * baseVertices[2].position.z)
        let normalizedHeight = Float(checkIn.averageScore) / 10.0
        let basePoint = SIMD3<Float>(x, 0, z)

        // Keep the original bias-derived base position, then move it toward the
        // apex by the same fraction as the normalized height so the point remains
        // inside the pyramid volume at every level.
        return simd_mix(basePoint, apexPosition, SIMD3<Float>(repeating: normalizedHeight))
    }

    private func rebuildTrendNodes(points: [SIMD3<Float>]) {
        trendContentNode.childNodes.forEach { $0.removeFromParentNode() }
        guard !points.isEmpty else { return }

        let smoothedPoints = catmullRomPath(points: points, samplesPerSegment: 10)
        if smoothedPoints.count >= 2 {
            for index in 0..<(smoothedPoints.count - 1) {
                let start = smoothedPoints[index]
                let end = smoothedPoints[index + 1]
                let alpha = opacityProgress(index: index, total: smoothedPoints.count - 1)
                let segmentNode = makeTrendSegmentNode(from: start, to: end, alpha: alpha)
                trendContentNode.addChildNode(segmentNode)
            }
        }

        for index in points.indices {
            let point = points[index]
            let alpha = opacityProgress(index: index, total: max(points.count - 1, 1))
            let marker = SCNNode(geometry: makeTrendMarkerGeometry())
            marker.position = SCNVector3(point.x, point.y, point.z)
            marker.opacity = CGFloat(alpha)
            trendContentNode.addChildNode(marker)
        }

        if smoothedPoints.count >= 2 {
            let traceNode = makeTrendTraceNode()
            traceNode.position = SCNVector3(smoothedPoints[0].x, smoothedPoints[0].y, smoothedPoints[0].z)
            animateTrendTrace(traceNode, along: smoothedPoints)
            trendContentNode.addChildNode(traceNode)
        }
    }

    private func makeTrendSegmentNode(from start: SIMD3<Float>, to end: SIMD3<Float>, alpha: Float) -> SCNNode {
        let vector = end - start
        let length = simd_length(vector)
        let cylinder = SCNCylinder(radius: 0.018, height: CGFloat(length))
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(PrismColors.heading)
        material.emission.contents = UIColor(PrismColors.heading).withAlphaComponent(0.18)
        material.metalness.contents = 0.04
        material.roughness.contents = 0.3
        material.lightingModel = .physicallyBased
        cylinder.materials = [material]

        let node = SCNNode(geometry: cylinder)
        node.position = SCNVector3(
            (start.x + end.x) * 0.5,
            (start.y + end.y) * 0.5,
            (start.z + end.z) * 0.5
        )
        node.opacity = CGFloat(alpha)
        node.simdOrientation = simd_quatf(
            from: SIMD3<Float>(0, 1, 0),
            to: simd_normalize(vector)
        )
        return node
    }

    private func makeTrendTraceNode() -> SCNNode {
        let sphere = SCNSphere(radius: 0.072)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(PrismColors.heading).withAlphaComponent(0.92)
        material.emission.contents = UIColor(PrismColors.heading).withAlphaComponent(0.55)
        material.lightingModel = .constant
        material.blendMode = .add
        material.isDoubleSided = true
        sphere.materials = [material]

        let node = SCNNode(geometry: sphere)
        node.opacity = 0.0
        return node
    }

    private func animateTrendTrace(_ node: SCNNode, along points: [SIMD3<Float>]) {
        guard points.count >= 2 else { return }

        var actions: [SCNAction] = [
            .fadeOpacity(to: 0.85, duration: 0.2)
        ]

        for index in 1..<points.count {
            let start = points[index - 1]
            let end = points[index]
            let distance = CGFloat(simd_distance(start, end))
            let duration = max(0.03, TimeInterval(distance * 0.85))
            actions.append(.move(to: SCNVector3(end.x, end.y, end.z), duration: duration))
        }

        actions.append(.fadeOpacity(to: 0.0, duration: 0.22))
        actions.append(.wait(duration: 0.35))
        actions.append(.move(to: SCNVector3(points[0].x, points[0].y, points[0].z), duration: 0))

        let pulse = SCNAction.repeatForever(
            .sequence([
                .scale(to: 1.18, duration: 0.55),
                .scale(to: 0.92, duration: 0.55)
            ])
        )
        node.runAction(pulse, forKey: "trendTracePulse")
        node.runAction(.repeatForever(.sequence(actions)), forKey: "trendTracePath")
    }

    private func catmullRomPath(points: [SIMD3<Float>], samplesPerSegment: Int) -> [SIMD3<Float>] {
        guard points.count > 2 else { return points }

        var smoothed: [SIMD3<Float>] = []

        for index in 0..<(points.count - 1) {
            let p0 = points[max(index - 1, 0)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(index + 2, points.count - 1)]

            for sample in 0..<samplesPerSegment {
                let t = Float(sample) / Float(samplesPerSegment)
                smoothed.append(catmullRomPoint(p0: p0, p1: p1, p2: p2, p3: p3, t: t))
            }
        }

        if let last = points.last {
            smoothed.append(last)
        }

        return smoothed
    }

    private func catmullRomPoint(
        p0: SIMD3<Float>,
        p1: SIMD3<Float>,
        p2: SIMD3<Float>,
        p3: SIMD3<Float>,
        t: Float
    ) -> SIMD3<Float> {
        let t2 = t * t
        let t3 = t2 * t
        let term1 = 2.0 * p1
        let term2 = (-p0 + p2) * t
        let term3 = ((2.0 * p0) - (5.0 * p1) + (4.0 * p2) - p3) * t2
        let term4 = (-p0 + (3.0 * p1) - (3.0 * p2) + p3) * t3

        return 0.5 * (term1 + term2 + term3 + term4)
    }

    private func opacityProgress(index: Int, total: Int) -> Float {
        guard total > 0 else { return 1.0 }
        let progress = Float(index) / Float(total)
        return 0.22 + (progress * 0.78)
    }

}

private extension Domain {
    var uiColor: UIColor {
        UIColor(color)
    }
}
