import UIKit

/// A custom-draw view that renders a tab item (SF Symbol icon + title) at the current graphics context scale.
///
/// This view supports `NSCoding` so it survives the system accessibility popover's archive/unarchive cycle.
/// When the popover copies segment content, it archives this view and unarchives a copy. Because the
/// symbol name and title are encoded as simple strings, the copy can re-render via `draw(_:)` at whatever
/// scale the popover uses — producing crisp output without any timing hacks or pre-rendered bitmaps.
@available(iOS 26.0, *)
@objc(FabBarTabItemContentView)
final class TabItemContentView: UIView {
    private var symbolName: String = ""
    private var customImageName: String = ""
    private var customImageBundleIdentifier: String = ""
    private var customImageSize: CGFloat = 0
    private var title: String = ""

    private let font = UIFont.systemFont(ofSize: Constants.tabTitleFontSize, weight: .semibold)

    /// Height reserved for the icon. Grows when a custom image is larger than the standard area.
    private var imageAreaHeight: CGFloat {
        max(Constants.iconViewSize, customImageSize)
    }

    init(title: String, symbolName: String) {
        self.title = title
        self.symbolName = symbolName
        super.init(frame: .zero)
        isOpaque = false
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    init(title: String, imageName: String, imageBundle: Bundle?, imageSize: CGFloat?) {
        self.title = title
        self.customImageName = imageName
        self.customImageBundleIdentifier = imageBundle?.bundleIdentifier ?? ""
        self.customImageSize = imageSize ?? 0
        super.init(frame: .zero)
        isOpaque = false
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    // MARK: - NSCoding

    required init?(coder: NSCoder) {
        self.symbolName = coder.decodeObject(forKey: "symbolName") as? String ?? ""
        self.customImageName = coder.decodeObject(forKey: "customImageName") as? String ?? ""
        self.customImageBundleIdentifier = coder.decodeObject(forKey: "customImageBundleIdentifier") as? String ?? ""
        self.customImageSize = coder.decodeDouble(forKey: "customImageSize")
        self.title = coder.decodeObject(forKey: "title") as? String ?? ""
        super.init(coder: coder)
        // When unarchived by the accessibility popover, hide this view so only the
        // native segment labels are visible. The system renders those at popover scale.
        isHidden = true
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(symbolName, forKey: "symbolName")
        coder.encode(customImageName, forKey: "customImageName")
        coder.encode(customImageBundleIdentifier, forKey: "customImageBundleIdentifier")
        coder.encode(Double(customImageSize), forKey: "customImageSize")
        coder.encode(title, forKey: "title")
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        setNeedsDisplay()
    }

    // MARK: - Sizing

    override var intrinsicContentSize: CGSize {
        let textSize = (title as NSString).size(withAttributes: [.font: font])
        let icon = loadIcon()
        let contentWidth = max(icon?.size.width ?? 0, textSize.width)
        let height = imageAreaHeight + textSize.height
        return CGSize(width: contentWidth, height: height)
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        let tintColor = tintColor ?? .label

        let icon = loadIcon()
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: tintColor,
        ]
        let textSize = (title as NSString).size(withAttributes: textAttributes)

        let contentNudgeUp: CGFloat = 1
        let iconTextGap: CGFloat = 1

        // Draw icon centered in top area
        if let icon {
            let imageSize = icon.size
            let imageX = (bounds.width - imageSize.width) / 2
            let imageY = (imageAreaHeight - imageSize.height) / 2 - contentNudgeUp
            let imageRect = CGRect(x: imageX, y: imageY, width: imageSize.width, height: imageSize.height)

            tintColor.setFill()
            icon.withRenderingMode(.alwaysTemplate).draw(in: imageRect)
        }

        // Draw text centered below icon area
        let textX = (bounds.width - textSize.width) / 2
        let textPoint = CGPoint(x: textX, y: imageAreaHeight - contentNudgeUp + iconTextGap)
        (title as NSString).draw(at: textPoint, withAttributes: textAttributes)
    }

    // MARK: - Private

    private func loadIcon() -> UIImage? {
        let config = UIImage.SymbolConfiguration(
            pointSize: Constants.tabIconPointSize,
            weight: .medium,
            scale: .large
        )

        if !symbolName.isEmpty {
            return UIImage(systemName: symbolName, withConfiguration: config)
        } else if !customImageName.isEmpty {
            let bundle: Bundle?
            if customImageBundleIdentifier.isEmpty {
                bundle = .main
            } else {
                bundle = Bundle(identifier: customImageBundleIdentifier)
            }
            let image = UIImage(named: customImageName, in: bundle, with: config)
            guard customImageSize > 0 else { return image }
            return image?.resized(fittingSquareOf: customImageSize)
        }

        return nil
    }
}

@available(iOS 26.0, *)
extension UIImage {
    /// Redraws the image to fit a square of the given point size, preserving aspect ratio.
    func resized(fittingSquareOf side: CGFloat) -> UIImage {
        guard size.width > 0, size.height > 0 else { return self }

        let scale = min(side / size.width, side / size.height)
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)

        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        .withRenderingMode(.alwaysTemplate)
    }
}
