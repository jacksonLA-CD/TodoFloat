import AppKit
import Carbon.HIToolbox
import SwiftUI

/// 无边框、置顶、可以接收键盘输入的悬浮面板。
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class FloatingPanelController: NSObject, NSWindowDelegate {
    static let size = NSSize(width: 560, height: 420)

    private let panel: FloatingPanel
    private let model: TodoListModel
    private var keyMonitor: Any?

    init(store: TodoStore) {
        model = TodoListModel(store: store)
        panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: Self.size))
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.maskImage = Self.roundedMask(radius: 14)
        background.autoresizingMask = [.width, .height]

        let hosting = NSHostingView(rootView: TodoView(store: store, model: model))
        hosting.frame = background.bounds
        hosting.autoresizingMask = [.width, .height]
        background.addSubview(hosting)
        panel.contentView = background

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyDown(event)
        }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        positionOnActiveScreen()
        NSApp.unhide(nil)
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
        model.resetForShow()
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        // 把焦点还给之前的应用
        NSApp.hide(nil)
    }

    /// 返回 nil 表示事件已处理。
    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard panel.isKeyWindow else { return event }
        // 输入法正在拼写（比如拼音候选框打开）时，按键全部交给输入法
        if let textView = panel.firstResponder as? NSTextView, textView.hasMarkedText() {
            return event
        }
        if Int(event.keyCode) == kVK_Escape {
            if model.isEditing {
                model.cancelEditing()
            } else {
                hide()
            }
            return nil
        }
        return model.handleKeyDown(event) ? nil : event
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    /// 放在鼠标所在屏幕的中上方，和 Spotlight 类似。
    private func positionOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let x = visible.midX - Self.size.width / 2
        let y = visible.maxY - visible.height * 0.18 - Self.size.height
        panel.setFrame(NSRect(x: x, y: y, width: Self.size.width, height: Self.size.height), display: false)
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
