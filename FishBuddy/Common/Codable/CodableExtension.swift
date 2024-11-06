//
//  CodableExtension.swift
//  FishBuddy
//
//  Created by 林哲豪 on 2024/11/6.
//  參考文獻：https://juejin.cn/post/7100194774656745480
//

import Foundation

// 擁有 DefaultValue 協議和 Codable 協議的組合協議，目的是使 SingleValueDecodingContainer 的 decode 保證語法上正確！
typealias DefaultCodableValue = DefaultValue & Codable

// 屬性包裝器
@propertyWrapper
struct Default<T: DefaultCodableValue> {
    var wrappedValue: T
}

// 包裝器遵守 Codable 協議，實現默認的 decoder 和 encoder 方法
extension Default: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        wrappedValue = (try? container.decode(T.self)) ?? T.defaultValue
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

// 對於 key 不存在或者意外輸入不同類型時使用默認的值
extension KeyedDecodingContainer {
    func decode<T>(
        _ type: Default<T>.Type,
        forKey key: Key
    ) throws -> Default<T> where T: DefaultCodableValue {
        if let value = try decodeIfPresent(type, forKey: key) {
            return value
            
        } else {
            return Default(wrappedValue: T.defaultValue)
        }
    }
}

// 數組相關的處理，含義和 KeyedDecodingContainer 的處理一樣
extension UnkeyedDecodingContainer {
    mutating func decode<T>(
        _ type: Default<T>.Type
    ) throws -> Default<T> where T : DefaultCodableValue {
            try decodeIfPresent(type) ?? Default(wrappedValue: T.defaultValue)
    }
}

// 默認值協議
protocol DefaultValue {
    static var defaultValue: Self { get }
}

// 可以給某個可能為 nil 的類型遵守 DefaultValue，使其擁有 defaultValue
extension Bool: DefaultValue { static let defaultValue = false }

extension String: DefaultValue { static var defaultValue = "" }

extension Int: DefaultValue { static var defaultValue = 0 }

extension Double: DefaultValue { static var defaultValue = 0.0 }

extension Float: DefaultValue { static var defaultValue: Float { 0.0 } }

extension Array: DefaultValue { static var defaultValue: Array<Element> { [] } }

extension Dictionary: DefaultValue { static var defaultValue: Dictionary<Key, Value> { [:] } }


extension Data {
    func decode<T: Decodable>(as type: T.Type) -> T? {
        let decoder = JSONDecoder()
        do {
            let decodedData = try decoder.decode(type, from: self)
            return decodedData
        } catch {
            print("Error decoding data: \(error)")
            return nil
        }
    }
}


// MARK: - AnyValue (用來 Codable 解成 Dictionary)
enum AnyValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyValue])
    case dictionary([String: AnyValue])
}

extension AnyValue {
    static func convertAnyValueDictToAnyDict(_ anyValueDict: [String: AnyValue]) -> [String: Any] {
        var anyDict: [String: Any] = [:]
        for (key, value) in anyValueDict {
            switch value {
            case .string(let stringValue):
                anyDict[key] = stringValue
            case .int(let intValue):
                anyDict[key] = intValue
            case .double(let doubleValue):
                anyDict[key] = doubleValue
            case .bool(let boolValue):
                anyDict[key] = boolValue
            case .array(let arrayValue):
                anyDict[key] = arrayValue.map { convertAnyValueToAny($0) }
            case .dictionary(let dictionaryValue):
                anyDict[key] = convertAnyValueDictToAnyDict(dictionaryValue)
            }
        }
        return anyDict
    }
    
    static func convertAnyValueToAny(_ anyValue: AnyValue) -> Any {
        switch anyValue {
        case .string(let stringValue):
            return stringValue
        case .int(let intValue):
            return intValue
        case .double(let doubleValue):
            return doubleValue
        case .bool(let boolValue):
            return boolValue
        case .array(let arrayValue):
            return arrayValue.map { convertAnyValueToAny($0) }
        case .dictionary(let dictionaryValue):
            return convertAnyValueDictToAnyDict(dictionaryValue)
        
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([AnyValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: AnyValue].self) {
            self = .dictionary(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .dictionary(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        }
    }
}
