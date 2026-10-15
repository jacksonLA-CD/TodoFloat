import AppKit
import Carbon.HIToolbox

/// 悬浮窗里的列表状态：当前选中哪一条、正在编辑哪一条，以及键盘操作。
final class TodoListModel: ObservableObject {
    let store: TodoStore
    @Published var selectedID: UUID?
    @Published var editingID: UUID?
    /// 每次面板弹出时递增，让输入框重新获得焦点。
    @Published private(set) var showCount = 0

    init(store: TodoStore) {
        self.store = store
    }

    var isEditing: Bool { editingID != nil }

    func resetForShow() {
        selectedID = nil
        editingID = nil
        showCount += 1
    }

    /// 处理键盘事件，返回 true 表示已处理，不再传给输入框。
    /// Esc 由面板自己处理（取消编辑或关闭面板）。
    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard !isEditing else { return false }
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let hasSelection = selectedID != nil

        switch Int(event.keyCode) {
        case kVK_DownArrow where flags.isEmpty:
            moveSelection(by: 1)
            return true
        case kVK_UpArrow where flags.isEmpty && hasSelection:
            moveSelection(by: -1)
            return true
        case kVK_Space where flags.isEmpty && hasSelection:
            toggleSelected()
            return true
        case kVK_Return where flags.isEmpty && hasSelection:
            editingID = selectedID
            return true
        case kVK_Delete where flags == .command && hasSelection:
            deleteSelected()
            return true
        case kVK_ANSI_1 where flags.isEmpty && hasSelection:
            setSelectedPriority(.high)
            return true
        case kVK_ANSI_2 where flags.isEmpty && hasSelection:
            setSelectedPriority(.medium)
            return true
        case kVK_ANSI_3 where flags.isEmpty && hasSelection:
            setSelectedPriority(.low)
            return true
        case kVK_ANSI_0 where flags.isEmpty && hasSelection:
            setSelectedPriority(.normal)
            return true
        default:
            return false
        }
    }

    /// 在列表里上下移动；从第一条再往上就回到输入框。
    func moveSelection(by offset: Int) {
        let items = store.sorted
        guard !items.isEmpty else { return }
        guard let current = items.firstIndex(where: { $0.id == selectedID }) else {
            if offset > 0 { selectedID = items[0].id }
            return
        }
        let next = current + offset
        if next < 0 {
            selectedID = nil
        } else if next < items.count {
            selectedID = items[next].id
        }
    }

    func beginEditing(_ todo: Todo) {
        selectedID = todo.id
        editingID = todo.id
    }

    func commitEdit(_ todo: Todo, text: String) {
        store.update(todo, from: text)
        editingID = nil
    }

    func cancelEditing() {
        editingID = nil
    }

    func clearCompleted() {
        store.clearCompleted()
        if !store.todos.contains(where: { $0.id == selectedID }) {
            selectedID = nil
        }
    }

    /// 完成或删除后，选中同一位置的下一条，方便连续操作。
    private func toggleSelected() {
        let items = store.sorted
        guard let index = items.firstIndex(where: { $0.id == selectedID }) else { return }
        store.toggle(items[index])
        selectItem(at: index)
    }

    private func deleteSelected() {
        let items = store.sorted
        guard let index = items.firstIndex(where: { $0.id == selectedID }) else { return }
        store.delete(items[index])
        selectItem(at: index)
    }

    /// 改优先级后这一条会换位置，选中状态跟着它走。
    private func setSelectedPriority(_ priority: Priority) {
        guard let todo = store.todos.first(where: { $0.id == selectedID }) else { return }
        store.setPriority(todo, to: priority)
    }

    private func selectItem(at index: Int) {
        let items = store.sorted
        selectedID = items.isEmpty ? nil : items[min(index, items.count - 1)].id
    }
}
