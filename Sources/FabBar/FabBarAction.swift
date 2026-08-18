import Foundation

/// Configuration for the floating action button (FAB) in FabBar.
///
/// The FAB appears as a circular glass button next to the tab items,
/// morphing with the iOS 26 glass effect.
@available(iOS 26.0, *)
public struct FabBarAction {
    /// The SF Symbol name for the button icon. Used when `image` is nil.
    public let systemImage: String?

    /// The custom image name from a bundle. Takes precedence over `systemImage` when set.
    public let image: String?

    /// The bundle containing the custom image. Defaults to `.main` if not specified.
    public let imageBundle: Bundle?

    /// The point size to draw the custom image at. Uses the image's own size when nil.
    public let imageSize: CGFloat?

    /// The accessibility label for VoiceOver users.
    public let accessibilityLabel: String

    /// The action to perform when the button is tapped.
    public let action: () -> Void

    /// Creates a floating action button with an SF Symbol icon.
    ///
    /// - Parameters:
    ///   - systemImage: The SF Symbol name for the button icon.
    ///   - accessibilityLabel: The accessibility label for VoiceOver users.
    ///   - action: The action to perform when the button is tapped.
    public init(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.image = nil
        self.imageBundle = nil
        self.imageSize = nil
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    /// Creates a floating action button with a custom image from a bundle.
    ///
    /// The image is drawn as a template, tinted to match the FAB's foreground color.
    ///
    /// - Parameters:
    ///   - image: The custom image name.
    ///   - imageBundle: The bundle containing the image. Defaults to `.main`.
    ///   - imageSize: The point size to draw the image at. Defaults to the image's own size.
    ///   - accessibilityLabel: The accessibility label for VoiceOver users.
    ///   - action: The action to perform when the button is tapped.
    public init(
        image: String,
        imageBundle: Bundle? = nil,
        imageSize: CGFloat? = nil,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.systemImage = nil
        self.image = image
        self.imageBundle = imageBundle ?? .main
        self.imageSize = imageSize
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }
}
