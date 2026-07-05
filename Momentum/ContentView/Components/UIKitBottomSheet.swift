//
//  UIKitBottomSheet.swift
//  Momentum
//
//  UIKit-backed persistent bottom sheet using UISheetPresentationController.
//  This is the same approach Apple Maps uses — a UIKit sheet with custom detents
//  that can present sub-modals (sheets, fullScreenCovers) from within.
//
//  Exposes a `sheetProgress` environment value (0 = collapsed, 1 = expanded)
//  that updates in real time during drag so child views can animate layout.
//

import SwiftUI
import UIKit

// MARK: - Environment Key for sheet progress

/// A value from 0 (collapsed) to 1 (fully expanded) representing the current
/// drag position of the bottom sheet. Updates continuously during interaction.
struct SheetProgressKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var sheetProgress: CGFloat {
        get { self[SheetProgressKey.self] }
        set { self[SheetProgressKey.self] = newValue }
    }
}

// MARK: - View Modifier

extension View {
    /// Attaches a UIKit-backed persistent bottom sheet that supports presenting
    /// sub-modals from within (unlike SwiftUI's `.sheet`).
    func uiKitBottomSheet<Content: View>(
        isExpanded: Binding<Bool>,
        barHeight: CGFloat = 105,
        cornerRadius: CGFloat = 24,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.background(
            UIKitSheetPresenter(
                isExpanded: isExpanded,
                barHeight: barHeight,
                cornerRadius: cornerRadius,
                sheetContent: content
            )
        )
    }
}

// MARK: - UIKit Sheet Presenter

private struct UIKitSheetPresenter<SheetContent: View>: UIViewControllerRepresentable {
    @Binding var isExpanded: Bool
    let barHeight: CGFloat
    let cornerRadius: CGFloat
    @ViewBuilder let sheetContent: () -> SheetContent

    func makeUIViewController(context: Context) -> SheetAnchorController<SheetContent> {
        let anchor = SheetAnchorController<SheetContent>()
        anchor.barHeight = barHeight
        anchor.cornerRadius = cornerRadius
        anchor.onDetentChange = { identifier in
            DispatchQueue.main.async {
                isExpanded = (identifier == .large)
            }
        }
        return anchor
    }

    func updateUIViewController(_ controller: SheetAnchorController<SheetContent>, context: Context) {
        controller.updateContent(sheetContent())
        controller.updateDetent(isExpanded: isExpanded)
    }
}

// MARK: - Anchor Controller

final class SheetAnchorController<SheetContent: View>: UIViewController {
    var onDetentChange: ((UISheetPresentationController.Detent.Identifier) -> Void)?
    var barHeight: CGFloat = 105
    var cornerRadius: CGFloat = 24
    private var sheetController: SheetContentController<SheetContent>?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tryPresent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.main.async { [weak self] in
            self?.tryPresent()
        }
    }

    func updateContent(_ content: SheetContent) {
        // If the sheet was dismissed externally (e.g. by a SwiftUI .sheet taking over),
        // clear the stale reference so tryPresent() can re-create it
        if let existing = sheetController, existing.presentingViewController == nil {
            sheetController = nil
        }
        
        if let controller = sheetController {
            controller.updateContent(content)
        } else {
            tryPresent()
        }
    }

    func updateDetent(isExpanded: Bool) {
        if let existing = sheetController {
            existing.updateDetent(isExpanded: isExpanded)
        }
    }

    private func tryPresent() {
        // If the sheet controller still exists but was dismissed, clear it
        if let existing = sheetController, existing.presentingViewController == nil {
            sheetController = nil
        }
        
        guard sheetController == nil,
              presentedViewController == nil,
              view.window != nil else { return }

        let content = SheetContentController<SheetContent>(barHeight: barHeight)
        content.onDetentChange = onDetentChange

        if let sheet = content.sheetPresentationController {
            let barDetent = UISheetPresentationController.Detent.custom(identifier: .init("bottomBar")) { [barHeight] _ in
                return barHeight
            }
            sheet.detents = [barDetent, .large()]
            sheet.selectedDetentIdentifier = .init("bottomBar")
            sheet.prefersGrabberVisible = false
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.largestUndimmedDetentIdentifier = .init("bottomBar")
            sheet.preferredCornerRadius = cornerRadius
            sheet.delegate = content
        }

        content.isModalInPresentation = true
        sheetController = content
        present(content, animated: false)
    }
}

// MARK: - Sheet Content Controller

final class SheetContentController<SheetContent: View>: UIViewController, UISheetPresentationControllerDelegate {
    var onDetentChange: ((UISheetPresentationController.Detent.Identifier) -> Void)?
    private var hostingController: UIHostingController<AnyView>?
    private var displayLink: CADisplayLink?
    private var latestContent: SheetContent?

    /// The collapsed bar height (used to compute progress fraction).
    private let barHeight: CGFloat

    /// Published progress value: 0 = collapsed at barHeight, 1 = fully expanded.
    private var currentProgress: CGFloat = 0

    init(barHeight: CGFloat = 105) {
        self.barHeight = barHeight
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startTrackingProgress()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopTrackingProgress()
    }

    // MARK: - Progress Tracking via Display Link

    private func startTrackingProgress() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(trackFrame))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopTrackingProgress() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func trackFrame() {
        guard let presentationLayer = view.superview?.layer.presentation() else { return }
        let currentY = presentationLayer.frame.origin.y
        let screenHeight = view.window?.bounds.height ?? UIScreen.main.bounds.height
        let safeTop = view.window?.safeAreaInsets.top ?? 0

        // Sheet top at collapsed = screenHeight - barHeight - safeAreaBottom
        // Sheet top at expanded = safeTop
        let collapsedY = screenHeight - barHeight - (view.window?.safeAreaInsets.bottom ?? 0)
        let expandedY = safeTop

        guard collapsedY > expandedY else { return }
        let progress = 1.0 - ((currentY - expandedY) / (collapsedY - expandedY))
        let clamped = min(max(progress, 0), 1)

        if abs(clamped - currentProgress) > 0.005 {
            currentProgress = clamped
            refreshContent()
        }
    }

    // MARK: - Content

    func updateContent(_ content: SheetContent) {
        latestContent = content
        refreshContent()
    }

    private func refreshContent() {
        guard let content = latestContent else { return }
        let wrappedView = AnyView(
            content
                .environment(\.sheetProgress, currentProgress)
        )

        if let host = hostingController {
            host.rootView = wrappedView
        } else {
            let host = UIHostingController(rootView: wrappedView)
            host.view.backgroundColor = .clear
            addChild(host)
            view.addSubview(host.view)
            host.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                host.view.topAnchor.constraint(equalTo: view.topAnchor),
                host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            host.didMove(toParent: self)
            hostingController = host
        }
    }

    func updateDetent(isExpanded: Bool) {
        guard let sheet = sheetPresentationController else { return }
        let target: UISheetPresentationController.Detent.Identifier = isExpanded ? .large : .init("bottomBar")
        guard sheet.selectedDetentIdentifier != target else { return }
        sheet.animateChanges {
            sheet.selectedDetentIdentifier = target
        }
    }

    // MARK: UISheetPresentationControllerDelegate

    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(_ controller: UISheetPresentationController) {
        if let id = controller.selectedDetentIdentifier {
            onDetentChange?(id)
        }
    }
}
