import Foundation

enum Priority: Int, Codable, Comparable, CaseIterable {
    case normal = 0, low, medium, high

    static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .normal: return "无"
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
}

/// 截止时间。hasTime 为 false 时只有日期，date 是当天 0 点，算到当天结束才过期。
struct Due: Equatable {
    var date: Date
    var hasTime: Bool

    /// 真正的截止时刻：没写时间的算到当天 23:59:59。
    func deadline(calendar: Calendar = .current) -> Date {
        guard !hasTime, let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) else {
            return date
        }
        return nextDay.addingTimeInterval(-1)
    }

    func isOverdue(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        deadline(calendar: calendar) < now
    }
}

struct Todo: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var done = false
    var createdAt = Date()
    var completedAt: Date?
    /// 截止时间；dueHasTime 为 false 时只用到日期，存的是当天 0 点。
    var dueDate: Date?
    var dueHasTime = false
    var priority: Priority = .normal

    var due: Due? {
        get { dueDate.map { Due(date: $0, hasTime: dueHasTime) } }
        set {
            dueDate = newValue?.date
            dueHasTime = newValue?.hasTime ?? false
        }
    }
}

extension Todo {
    /// 兼容旧版本的数据文件：没有 dueDate、dueHasTime、priority 字段时用默认值。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        done = try container.decode(Bool.self, forKey: .done)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        dueHasTime = try container.decodeIfPresent(Bool.self, forKey: .dueHasTime) ?? false
        priority = try container.decodeIfPresent(Priority.self, forKey: .priority) ?? .normal
    }
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

    /// 未完成的在前：先按优先级（高→无），再按截止时间（早→晚，没写时间的算当天结束，没有截止的排后面），
    /// 最后新添加的在上面。已完成的放在最后。
    var sorted: [Todo] {
        todos.filter { !$0.done }.sorted(by: Self.activeOrder) + todos.filter { $0.done }
    }

    private static func activeOrder(_ a: Todo, _ b: Todo) -> Bool {
        if a.priority != b.priority {
            return a.priority > b.priority
        }
        switch (a.due?.deadline(), b.due?.deadline()) {
        case let (x?, y?) where x != y:
            return x < y
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            return a.createdAt > b.createdAt
        }
    }

    var remainingCount: Int {
        todos.filter { !$0.done }.count
    }

    var doneCount: Int {
        todos.count - remainingCount
    }

    /// 输入里可以带 @日期 和 !/!!/!!!，见 QuickEntry。
    func add(_ input: String) {
        let entry = QuickEntry.parse(input)
        guard !entry.text.isEmpty else { return }
        var todo = Todo(text: entry.text, priority: entry.priority ?? .normal)
        todo.due = entry.due
        todos.insert(todo, at: 0)
        save()
    }

    func toggle(_ todo: Todo) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[index].done.toggle()
        todos[index].completedAt = todos[index].done ? Date() : nil
        save()
    }

    /// 编辑时文字、截止日期、优先级一起更新；去掉标记就是清除。文字为空时保留原来的内容。
    func update(_ todo: Todo, from input: String) {
        let entry = QuickEntry.parse(input)
        guard !entry.text.isEmpty, let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[index].text = entry.text
        todos[index].due = entry.due
        todos[index].priority = entry.priority ?? .normal
        save()
    }

    func setPriority(_ todo: Todo, to priority: Priority) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[index].priority = priority
        save()
    }

    func setDue(_ todo: Todo, to due: Due?) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[index].due = due
        save()
    }

    func delete(_ todo: Todo) {
        todos.removeAll { $0.id == todo.id }
        save()
    }

    func clearCompleted() {
        todos.removeAll { $0.done }
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
