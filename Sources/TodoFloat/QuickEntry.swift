import Foundation

/// 快速输入语法：在待办文字里用 @日期 设置截止时间，用 ! / !! / !!! 设置低 / 中 / 高优先级。
/// 标记要用空格和文字隔开，例如“交周报 @周五 !!”。全角的 ＠ ！ ： 也可以。
///
/// 时间可以直接接在日期后面（@明天15:00、@周五下午3点），也可以空一格（@明天 15:00），
/// 或者只写时间（@15:00、@下午3点：今天，如果已经过了就是明天）。
enum QuickEntry {
    struct Result: Equatable {
        var text: String
        var due: Due?
        var priority: Priority?
    }

    static func parse(_ input: String, now: Date = Date(), calendar: Calendar = .current) -> Result {
        var words: [String] = []
        var due: Due?
        var priority: Priority?
        // 上一个标记是只有日期的 @日期 时，紧跟着的时间（如“@明天 15:00”）算作它的时间
        var canAttachTime = false

        for token in input.split(whereSeparator: \.isWhitespace).map(String.init) {
            let attachTime = canAttachTime
            canAttachTime = false

            if let parsed = parsePriority(token) {
                priority = parsed
            } else if let first = token.first, first == "@" || first == "＠",
                      let parsed = parseDue(String(token.dropFirst()), now: now, calendar: calendar) {
                due = parsed
                canAttachTime = !parsed.hasTime
            } else if attachTime, let current = due, let time = parseTime(token),
                      let date = at(time, on: current.date, calendar: calendar) {
                due = Due(date: date, hasTime: true)
            } else {
                words.append(token)
            }
        }
        return Result(text: words.joined(separator: " "), due: due, priority: priority)
    }

    /// 编辑时显示的文字：把截止时间和优先级还原成标记，保存时再解析回来。
    static func editableText(for todo: Todo, now: Date = Date(), calendar: Calendar = .current) -> String {
        var parts = [todo.text]
        if let due = todo.due {
            parts.append("@" + dateToken(due.date, now: now, calendar: calendar))
            if due.hasTime {
                parts.append(timeText(due.date, calendar: calendar))
            }
        }
        if todo.priority != .normal {
            parts.append(String(repeating: "!", count: todo.priority.rawValue))
        }
        return parts.joined(separator: " ")
    }

    /// 列表里显示的截止时间：今天、明天 15:00、昨天、周五 09:30、10月20日、2027年1月3日。
    static func dueLabel(_ due: Due, now: Date = Date(), calendar: Calendar = .current) -> String {
        let day = dayLabel(due.date, now: now, calendar: calendar)
        return due.hasTime ? day + " " + timeText(due.date, calendar: calendar) : day
    }

