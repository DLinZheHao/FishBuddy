//
//  JsonHelper.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2025/12/24.
//

import UIKit

enum JSONDecodeError: Error {
    case emptyString
    case invalidData
    case decodingFailed(Error)
}

struct JSONHelper {

    /// Decode a JSON string into a Decodable type.
    ///
    /// - Parameters:
    ///   - jsonString: Raw JSON string from database (TEXT column)
    ///   - type: Target Decodable type
    ///   - decoder: Custom JSONDecoder if needed (default provided)
    ///
    /// - Returns:
    ///   Decoded object, or nil if jsonString is nil.
    ///
    /// - Throws:
    ///   JSONDecodeError when string exists but decoding fails.
    static func decode<T: Decodable>(
        _ jsonString: String?,
        as type: T.Type,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> T? {

        guard let jsonString else { return nil }
        guard !jsonString.isEmpty else {
            throw JSONDecodeError.emptyString
        }
        guard let data = jsonString.data(using: .utf8) else {
            throw JSONDecodeError.invalidData
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw JSONDecodeError.decodingFailed(error)
        }
    }
}
