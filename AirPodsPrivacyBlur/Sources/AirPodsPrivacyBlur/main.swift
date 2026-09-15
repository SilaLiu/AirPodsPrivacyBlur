import AppKit
import CoreMotion
import Foundation

func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let blurOverlay = PrivacyBlurOverlay()
    private let headPoseMonitor = HeadPoseMonitor()
    private let preferences = Preferences()
    private var controlWindow: NSWindow?

    private let statusMenu = NSMenu()
    private let statusItemLabel = NSMenuItem(title: L("status.starting"), action: nil, keyEquivalent: "")
    private let angleItem = NSMenuItem(title: L("angle.empty"), action: nil, keyEquivalent: "")
    private let enabledItem = NSMenuItem(title: L("menu.protection.enabled"), action: #selector(toggleEnabled), keyEquivalent: "")
    private let showWindowItem = NSMenuItem(title: L("menu.show.window"), action: #selector(showControlWindowAction), keyEquivalent: "")
    private let trackingItem = NSMenuItem(title: L("menu.tracking.start"), action: #selector(toggleTracking), keyEquivalent: "")
    private let calibrateItem = NSMenuItem(title: L("menu.calibrate"), action: #selector(calibrate), keyEquivalent: "")
    private let testBlurItem = NSMenuItem(title: L("menu.test.blur"), action: #selector(testBlur), keyEquivalent: "")
    private let sensitivityItem = NSMenuItem(title: String(format: L("menu.sensitivity.current"), Sensitivity.medium.title), action: nil, keyEquivalent: "")
    private var testBlurTimer: Timer?
    private var isTracking = false
    private var trackingButton: NSButton?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("AirPodsPrivacyBlur did finish launching")
        NSApp.setActivationPolicy(.regular)
        configureStatusMenu()
        configureMotionCallbacks()
        showControlWindow()
        statusItemLabel.title = L("status.ready")
        NSLog("AirPodsPrivacyBlur control window requested")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showControlWindow()
        return true
    }

    private func configureStatusMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = L("app.menu.title")
        statusItem.button?.toolTip = L("app.name")
        if let logo = loadLogoImage(size: NSSize(width: 18, height: 18)) {
            statusItem.button?.image = logo
            statusItem.button?.imagePosition = .imageLeading
        }

        statusItemLabel.isEnabled = false
        angleItem.isEnabled = false
        sensitivityItem.isEnabled = false
        enabledItem.target = self
        showWindowItem.target = self
        trackingItem.target = self
        calibrateItem.target = self
        testBlurItem.target = self
        enabledItem.state = preferences.isEnabled ? .on : .off

        statusMenu.addItem(statusItemLabel)
        statusMenu.addItem(angleItem)
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(enabledItem)
        statusMenu.addItem(showWindowItem)
        statusMenu.addItem(trackingItem)
        statusMenu.addItem(calibrateItem)
        statusMenu.addItem(testBlurItem)
        statusMenu.addItem(sensitivityItem)
        statusMenu.addItem(makeSensitivitySubmenu())
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: L("menu.quit"), action: #selector(quit), keyEquivalent: "q"))
        statusMenu.items.last?.target = self

        statusItem.menu = statusMenu
        updateSensitivityTitle()
    }

    private func makeSensitivitySubmenu() -> NSMenuItem {
        let root = NSMenuItem(title: L("menu.sensitivity.set"), action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        for level in Sensitivity.allCases {
            let item = NSMenuItem(title: level.title, action: #selector(selectSensitivity(_:)), keyEquivalent: "")
            item.representedObject = level.rawValue
            item.target = self
            item.state = preferences.sensitivity == level ? .on : .off
            submenu.addItem(item)
        }

        root.submenu = submenu
        return root
    }

    private func configureMotionCallbacks() {
        headPoseMonitor.onStateChange = { [weak self] state in
            self?.render(state)
        }
    }

    private func render(_ state: HeadPoseState) {
        statusItemLabel.title = state.statusText

        if let degrees = state.yawDegrees {
            angleItem.title = String(format: L("angle.value"), degrees)
        } else {
            angleItem.title = L("angle.empty")
        }

        guard preferences.isEnabled else {
            blurOverlay.hide()
            statusItem.button?.title = L("app.menu.title")
            return
        }

        if state.shouldBlur {
            blurOverlay.show()
            statusItem.button?.title = L("statusItem.blurred")
        } else {
            blurOverlay.hide()
            statusItem.button?.title = L("app.menu.title")
        }
    }

    @objc private func toggleEnabled() {
        preferences.isEnabled.toggle()
        enabledItem.state = preferences.isEnabled ? .on : .off
        if !preferences.isEnabled {
            blurOverlay.hide()
        }
    }

    @objc private func showControlWindowAction() {
        showControlWindow()
    }

    @objc private func toggleTracking() {
        if isTracking {
            headPoseMonitor.stop()
            isTracking = false
            trackingItem.title = L("menu.tracking.start")
            trackingButton?.title = L("menu.tracking.start")
            statusItemLabel.title = L("status.tracking.stopped")
            return
        }

        isTracking = true
        trackingItem.title = L("menu.tracking.stop")
        trackingButton?.title = L("menu.tracking.stop")
        statusItemLabel.title = L("status.tracking.starting")
        headPoseMonitor.start()
    }

    @objc private func calibrate() {
        headPoseMonitor.calibrateFacingScreen()
    }

    @objc private func testBlur() {
        testBlurTimer?.invalidate()
        blurOverlay.show()
        statusItem.button?.title = L("statusItem.blurred")
        testBlurTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.blurOverlay.hide()
                self?.statusItem.button?.title = L("app.menu.title")
            }
        }
    }

    @objc private func selectSensitivity(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let sensitivity = Sensitivity(rawValue: rawValue)
        else {
            return
        }

        preferences.sensitivity = sensitivity
        headPoseMonitor.updateThresholds(sensitivity.thresholds)
        updateSensitivityTitle()

        statusMenu.items
            .compactMap(\.submenu)
            .flatMap(\.items)
            .forEach { item in
                item.state = (item.representedObject as? String) == rawValue ? .on : .off
            }
    }

    private func updateSensitivityTitle() {
        sensitivityItem.title = String(format: L("menu.sensitivity.current"), preferences.sensitivity.title)
        headPoseMonitor.updateThresholds(preferences.sensitivity.thresholds)
    }

    @objc private func quit() {
        headPoseMonitor.stop()
        NSApp.terminate(nil)
    }

    private func showControlWindow() {
        if let controlWindow {
            controlWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 230),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = L("window.title")
        if let logo = loadLogoImage(size: NSSize(width: 128, height: 128)) {
            NSApp.applicationIconImage = logo
        }
        window.level = .floating
        window.center()
        window.isReleasedWhenClosed = false

        let titleLabel = NSTextField(labelWithString: L("window.heading"))
        titleLabel.font = .boldSystemFont(ofSize: 17)

        let headerRow: NSStackView
        if let logo = loadLogoImage(size: NSSize(width: 56, height: 56)) {
            let logoView = NSImageView(image: logo)
            logoView.imageScaling = .scaleProportionallyUpOrDown
            logoView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                logoView.widthAnchor.constraint(equalToConstant: 56),
                logoView.heightAnchor.constraint(equalToConstant: 56)
            ])

            headerRow = NSStackView(views: [logoView, titleLabel])
            headerRow.orientation = .horizontal
            headerRow.alignment = .centerY
            headerRow.spacing = 14
        } else {
            headerRow = NSStackView(views: [titleLabel])
            headerRow.orientation = .horizontal
            headerRow.alignment = .centerY
        }

        let bodyLabel = NSTextField(wrappingLabelWithString: L("window.body"))
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.maximumNumberOfLines = 3

        let trackingButton = NSButton(title: L("menu.tracking.start"), target: self, action: #selector(toggleTracking))
        trackingButton.bezelStyle = .rounded
        self.trackingButton = trackingButton

        let testButton = NSButton(title: L("menu.test.blur"), target: self, action: #selector(testBlur))
        testButton.bezelStyle = .rounded

        let calibrateButton = NSButton(title: L("menu.calibrate"), target: self, action: #selector(calibrate))
        calibrateButton.bezelStyle = .rounded

        let quitButton = NSButton(title: L("menu.quit"), target: self, action: #selector(quit))
        quitButton.bezelStyle = .rounded

        let buttonRow = NSStackView(views: [trackingButton, testButton, calibrateButton, quitButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10
        buttonRow.distribution = .fillEqually

        let stack = NSStackView(views: [headerRow, bodyLabel, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 32),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -24)
        ])

        controlWindow = window
        window.contentView = container
        DispatchQueue.main.async {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func loadLogoImage(size: NSSize) -> NSImage? {
        let path = Bundle.main.path(forResource: "logo-rounded", ofType: "png")
            ?? Bundle.main.path(forResource: "logo", ofType: "png")

        guard let path, let image = NSImage(contentsOfFile: path) else {
            return nil
        }

        image.size = size
        return image
    }
}

@MainActor
final class HeadPoseMonitor {
    var onStateChange: (@MainActor (HeadPoseState) -> Void)?

    private var manager: CMHeadphoneMotionManager?
    private var baselineYaw: Double?
    private var isBlurred = false
    private var blurEnterThreshold = Sensitivity.medium.thresholds.enter
    private var blurExitThreshold = Sensitivity.medium.thresholds.exit
    private var latestMotion: CMDeviceMotion?

    func start() {
        let manager = CMHeadphoneMotionManager()
        self.manager = manager

        guard manager.isDeviceMotionAvailable else {
            onStateChange?(HeadPoseState(statusText: L("status.motion.unavailable"), yawDegrees: nil, shouldBlur: false))
            return
        }

        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self else { return }

            if let error {
                self.onStateChange?(HeadPoseState(statusText: error.localizedDescription, yawDegrees: nil, shouldBlur: false))
                return
            }

            guard let motion else {
                self.onStateChange?(HeadPoseState(statusText: L("status.motion.waiting"), yawDegrees: nil, shouldBlur: false))
                return
            }

            self.latestMotion = motion
            self.process(motion)
        }
    }

    func stop() {
        manager?.stopDeviceMotionUpdates()
        manager = nil
        isBlurred = false
    }

    func calibrateFacingScreen() {
        guard let motion = latestMotion else {
            baselineYaw = nil
            onStateChange?(HeadPoseState(statusText: L("status.motion.calibrate.first"), yawDegrees: nil, shouldBlur: false))
            return
        }

        baselineYaw = motion.attitude.yaw
        isBlurred = false
        process(motion)
    }

    func updateThresholds(_ thresholds: BlurThresholds) {
        blurEnterThreshold = thresholds.enter
        blurExitThreshold = thresholds.exit
    }

    private func process(_ motion: CMDeviceMotion) {
        if baselineYaw == nil {
            baselineYaw = motion.attitude.yaw
        }

        let yawOffset = normalizedAngle(motion.attitude.yaw - (baselineYaw ?? motion.attitude.yaw))
        let yawDegrees = radiansToDegrees(yawOffset)
        let absoluteYaw = abs(yawDegrees)

        if isBlurred {
            isBlurred = absoluteYaw > blurExitThreshold
        } else {
            isBlurred = absoluteYaw >= blurEnterThreshold
        }

        let status = String(format: L("status.facing.baseline"), yawDegrees)
        onStateChange?(HeadPoseState(statusText: status, yawDegrees: yawDegrees, shouldBlur: isBlurred))
    }

    private func normalizedAngle(_ angle: Double) -> Double {
        var result = angle
        while result > .pi {
            result -= 2 * .pi
        }
        while result < -.pi {
            result += 2 * .pi
        }
        return result
    }

    private func radiansToDegrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }
}

struct HeadPoseState {
    let statusText: String
    let yawDegrees: Double?
    let shouldBlur: Bool
}

@MainActor
final class PrivacyBlurOverlay {
    private var panels: [NSPanel] = []
    private var isShowing = false
    private var isFadingOut = false
    private let fadeInDuration: TimeInterval = 0.22
    private let fadeOutDuration: TimeInterval = 0.34

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func show() {
        isShowing = true
        isFadingOut = false
        if !panels.isEmpty {
            animatePanels(to: 1, duration: fadeInDuration)
            return
        }

        panels = NSScreen.screens.map { screen in
            let screenFrame = screen.frame
            let localBounds = NSRect(origin: .zero, size: screenFrame.size)
            let panel = NSPanel(
                contentRect: screenFrame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
                screen: screen
            )

            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.alphaValue = 0
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.setFrame(screenFrame, display: true)

            let container = NSView(frame: localBounds)
            container.autoresizingMask = [.width, .height]

            let blurView = NSVisualEffectView(frame: localBounds)
            blurView.autoresizingMask = [.width, .height]
            blurView.blendingMode = .behindWindow
            blurView.material = .hudWindow
            blurView.state = .active

            let dimView = NSView(frame: localBounds)
            dimView.autoresizingMask = [.width, .height]
            dimView.wantsLayer = true
            dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.38).cgColor

            let label = NSTextField(labelWithString: L("overlay.active"))
            label.font = .boldSystemFont(ofSize: 32)
            label.textColor = .white
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false

            container.addSubview(blurView)
            container.addSubview(dimView)
            container.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
            panel.contentView = container
            panel.orderFrontRegardless()

            return panel
        }

        animatePanels(to: 1, duration: fadeInDuration)
    }

    func hide() {
        isShowing = false
        let panelsToHide = panels
        guard !panelsToHide.isEmpty, !isFadingOut else { return }
        isFadingOut = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeOutDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panelsToHide.forEach { panel in
                panel.animator().alphaValue = 0
            }
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.isFadingOut = false
                if !self.isShowing {
                    self.removePanels()
                }
            }
        }
    }

    private func removePanels() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }

    private func animatePanels(to alphaValue: CGFloat, duration: TimeInterval) {
        let panelsToAnimate = panels
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panelsToAnimate.forEach { panel in
                panel.animator().alphaValue = alphaValue
            }
        }
    }

    @objc private func screenParametersDidChange() {
        guard isShowing else { return }
        removePanels()
        show()
    }
}

final class Preferences {
    private enum Keys {
        static let isEnabled = "isEnabled"
        static let sensitivity = "sensitivity"
    }

    var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.isEnabled) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.isEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.isEnabled)
        }
    }

    var sensitivity: Sensitivity {
        get {
            guard
                let rawValue = UserDefaults.standard.string(forKey: Keys.sensitivity),
                let value = Sensitivity(rawValue: rawValue)
            else {
                return .medium
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.sensitivity)
        }
    }
}

enum Sensitivity: String, CaseIterable {
    case high
    case medium
    case low

    var title: String {
        switch self {
        case .high:
            L("sensitivity.high")
        case .medium:
            L("sensitivity.medium")
        case .low:
            L("sensitivity.low")
        }
    }

    var thresholds: BlurThresholds {
        switch self {
        case .high:
            BlurThresholds(enter: 14, exit: 8)
        case .medium:
            BlurThresholds(enter: 20, exit: 12)
        case .low:
            BlurThresholds(enter: 28, exit: 18)
        }
    }
}

struct BlurThresholds {
    let enter: Double
    let exit: Double
}

let application = NSApplication.shared
let applicationDelegate = AppDelegate()
application.delegate = applicationDelegate
application.run()