    /// 负数表示在今天之前。
    static func daysFromToday(to date: Date, now: Date = Date(), calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: date)).day ?? 0
    }

    /// 只有日期的截止（右键菜单用）。
    static func dateOnlyDue(_ text: String, now: Date = Date(), calendar: Calendar = .current) -> Due? {
        parseDate(text, now: now, calendar: calendar).map { Due(date: $0, hasTime: false) }
    }

    // MARK: - 显示

    private static let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    private static func dayLabel(_ date: Date, now: Date, calendar: Calendar) -> String {
        switch daysFromToday(to: date, now: now, calendar: calendar) {
        case 0: return "今天"
        case 1: return "明天"
        case -1: return "昨天"
        case 2...6: return weekdayNames[calendar.component(.weekday, from: date) - 1]
        default:
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            let sameYear = parts.year == calendar.component(.year, from: now)
            let monthDay = "\(parts.month!)月\(parts.day!)日"
            return sameYear ? monthDay : "\(parts.year!)年" + monthDay
        }
    }

    private static func timeText(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour!, parts.minute!)
    }

    /// 今年且还没过的日期写成 10-20，否则写全 2027-1-3，保证再解析回来是同一天。
    private static func dateToken(_ date: Date, now: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let sameYear = parts.year == calendar.component(.year, from: now)
        let notPast = calendar.startOfDay(for: date) >= calendar.startOfDay(for: now)
        let monthDay = "\(parts.month!)-\(parts.day!)"
        return sameYear && notPast ? monthDay : "\(parts.year!)-" + monthDay
    }

    // MARK: - 解析截止时间

    /// 日期、日期+时间、或者只有时间。
    static func parseDue(_ raw: String, now: Date = Date(), calendar: Calendar = .current) -> Due? {
        if let date = parseDate(raw, now: now, calendar: calendar) {
            return Due(date: date, hasTime: false)
        }
        // 日期在前、时间在后。从最长的日期开始试，这样“10-203点”是 10-20 的 3 点，而不是 10-2 的 03 点。
        let chars = Array(raw)
        for split in stride(from: chars.count - 1, through: 0, by: -1) {
            guard let time = parseTime(String(chars[split...])) else { continue }
            if split == 0 {
                // 只有时间：今天这个时间；如果已经过了，就是明天
                let today = calendar.startOfDay(for: now)
                guard let todayAt = at(time, on: today, calendar: calendar) else { return nil }
                if todayAt > now { return Due(date: todayAt, hasTime: true) }
                guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
                      let tomorrowAt = at(time, on: tomorrow, calendar: calendar) else { return nil }
                return Due(date: tomorrowAt, hasTime: true)
            }
            if let day = parseDate(String(chars[..<split]), now: now, calendar: calendar),
               let date = at(time, on: day, calendar: calendar) {
                return Due(date: date, hasTime: true)
            }
        }
        return nil
    }

    private static func at(_ time: (hour: Int, minute: Int), on day: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: calendar.startOfDay(for: day))
    }

    // MARK: - 解析时间

    private enum Period {
        case morning    // 凌晨、早上、上午、am：12 点算 0 点
        case noon       // 中午：1 点算 13 点
        case afternoon  // 下午、晚上、pm：加 12 小时
    }

    /// 长的写在前面，避免“早上”被当成“早”。
    private static let periodPrefixes: [(String, Period)] = [
        ("凌晨", .morning), ("早上", .morning), ("上午", .morning), ("早", .morning),
        ("中午", .noon),
        ("下午", .afternoon), ("傍晚", .afternoon), ("晚上", .afternoon), ("晚", .afternoon),
    ]

    /// 15:00、9:30、15点、15点30、15点30分、3点半、下午3点、晚上8点半、3pm、9:30am。
    /// 小时最多两位数；单独一个数字（如“15”）不算时间，必须带 : 、点、上下午或 am/pm。
    static func parseTime(_ raw: String) -> (hour: Int, minute: Int)? {
        var s = Substring(raw.lowercased().replacingOccurrences(of: "：", with: ":"))
        var period: Period?

        for (prefix, value) in periodPrefixes where s.hasPrefix(prefix) {
            period = value
            s = s.dropFirst(prefix.count)
            break
        }
        if period == nil {
            if s.hasSuffix("am") {
                period = .morning
                s = s.dropLast(2)
            } else if s.hasSuffix("pm") {
                period = .afternoon
                s = s.dropLast(2)
            }
        }

        var hour: Int
        var minute = 0
        if let colon = s.firstIndex(of: ":") {
            let h = s[..<colon], m = s[s.index(after: colon)...]
            guard isNumber(h, digits: 1...2), isNumber(m, digits: 2...2) else { return nil }
            hour = Int(h)!
            minute = Int(m)!
        } else if let dot = s.firstIndex(where: { $0 == "点" || $0 == "時" || $0 == "时" }) {
            let h = s[..<dot]
            var m = s[s.index(after: dot)...]
            guard isNumber(h, digits: 1...2) else { return nil }
            hour = Int(h)!
            if m == "半" {
                minute = 30
            } else if !m.isEmpty {
                if m.hasSuffix("分") { m = m.dropLast() }
                guard isNumber(m, digits: 1...2) else { return nil }
                minute = Int(m)!
            }
        } else {
            // 没有 : 或“点”时，必须有上下午或 am/pm，比如“3pm”“下午3”
            guard period != nil, isNumber(s, digits: 1...2) else { return nil }
            hour = Int(s)!
        }

        switch period {
        case .morning:
            if hour == 12 { hour = 0 }
        case .noon:
            if hour < 11 { hour += 12 }
        case .afternoon:
            if hour < 12 { hour += 12 }
        case nil:
            break
        }
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return (hour, minute)
    }

    private static func isNumber(_ s: Substring, digits: ClosedRange<Int>) -> Bool {
        digits.contains(s.count) && s.allSatisfy(\.isASCII) && s.allSatisfy(\.isNumber)
    }

    // MARK: - 解析日期

    /// Calendar 的 weekday：1 是周日，2 是周一……7 是周六。
    private static let weekdayByName: [String: Int] = [
        "一": 2, "二": 3, "三": 4, "四": 5, "五": 6, "六": 7, "日": 1, "天": 1,
        "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7, "sun": 1,
    ]

    private static func parsePriority(_ token: String) -> Priority? {
        guard (1...3).contains(token.count), token.allSatisfy({ $0 == "!" || $0 == "！" }) else { return nil }
        return Priority(rawValue: token.count)
    }

    /// 只解析日期，返回当天 0 点。
    static func parseDate(_ raw: String, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: now)
        let s = raw.lowercased()
        func daysLater(_ n: Int) -> Date? { calendar.date(byAdding: .day, value: n, to: today) }

        switch s {
        case "今天", "今", "today": return today
        case "明天", "明", "tomorrow": return daysLater(1)
        case "后天": return daysLater(2)
        case "大后天": return daysLater(3)
        default: break
        }

        // 3天后、+3
        if s.hasSuffix("天后"), let n = Int(s.dropLast(2)) { return daysLater(n) }
        if s.hasPrefix("+"), let n = Int(s.dropFirst()) { return daysLater(n) }

        if let date = parseWeekday(s, today: today, calendar: calendar) { return date }
        return parseCalendarDate(s, today: today, calendar: calendar)
    }

    /// 周五 / 星期五 / 礼拜五 / fri：今天或之后最近的那一天。
    /// 下周五 / 下星期五：下一个自然周（周一开始）里的那一天。
    private static func parseWeekday(_ s: String, today: Date, calendar: Calendar) -> Date? {
        var rest = Substring(s)
        var nextWeek = false
        if rest.hasPrefix("下") {
            nextWeek = true
            rest = rest.dropFirst()
        }
        var hadPrefix = false
        for prefix in ["星期", "礼拜", "周"] where rest.hasPrefix(prefix) {
            rest = rest.dropFirst(prefix.count)
            hadPrefix = true
            break
        }
        let isEnglish = rest.count == 3 && rest.allSatisfy(\.isASCII)
        guard hadPrefix || (isEnglish && !nextWeek), let target = weekdayByName[String(rest)] else { return nil }

        let todayWeekday = calendar.component(.weekday, from: today)
        if nextWeek {
            // 以周一为一周的第一天：0 = 周一 … 6 = 周日
            let todayIndex = (todayWeekday + 5) % 7
            let targetIndex = (target + 5) % 7
            return calendar.date(byAdding: .day, value: 7 - todayIndex + targetIndex, to: today)
        }
        return calendar.date(byAdding: .day, value: (target - todayWeekday + 7) % 7, to: today)
    }

    /// 2026-10-20、10-20、10/20、10.20、10月20日、10月20号。
    /// 没写年份时用今年；如果这一天已经过去，就算明年。
    private static func parseCalendarDate(_ s: String, today: Date, calendar: Calendar) -> Date? {
        var body = s
        if body.hasSuffix("日") || body.hasSuffix("号") { body.removeLast() }
        let numbers = body
            .split(whereSeparator: { "-/.月年".contains($0) })
            .map { Int($0) }
        guard numbers.count == 2 || numbers.count == 3, numbers.allSatisfy({ $0 != nil }) else { return nil }
        let values = numbers.map { $0! }

        if values.count == 3 {
            return makeDate(year: values[0], month: values[1], day: values[2], calendar: calendar)
        }
        let thisYear = calendar.component(.year, from: today)
        guard let date = makeDate(year: thisYear, month: values[0], day: values[1], calendar: calendar) else { return nil }
        return date < today
            ? makeDate(year: thisYear + 1, month: values[0], day: values[1], calendar: calendar)
            : date
    }

    private static func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        // 排除 2-30 这种会被自动顺延到下个月的日期
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == year, check.month == month, check.day == day else { return nil }
        return date
    }
}
