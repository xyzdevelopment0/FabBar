import SwiftUI
import UIKit

/// A UIViewRepresentable that wraps a TabBarSegmentedControl for tab bar functionality.
/// Tab content (icon + label) is injected directly into each segment's view subtree so that
/// the glass magnification effect applies to the content. SF Symbols remain vector-based
/// and scale at any resolution, avoiding rasterization issues in accessibility popovers.
@available(iOS 26.0, *)
struct FabBarRepresentable<Value: Hashable>: UIViewRepresentable {
    var tabs: [FabBarTab<Value>]
    var action: FabBarAction
    var inactiveTint: Color?
    var interactiveGlass: Bool

    @Binding var activeTab: Value

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> GlassTabBarView {
        let images = tabs.compactMap { _ in
            UIImage(systemName: "circle")
        }
        let control = TabBarSegmentedControl(items: images)
        control.showsLargeContentViewer = false
        let selectedIndex = tabs.firstIndex { $0.value == activeTab } ?? 0
        control.selectedSegmentIndex = selectedIndex

        configureSegmentContent(on: control)
        control.selectedSegmentTintColor = segmentTintColor(for: control.traitCollection.userInterfaceStyle)
        control.inactiveTintColor = inactiveTintColor

        control.addTarget(context.coordinator, action: #selector(context.coordinator.tabSelected(_:)), for: .valueChanged)

        // Handle reselection (tapping already-selected segment)
        let coordinator = context.coordinator
        control.onReselect = { [weak coordinator] index in
            guard let coordinator else { return }
            if index >= 0 && index < coordinator.parent.tabs.count {
                coordinator.parent.tabs[index].onReselect?()
            }
        }

        // Wrap in glass tab bar view with segmented control and FAB
        let container = GlassTabBarView(
            segmentedControl: control,
            tabCount: tabs.count,
            action: action,
            interactiveGlass: interactiveGlass
        )

        return container
    }

    func updateUIView(_ uiView: GlassTabBarView, context: Context) {
        context.coordinator.parent = self

        let control = uiView.segmentedControl

        // Assigning selectedSegmentTintColor makes UISegmentedControl rebuild its selection
        // indicator. updateUIView runs on every selection change, so reassigning the same
        // color there re-renders the indicator mid-transition and reads as a brief flash.
        // Only assign when the resolved color would actually differ.
        let interfaceStyle = uiView.traitCollection.userInterfaceStyle
        if context.coordinator.appliedInterfaceStyle != interfaceStyle {
            context.coordinator.appliedInterfaceStyle = interfaceStyle
            control.selectedSegmentTintColor = segmentTintColor(for: interfaceStyle)
        }

        control.inactiveTintColor = inactiveTintColor
        uiView.interactiveGlass = interactiveGlass

        // Sync segments when tabs change (count, order, or identity)
        let currentTabValues = tabs.map(\.value)
        if currentTabValues != context.coordinator.previousTabValues {
            context.coordinator.previousTabValues = currentTabValues

            // Rebuild all segments — configureSegmentContent replaces all
            // injected content views anyway, so incremental patching adds
            // complexity without benefit.
            control.removeAllSegments()
            for _ in tabs {
                control.insertSegment(
                    with: UIImage(systemName: "circle"),
                    at: control.numberOfSegments,
                    animated: false
                )
            }

            configureSegmentContent(on: control)
            uiView.updateTabCount(tabs.count)
        }

        let newIndex = tabs.firstIndex { $0.value == activeTab } ?? 0
        if control.selectedSegmentIndex != newIndex {
            control.selectedSegmentIndex = newIndex
        }

        // Set accent color from the view's inherited tintColor, converted to a concrete color.
        // Only update when tintAdjustmentMode is normal — when dimmed (e.g. sheet presented),
        // tintColor returns a dimmed gray which would incorrectly overwrite the accent color.
        if uiView.tintAdjustmentMode == .normal, let tint = uiView.tintColor {
            let concreteAccentColor = UIColor(cgColor: tint.cgColor)
            control.activeTintColor = concreteAccentColor
        }
    }

    /// Sets accessibility titles, injects content views, and configures segment widths.
    private func configureSegmentContent(on control: TabBarSegmentedControl) {
        for (index, tab) in tabs.enumerated() {
            control.setTitle(tab.title, forSegmentAt: index)
        }

        // Content views use draw(_:) rendering with NSCoding support, so when the
        // accessibility popover archives/unarchives them they hide (via init(coder:)),
        // letting the native segment labels render crisply at popover scale.
        // Two views per segment: base (inactive) underneath, accent (active) on top
        // masked to the glass indicator position.
        let baseViews = tabs.map(makeContentView)
        let accentViews = tabs.map(makeContentView)
        control.configureContentViews(baseViews, accentViews: accentViews)

        // Fixed width for <3 tabs (glass floats leading-aligned); 0 for 3+ (auto-distribute)
        for index in 0..<tabs.count {
            control.setWidth(tabs.count < 3 ? Constants.fewTabsSegmentWidth : 0, forSegmentAt: index)
        }
    }

    private func makeContentView(for tab: FabBarTab<Value>) -> TabItemContentView {
        if let imageName = tab.image {
            TabItemContentView(
                title: tab.title,
                imageName: imageName,
                imageBundle: tab.imageBundle,
                imageSize: tab.imageSize
            )
        } else {
            TabItemContentView(title: tab.title, symbolName: tab.systemImage ?? "")
        }
    }

    private var inactiveTintColor: UIColor {
        if let inactiveTint {
            UIColor(inactiveTint)
        } else {
            .label
        }
    }

    private func segmentTintColor(for interfaceStyle: UIUserInterfaceStyle) -> UIColor {
        switch interfaceStyle {
        case .dark:
            return .label.withAlphaComponent(0.15)
        default:
            return .label.withAlphaComponent(0.08)
        }
    }

    @MainActor
    class Coordinator: NSObject {
        var parent: FabBarRepresentable<Value>
        var previousTabValues: [Value]

        /// Interface style the segment tint was last resolved for, so it is only reassigned
        /// when it would actually change.
        var appliedInterfaceStyle: UIUserInterfaceStyle?

        init(parent: FabBarRepresentable<Value>) {
            self.parent = parent
            self.previousTabValues = parent.tabs.map(\.value)
        }

        @objc func tabSelected(_ control: UISegmentedControl) {
            let index = control.selectedSegmentIndex
            if index >= 0 && index < parent.tabs.count {
                parent.activeTab = parent.tabs[index].value
            }
        }
    }
}
