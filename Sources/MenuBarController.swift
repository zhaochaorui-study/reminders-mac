import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject, ObservableObject {
    private let store: ReminderStore
    private let statusItem: NSStatusItem
    private let panel: MenuBarPanel
    private let contextMenu = NSMenu()
    private var cancellables: Set<AnyCancellable> = []
    private var hostingController: NSHostingController<MenuBarRootView>?
    private var panelAnimationToken = UUID()

    private let panelSize = CGSize(width: 320, height: 520)
    private let panelGap: CGFloat = 10
    private let panelInitialScale: CGFloat = 0.92
    private let panelSlideOffset: CGFloat = 8
    private let panelShowDuration: TimeInterval = 0.28
    private let panelHideDuration: TimeInterval = 0.18

    init(store: ReminderStore) {
        self.store = store
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.panel = MenuBarPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()
        configureStatusItem()
        configurePanel()
        bindStore()
        refreshUI()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(togglePanel(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.appearsDisabled = false
        button.toolTip = "Reminders"

        configureContextMenu()
    }

    private func configureContextMenu() {
        contextMenu.removeAllItems()
        contextMenu.addItem(
            withTitle: "退出",
            action: #selector(terminateApp(_:)),
            keyEquivalent: "q"
        )
        contextMenu.items.forEach { $0.target = self }
    }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.animationBehavior = .utilityWindow
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let controller = NSHostingController(rootView: MenuBarRootView(store: store))
        controller.view.frame = NSRect(origin: .zero, size: panelSize)
        hostingController = controller
        panel.contentViewController = controller
        panel.setContentSize(panelSize)
        syncHostingViewLayerGeometry()
        setPanelContent(scale: 1, opacity: 1, translateY: 0)
    }

    private func bindStore() {
        store.$pendingItems
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshUI()
            }
            .store(in: &cancellables)

        store.$highlightedReminderID
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshUI()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .reminderDidAutoPresent)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.hidePanel(animated: false)
            }
            .store(in: &cancellables)

    }

    private func refreshUI() {
        updateStatusItemImage()
        updatePanelLayout()
    }

    private func updateStatusItemImage() {
        guard let button = statusItem.button else {
            return
        }

        let renderer = ImageRenderer(
            content: MenuBarStatusIconView(
                pendingCount: store.pendingCount,
                hasHighlightedReminder: store.highlightedReminder != nil
            )
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        let image = renderer.nsImage
        image?.isTemplate = false
        button.image = image
    }

    private func updatePanelLayout() {
        hostingController?.rootView = MenuBarRootView(store: store)
        panel.setContentSize(panelSize)
        syncHostingViewLayerGeometry()
    }

    private func showPanel(animated: Bool) {
        guard let button = statusItem.button else {
            return
        }

        store.refreshForPanelPresentation()
        let targetFrame = panelFrame(relativeTo: button)
        panelAnimationToken = UUID()

        panel.setFrame(targetFrame, display: false)
        syncHostingViewLayerGeometry()

        if animated {
            setPanelContent(scale: panelInitialScale, opacity: 0, translateY: panelSlideOffset)
            panel.makeKeyAndOrderFront(nil)

            animatePanelContent(
                scale: 1,
                opacity: 1,
                translateY: 0,
                duration: panelShowDuration,
                timingFunction: CAMediaTimingFunction(controlPoints: 0.2, 1.2, 0.4, 1)
            )
        } else {
            setPanelContent(scale: 1, opacity: 1, translateY: 0)
            panel.makeKeyAndOrderFront(nil)
        }
    }

    private func hidePanel(animated: Bool) {
        guard panel.isVisible else {
            return
        }

        let animationToken = UUID()
        panelAnimationToken = animationToken

        if animated {
            syncHostingViewLayerGeometry()

            animatePanelContent(
                scale: panelInitialScale,
                opacity: 0,
                translateY: panelSlideOffset,
                duration: panelHideDuration,
                timingFunction: CAMediaTimingFunction(name: .easeIn)
            ) { [weak self] in
                guard let self, self.panelAnimationToken == animationToken else {
                    return
                }

                self.panel.orderOut(nil)
                self.setPanelContent(scale: 1, opacity: 1, translateY: 0)
            }
        } else {
            panel.orderOut(nil)
            setPanelContent(scale: 1, opacity: 1, translateY: 0)
        }
    }

    private func syncHostingViewLayerGeometry() {
        guard let hostingView = hostingController?.view else {
            return
        }

        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.frame = NSRect(origin: .zero, size: panelSize)

        guard let layer = hostingView.layer else {
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.anchorPoint = CGPoint(x: 0.5, y: 1)
        layer.position = CGPoint(x: hostingView.bounds.midX, y: hostingView.bounds.maxY)
        layer.allowsEdgeAntialiasing = true
        CATransaction.commit()
    }

    private func setPanelContent(scale: CGFloat, opacity: Float, translateY: CGFloat) {
        guard let layer = hostingController?.view.layer else {
            return
        }

        layer.removeAnimation(forKey: "panelTransform")
        layer.removeAnimation(forKey: "panelOpacity")

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.opacity = opacity
        var transform = CGAffineTransform(scaleX: scale, y: scale)
        transform = transform.translatedBy(x: 0, y: -translateY / scale)
        layer.transform = CATransform3DMakeAffineTransform(transform)
        CATransaction.commit()
    }

    private func animatePanelContent(
        scale: CGFloat,
        opacity: Float,
        translateY: CGFloat,
        duration: TimeInterval,
        timingFunction: CAMediaTimingFunction,
        completion: (() -> Void)? = nil
    ) {
        guard let layer = hostingController?.view.layer else {
            completion?()
            return
        }

        var targetTransform = CGAffineTransform(scaleX: scale, y: scale)
        targetTransform = targetTransform.translatedBy(x: 0, y: -translateY / scale)
        let target3D = CATransform3DMakeAffineTransform(targetTransform)

        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)

        let transformAnim = CABasicAnimation(keyPath: "transform")
        transformAnim.fromValue = layer.presentation()?.transform ?? layer.transform
        transformAnim.toValue = target3D
        transformAnim.duration = duration
        transformAnim.timingFunction = timingFunction
        transformAnim.fillMode = .forwards
        transformAnim.isRemovedOnCompletion = false

        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = layer.presentation()?.opacity ?? layer.opacity
        opacityAnim.toValue = opacity
        opacityAnim.duration = duration
        opacityAnim.timingFunction = timingFunction
        opacityAnim.fillMode = .forwards
        opacityAnim.isRemovedOnCompletion = false

        layer.transform = target3D
        layer.opacity = opacity

        layer.add(transformAnim, forKey: "panelTransform")
        layer.add(opacityAnim, forKey: "panelOpacity")

        CATransaction.commit()
    }

    private func panelFrame(relativeTo button: NSStatusBarButton) -> NSRect {
        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let screenRect = button.window?.convertToScreen(buttonRectInWindow) ?? .zero
        let screen = button.window?.screen ?? NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? .zero

        let x = min(
            max(visibleFrame.minX + 8, screenRect.midX - (panelSize.width / 2)),
            visibleFrame.maxX - panelSize.width - 8
        )
        let y = max(visibleFrame.minY + 8, screenRect.minY - panelSize.height - panelGap)

        return NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height)
    }

    @objc
    private func togglePanel(_ sender: AnyObject?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
            return
        }

        if panel.isVisible {
            hidePanel(animated: true)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            showPanel(animated: true)
        }
    }

    @objc
    private func terminateApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func showContextMenu() {
        guard let button = statusItem.button else {
            return
        }

        hidePanel(animated: false)
        statusItem.menu = contextMenu
        button.performClick(nil)
        statusItem.menu = nil
    }
}

private final class MenuBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private struct MenuBarStatusIconView: View {
    let pendingCount: Int
    let hasHighlightedReminder: Bool

    private var hasPendingItems: Bool {
        pendingCount > 0
    }

    private var countText: String {
        if pendingCount > 99 {
            return "99+"
        }

        return "\(max(pendingCount, 1))"
    }

    var body: some View {
        Group {
            if hasPendingItems {
                Text(countText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(hasHighlightedReminder ? RemindersPalette.accentRedDark : RemindersPalette.darkPrimaryText)
                    .padding(.horizontal, countText.count > 1 ? 2 : 0)
                    .frame(minWidth: 16, minHeight: 16)
            } else {
                Circle()
                    .stroke(RemindersPalette.darkPrimaryText, lineWidth: 1.5)
                    .background(Circle().fill(Color.clear))
                    .frame(width: 16, height: 16)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(RemindersPalette.darkPrimaryText)
                    }
            }
        }
        .frame(minWidth: 18, minHeight: 18)
        .padding(1)
    }
}
