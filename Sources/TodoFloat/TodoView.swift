import SwiftUI

struct TodoView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var model: TodoListModel
    @State private var input = ""
    @State private var confirmingClear = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                TextField("添加待办，按回车保存", text: $input)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .focused($inputFocused)
                    .onSubmit {
                        store.add(input)
                        input = ""
                    }
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
                                    onCommitEdit: { model.commitEdit(todo, text: $0) }
                                )
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .onChange(of: model.selectedID) { id in
                        guard let id else { return }
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
            return "空格 完成 · 回车 编辑 · ⌘⌫ 删除"
        } else {
            return "回车添加 · ↓ 选择 · Esc 关闭"
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
                        draft = todo.text
                        DispatchQueue.main.async { editorFocused = true }
                    }
            } else {
                Text(todo.text)
                    .font(.system(size: 15))
                    .strikethrough(todo.done)
                    .foregroundStyle(todo.done ? .secondary : .primary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, perform: onBeginEdit)
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
            Button("删除", action: onDelete)
        }
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
