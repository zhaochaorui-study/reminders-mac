import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject, ObservableObject {
    private let store: ReminderStore
    private let onShowSettings: @MainActor () -> Void
    private let statusItem: NSStatusItem
    private let panel: MenuBarPanel
    private let contextMenu = NSMenu()
    private var cancellables: Set<AnyCancellable> = []
    private var hostingController: NSHostingController<MenuBarRootView>?
    private var panelAnimationToken = UUID()

    private let panelSize = CGSize(width: 320, height: 520)
    private let panelGap: CGFloat = 10
    private let panelRevealScale: CGFloat = 0.20
    private let panelShowDuration: TimeInterval = 0.32
    private let panelHideDuration: TimeInterval = 0.20
    private let panelShowTimingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
    private let panelHideTimingFunction = CAMediaTimingFunction(controlPoints: 0.32, 0.0, 0.58, 1.0)
    private let defaultPanelAnchorPoint = CGPoint(x: 0.5, y: 1)
    private var panelContentAnchorPoint = CGPoint(x: 0.5, y: 1)
    private let menuBarTitleMaxWidth: CGFloat = 88
 
    init(store: ReminderStore, onShowSettings: @escaping @MainActor () -> Void) {
        self.store = store
        self.onShowSettings = onShowSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
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
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        button.appearsDisabled = false
        button.toolTip = "Reminders"
        statusItem.length = NSStatusItem.squareLength
 
        configureContextMenu()
    }

    private func configureContextMenu() {
        contextMenu.removeAllItems()
        contextMenu.addItem(
            withTitle: "设置…",
            action: #selector(showSettings(_:)),
            keyEquivalent: ""
        )
        contextMenu.addItem(.separator())
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

        ReminderPreferences.shared.$menuBarShowLatestTodo
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshUI()
            }
            .store(in: &cancellables)

    }

    private func refreshUI() {
        updateStatusItemImage()
    }

    private func updateStatusItemImage() {
        guard let button = statusItem.button else {
            return
        }

        let statusStyle: MenuStatusGlyphView.Style = {
            if store.pendingCount == 0 {
                return .normal
            }

            return store.highlightedReminder != nil ? .alert : .pending
        }()

        let renderer = ImageRenderer(
            content: MenuStatusGlyphView(style: statusStyle, badgeCount: store.pendingCount)
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        let image = renderer.nsImage ?? NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Reminders")
        image?.isTemplate = false
        button.image = image

        if ReminderPreferences.shared.menuBarShowLatestTodo {
            let calendar = Calendar.autoupdatingCurrent
            let firstPending = store.pendingItems.first { item in
                !item.isCompleted && calendar.isDateInToday(item.scheduledAt)
            }
            if let item = firstPending {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                let time = formatter.string(from: item.scheduledAt)
                let normalizedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let truncatedTitle = String(normalizedTitle.prefix(4))
                let titleSegments = [time, truncatedTitle].filter { !$0.isEmpty }
                let title = titleSegments.joined(separator: " ")

                button.title = title
                statusItem.length = min(
                    NSStatusItem.squareLength + menuBarTitleMaxWidth,
                    max(NSStatusItem.squareLength, button.intrinsicContentSize.width + 12)
                )
            } else {
                button.title = ""
                statusItem.length = NSStatusItem.squareLength
            }
        } else {
            button.title = ""
            statusItem.length = NSStatusItem.squareLength
        }
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
        updatePanelLayout()
        let targetFrame = panelFrame(relativeTo: button)
        panelContentAnchorPoint = panelRevealAnchorPoint(relativeTo: button, targetFrame: targetFrame)
        panelAnimationToken = UUID()
        let shouldAnimate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        panel.setFrame(targetFrame, display: false)
        syncHostingViewLayerGeometry()

        if shouldAnimate {
            setPanelContent(scale: panelRevealScale, opacity: 0, translateY: 0)
            panel.makeKeyAndOrderFront(nil)

            let animationToken = panelAnimationToken
            DispatchQueue.main.async { [weak self] in
                guard let self, self.panelAnimationToken == animationToken, self.panel.isVisible else {
                    return
                }

                self.animatePanelContent(
                    scale: 1,
                    opacity: 1,
                    translateY: 0,
                    duration: self.panelShowDuration,
                    timingFunction: self.panelShowTimingFunction
                )
            }
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
        let shouldAnimate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        if shouldAnimate {
            syncHostingViewLayerGeometry()

            animatePanelContent(
                scale: panelRevealScale,
                opacity: 0,
                translateY: 0,
                duration: panelHideDuration,
                timingFunction: panelHideTimingFunction
            ) { [weak self] in
                guard let self, self.panelAnimationToken == animationToken else {
                    return
                }

                self.panel.orderOut(nil)
                self.resetPanelPresentationState()
            }
        } else {
            panel.orderOut(nil)
            resetPanelPresentationState()
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
        layer.anchorPoint = panelContentAnchorPoint
        layer.position = CGPoint(
            x: hostingView.bounds.width * panelContentAnchorPoint.x,
            y: hostingView.bounds.height * panelContentAnchorPoint.y
        )
        layer.allowsEdgeAntialiasing = true
        CATransaction.commit()
    }

    private func resetPanelPresentationState() {
        panelContentAnchorPoint = defaultPanelAnchorPoint
        syncHostingViewLayerGeometry()
        setPanelContent(scale: 1, opacity: 1, translateY: 0)
    }

    private func panelRevealAnchorPoint(relativeTo button: NSStatusBarButton, targetFrame: NSRect) -> CGPoint {
        guard let window = button.window else {
            return defaultPanelAnchorPoint
        }

        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let screenRect = window.convertToScreen(buttonRectInWindow)

        guard targetFrame.width > 0, targetFrame.height > 0 else {
            return defaultPanelAnchorPoint
        }

        return CGPoint(
            x: (screenRect.midX - targetFrame.minX) / targetFrame.width,
            y: (screenRect.midY - targetFrame.minY) / targetFrame.height
        )
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

    @objc
    private func showSettings(_ sender: Any?) {
        hidePanel(animated: false)
        onShowSettings()
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
