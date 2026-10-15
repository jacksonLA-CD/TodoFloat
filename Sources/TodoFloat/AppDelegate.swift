import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotKey: HotKey?
    private let store = TodoStore()
    private lazy var panelController = FloatingPanelController(store: store)

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        // ⌘ ⇧ Space
        hotKey = HotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | shiftKey)) { [weak self] in
            self?.panelController.toggle()
        }
        if hotKey == nil {
            let alert = NSAlert()
            alert.messageText = "快捷键 ⌘⇧Space 注册失败"
            alert.informativeText = "可能已被其他应用占用。你仍然可以点击菜单栏图标打开待办。"
            alert.runModal()
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "待办")
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(withTitle: "打开待办  ⌘⇧Space", action: #selector(openPanel), keyEquivalent: "").target = self
        menu.addItem(withTitle: "在访达中显示数据文件", action: #selector(revealDataFile), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 TodoFloat", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func openPanel() {
        panelController.show()
    }

    @objc private func revealDataFile() {
        NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
    }
}
