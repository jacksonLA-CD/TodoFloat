import Foundation

struct Todo: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var done = false
    var createdAt = Date()
    var completedAt: Date?
}

/// 待办数据，保存在 ~/Library/Application Support/TodoFloat/todos.json
final class TodoStore: ObservableObject {
    @Published private(set) var todos: [Todo] = []
    let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TodoFloat", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("todos.json")
        load()
    }

    /// 未完成的在前（最新的在最上面），已完成的在后。
    var sorted: [Todo] {
        todos.filter { !$0.done } + todos.filter { $0.done }
    }

    var remainingCount: Int {
        todos.filter { !$0.done }.count
    }

    func add(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        todos.insert(Todo(text: trimmed), at: 0)
        save()
    }

    func toggle(_ todo: Todo) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[index].done.toggle()
        todos[index].completedAt = todos[index].done ? Date() : nil
        save()
    }

    func delete(_ todo: Todo) {
        todos.removeAll { $0.id == todo.id }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            todos = try Self.decoder.decode([Todo].self, from: data)
        } catch {
            // 文件损坏时先备份，避免下次保存把它覆盖掉
            let backup = fileURL.deletingPathExtension()
                .appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            NSLog("TodoFloat: 无法读取 todos.json，已备份到 \(backup.path)：\(error)")
        }
    }

    private func save() {
        do {
            let data = try Self.encoder.encode(todos)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("TodoFloat: 保存失败：\(error)")
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
