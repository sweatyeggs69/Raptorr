import Foundation

/// A person's birth and death dates, each as precise as Wikidata knows it.
nonisolated struct LifeDates: Sendable, Equatable {
    var born: DateComponents?
    var died: DateComponents?

    /// "Born January 17, 1962 (age 64)", or with a death "Born ... · Died ... (aged 59)".
    func text(now: Date = .now, calendar: Calendar = .init(identifier: .gregorian)) -> String? {
        guard let born else { return nil }
        var parts = ["Born " + Self.format(born)]
        if let died {
            var died = "Died " + Self.format(died)
            if let age = Self.age(from: born, to: self.died) { died += " (aged \(age))" }
            parts.append(died)
        } else if let age = Self.age(from: born, to: calendar.dateComponents([.year, .month, .day], from: now)) {
            parts[0] += " (age \(age))"
        }
        return parts.joined(separator: " · ")
    }

    /// Parses a Wikidata time value ("+1962-01-17T00:00:00Z") at its precision
    /// (9 = year, 10 = month, 11 = day).
    static func components(time: String, precision: Int) -> DateComponents? {
        let trimmed = time.hasPrefix("+") ? String(time.dropFirst()) : time
        let fields = trimmed.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard fields.count == 3, !time.hasPrefix("-") else { return nil }
        var components = DateComponents(year: fields[0])
        if precision >= 10, fields[1] > 0 { components.month = fields[1] }
        if precision >= 11, fields[2] > 0, components.month != nil { components.day = fields[2] }
        return components
    }

    private static func format(_ components: DateComponents) -> String {
        guard let year = components.year else { return "" }
        let calendar = Calendar(identifier: .gregorian)
        guard let month = components.month,
              let date = calendar.date(from: DateComponents(year: year, month: month, day: components.day ?? 1)) else {
            return String(year)
        }
        let style = components.day != nil
            ? Date.FormatStyle().year().month(.wide).day()
            : Date.FormatStyle().year().month(.wide)
        return date.formatted(style)
    }

    /// Whole years between two dates, only when both are known to the day.
    private static func age(from start: DateComponents, to end: DateComponents?) -> Int? {
        guard let end, let startYear = start.year, let startMonth = start.month, let startDay = start.day,
              let endYear = end.year, let endMonth = end.month, let endDay = end.day else { return nil }
        let hadBirthday = (endMonth, endDay) >= (startMonth, startDay)
        return endYear - startYear - (hadBirthday ? 0 : 1)
    }
}
