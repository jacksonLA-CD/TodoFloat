import AppKit
import Carbon.HIToolbox
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var hotKey: HotKey?
    private var launchAtLoginItem: NSMenuItem?
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
        let launchItem = menu.addItem(withTitle: "开机自动启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchAtLoginItem = launchItem
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 TodoFloat", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    @objc private func openPanel() {
        panelController.show()
    }

    @objc private func revealDataFile() {
        NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
    }

    // 每次打开菜单时刷新“开机自动启动”的勾选状态（用户也可能在系统设置里改过）
    func menuNeedsUpdate(_ menu: NSMenu) {
        launchAtLoginItem?.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "无法更改开机自动启动设置"
            alert.informativeText = error.localizedDescription
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }
        // 需要在“系统设置 > 通用 > 登录项”里允许
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
