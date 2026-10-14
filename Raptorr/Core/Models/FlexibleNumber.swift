import Foundation

/// A number the server sends either as a JSON number or as a string, such as a stream's
/// `frameRate` (`23.976` in the spec's schema, `"29.970"` in its examples).
nonisolated struct FlexibleNumber: Decodable, Sendable, Hashable {
    let value: Double

    init(_ value: Double) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Double.self) {
            value = number
        } else if let text = try? container.decode(String.self), let number = Double(text) {
            value = number
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a number")
        }
    }
}
