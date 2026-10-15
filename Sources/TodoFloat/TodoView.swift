import SwiftUI

struct TodoView: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var panelState: PanelState
    @State private var input = ""
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
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.sorted) { todo in
                            TodoRow(
                                todo: todo,
                                onToggle: { store.toggle(todo) },
                                onDelete: { store.delete(todo) }
                            )
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            Divider()

            HStack {
                Text("\(store.remainingCount) 项未完成")
                Spacer()
                Text("回车添加 · Esc 关闭")
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .frame(width: FloatingPanelController.size.width, height: FloatingPanelController.size.height)
        .onAppear { inputFocused = true }
        .onChange(of: panelState.showCount) { _ in
            DispatchQueue.main.async { inputFocused = true }
        }
    }
}

struct TodoRow: View {
    let todo: Todo
    let onToggle: () -> Void
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17))
                    .foregroundStyle(todo.done ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)

            Text(todo.text)
                .font(.system(size: 15))
                .strikethrough(todo.done)
                .foregroundStyle(todo.done ? .secondary : .primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(hovering ? 1 : 0)
            .help("删除")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(hovering ? Color.primary.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            Button(todo.done ? "标记为未完成" : "标记为完成", action: onToggle)
            Button("删除", action: onDelete)
        }
    }
}
