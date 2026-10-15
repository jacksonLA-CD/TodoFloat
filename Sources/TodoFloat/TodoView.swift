import SwiftUI

struct TodoView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var model: TodoListModel
    @State private var input = ""
    @State private var confirmingClear = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                    TextField("添加待办，例如：交周报 @周五 !!", text: $input)
                        .textFieldStyle(.plain)
                        .font(.system(size: 20))
                        .focused($inputFocused)
                        .onSubmit {
                            store.add(input)
                            input = ""
                        }
                }
                inputPreview
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)

            Divider()

            if store.todos.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32))
                    Text("还没有待办，输入一条试试")
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.sorted) { todo in
                                TodoRow(
                                    todo: todo,
                                    isSelected: model.selectedID == todo.id,
                                    isEditing: model.editingID == todo.id,
                                    onToggle: { store.toggle(todo) },
                                    onDelete: { store.delete(todo) },
                                    onBeginEdit: { model.beginEditing(todo) },
                                    onCommitEdit: { model.commitEdit(todo, text: $0) },
                                    onSetPriority: { store.setPriority(todo, to: $0) },
                                    onSetDue: { store.setDue(todo, to: $0) }
                                )
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onChange(of: model.selectedID) { id in
                        guard let id else { return }
                        proxy.scrollTo(id)
                    }
                    // 改优先级等操作会让选中的这一条换位置
                    .onChange(of: store.todos) { _ in
                        guard let id = model.selectedID else { return }
                        proxy.scrollTo(id)
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                Text("\(store.remainingCount) 项未完成")
                if store.doneCount > 0 {
                    Button(confirmingClear ? "确认清除 \(store.doneCount) 项已完成？" : "清除已完成") {
                        clearCompletedTapped()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(confirmingClear ? Color.red : Color.accentColor)
                }
                Spacer()
                Text(hint)
                    .lineLimit(1)
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .frame(width: FloatingPanelController.size.width, height: FloatingPanelController.size.height)
        .onAppear { inputFocused = true }
        .onChange(of: model.showCount) { _ in
            input = ""
            confirmingClear = false
            DispatchQueue.main.async { inputFocused = true }
        }
        // 选中列表里的某一条时，输入框让出焦点，空格等按键用来操作列表
        .onChange(of: model.selectedID) { id in
            if id != nil {
                inputFocused = false
            } else if !model.isEditing {
                inputFocused = true
            }
        }
        // 点回输入框时，退出列表选择和编辑
        .onChange(of: inputFocused) { focused in
            if focused {
                model.selectedID = nil
                model.editingID = nil
            }
        }
    }

    private var hint: String {
        if model.isEditing {
            return "回车保存 · Esc 取消"
        } else if model.selectedID != nil {
            return "空格 完成 · 回车 编辑 · 1/2/3 优先级 · ⌘⌫ 删除"
        } else {
            return "回车添加 · ↓ 选择 · Esc 关闭"
        }
    }

    /// 输入里识别到 @日期 或 ! 时，在输入框下面显示出来，确认解析对了。
    @ViewBuilder
    private var inputPreview: some View {
        let entry = QuickEntry.parse(input)
        if entry.due != nil || entry.priority != nil {
            HStack(spacing: 12) {
                if let due = entry.due {
                    Label("截止：" + QuickEntry.dueLabel(due), systemImage: due.hasTime ? "clock" : "calendar")
                }
                if let priority = entry.priority {
                    Label("优先级：" + priority.label, systemImage: "flag.fill")
                        .foregroundStyle(priority.color)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.leading, 30)
        }
    }

    /// 第一次点击变成“确认”，3 秒内再点一次才真正清除。
    private func clearCompletedTapped() {
        if confirmingClear {
            model.clearCompleted()
            confirmingClear = false
        } else {
            confirmingClear = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                confirmingClear = false
            }
        }
    }
}

struct TodoRow: View {
    let todo: Todo
    let isSelected: Bool
    let isEditing: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onBeginEdit: () -> Void
    let onCommitEdit: (String) -> Void
    let onSetPriority: (Priority) -> Void
    let onSetDue: (Due?) -> Void
    @State private var hovering = false
    @State private var draft = ""
    @FocusState private var editorFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17))
                    .foregroundStyle(todo.done ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)

            if isEditing {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($editorFocused)
                    .onSubmit { onCommitEdit(draft) }
                    .onAppear {
                        draft = QuickEntry.editableText(for: todo)
                        DispatchQueue.main.async { editorFocused = true }
                    }
            } else {
                if todo.priority != .normal {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(todo.priority.color)
                        .opacity(todo.done ? 0.4 : 1)
                        .help("优先级：" + todo.priority.label)
                }
                Text(todo.text)
                    .font(.system(size: 15))
                    .strikethrough(todo.done)
                    .foregroundStyle(todo.done ? .secondary : .primary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, perform: onBeginEdit)
                if let due = todo.due {
                    dueLabel(due)
                }
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(hovering && !isEditing ? 1 : 0)
            .help("删除")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            Button(todo.done ? "标记为未完成" : "标记为完成", action: onToggle)
            Button("编辑", action: onBeginEdit)
            Menu("优先级") {
                ForEach(Priority.allCases.reversed(), id: \.self) { priority in
                    Button(priority.label) { onSetPriority(priority) }
                }
            }
            Menu("截止日期") {
                Button("今天") { onSetDue(QuickEntry.dateOnlyDue("今天")) }
                Button("明天") { onSetDue(QuickEntry.dateOnlyDue("明天")) }
                Button("下周一") { onSetDue(QuickEntry.dateOnlyDue("下周一")) }
                Divider()
                Text("要精确到时间，请按回车编辑，例如 @明天 15:00")
                if todo.due != nil {
                    Divider()
                    Button("清除截止日期") { onSetDue(nil) }
                }
            }
            Divider()
            Button("删除", action: onDelete)
        }
    }

    /// 已过期红色（带时间的过了那个时刻就算），今天到期橙色，其他灰色；已完成的都是灰色。
    private func dueLabel(_ due: Due) -> some View {
        let overdue = due.isOverdue()
        let today = QuickEntry.daysFromToday(to: due.date) == 0
        let color: Color = todo.done ? .secondary : overdue ? .red : today ? .orange : .secondary
        return Label(QuickEntry.dueLabel(due), systemImage: due.hasTime ? "clock" : "calendar")
            .font(.system(size: 12))
            .foregroundStyle(color)
            .help(overdue && !todo.done ? "已过期" : "截止时间")
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.18)
        } else if hovering {
            return Color.primary.opacity(0.06)
        } else {
            return Color.clear
        }
    }
}

extension Priority {
    var color: Color {
        switch self {
        case .normal: return .secondary
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
}
