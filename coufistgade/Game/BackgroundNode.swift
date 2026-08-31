//
//  BackgroundNode.swift
//  coufistgade
//
//  The scene's backdrop (UI_DESIGN §11: subtle gradient, no busy textures).
//  Extracted from GameScene so that the scene stays an assembler rather than
//  carrying 30 lines of drawing code unrelated to physics.
//

import SpriteKit

final class BackgroundNode: SKSpriteNode {

    private static let zPosition: CGFloat = -100

    /// Avoids re-rasterising the gradient on every layout pass; the size only
    /// really changes on rotation, which this game does not do.
    private var renderedSize: CGSize = .zero

    init() {
        super.init(texture: nil, color: .clear, size: .zero)
        name = "background"
        zPosition = Self.zPosition
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("BackgroundNode is code-only; this app uses no storyboards or nibs.")
    }

    /// Resizes and, if needed, re-renders to fill a scene of `sceneSize`.
    func fill(sceneSize: CGSize) {
        guard sceneSize.width > 0, sceneSize.height > 0 else { return }

        size = sceneSize
        position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)

        guard sceneSize != renderedSize else { return }
        texture = Self.makeGradientTexture(size: sceneSize)
        renderedSize = sceneSize
    }

    /// Rasterised once per size rather than composited every frame
    /// (ARCHITECTURE §23).
    private static func makeGradientTexture(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cgContext = context.cgContext
            let colors = [
                UIColor(resource: .gameBackgroundCenter).cgColor,
                UIColor(resource: .appBackground).cgColor,
            ]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            ) else {
                UIColor(resource: .appBackground).setFill()
                cgContext.fill(CGRect(origin: .zero, size: size))
                return
            }

            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            cgContext.drawRadialGradient(
                gradient,
                startCenter: centre,
                startRadius: 0,
                endCenter: centre,
                endRadius: max(size.width, size.height)
                    * GameConfiguration.World.backgroundGradientRadiusRatio,
                options: [.drawsAfterEndLocation]
            )
        }
        return SKTexture(image: image)
    }
}
