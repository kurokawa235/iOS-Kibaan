//  Created by 山本敬太 on 2018/08/11.
//  Copyright © 2018年 altonotes. All rights reserved.
//

import XCTest
@testable import Kibaan

class LocalStorageTests: XCTestCase {

    let key = "key"

    func testString() {
        let setting = LocalStorage()

        let value = "testify"
        setting.setString(key, value: value, willSave: false)
        
        let result = setting.getString(key, defaultValue: "")
        
        XCTAssertEqual(value, result)
    }
    
    func testStringArray() {
        let setting = LocalStorage()
        
        let value = ["abc", "def", ",,", "\t"]
        setting.setStringArray(key: key, value: value, willSave: false)
        
        let result = setting.getStringArray(key)
        
        XCTAssertEqual(value.count, result.count)
        
        value.enumerated().forEach {
            XCTAssertEqual($0.element, result[$0.offset])
        }
    }
    
    func testInt() {
        let setting = LocalStorage()
        
        let value = 12345
        setting.setInt(key, value: value, willSave: false)
        
        let result = setting.getInt(key, defaultValue: 0)
        
        XCTAssertEqual(value, result)
    }
    
    func testBool() {
        let setting = LocalStorage()
        
        setting.setBool("true", value: true, willSave: false)
        setting.setBool("false", value: false, willSave: false)

        XCTAssertEqual(setting.getBool("true"), true)
        XCTAssertEqual(setting.getBool("false"), false)
    }
    
    func testFloat() {
        let setting = LocalStorage()
        
        let value: CGFloat = 12.345678

        setting.setFloat(key, value: value, decimalLength: 2, willSave: false)
        
        let result = setting.getFloat(key)

        XCTAssertEqual(result, 12.35)
    }
    
    func testEnum() {
        let setting = LocalStorage()
        
        let value: SampleEnum = .valueA
        
        setting.setEnum(key, value: value, willSave: false)
        
        let result = setting.getEnum(key, type: SampleEnum.self, defaultValue: .valueC)
        
        XCTAssertEqual(value, result)
    }
    
    func testEnumArray() {
        let setting = LocalStorage()
        
        let value: [SampleEnum] = [.valueA, .valueB, .valueC]
        
        setting.setEnumArray(key, value: value, willSave: false)
        
        let result = setting.getEnumArray(key, type: SampleEnum.self)
        
        XCTAssertEqual(value.count, result.count)
        value.enumerated().forEach {
            XCTAssertEqual($0.element, result[$0.offset])
        }
    }
    
    func testEnumOrNilArray() {
        let setting = LocalStorage()
        
        let value: [SampleEnum?] = [.valueA, .valueB, nil, .valueC]
        
        setting.setEnumOrNilArray(key, value: value, willSave: false)
        
        let result = setting.getEnumOrNilArray(key, type: SampleEnum.self)
        
        XCTAssertEqual(value.count, result.count)
        value.enumerated().forEach {
            XCTAssertEqual($0.element, result[$0.offset])
        }
    }
    
    func testCodable() {
        let setting = LocalStorage()
        
        let value = SampleCodable(number: 1234)
        let emptyValue = SampleCodable(number: 0)
        
        setting.setCodable(key, value: value, willSave: false)
        
        let result = setting.getCodable(key, type: SampleCodable.self, defaultValue: emptyValue)
        
        XCTAssertEqual(value.number, result.number)

    }
    
    func testCodableOrNil() {
        let setting = LocalStorage()
        XCTAssertNil(setting.getCodableOrNil("Nil", type: String.self))
    }
    
    enum SampleEnum: String {
        case valueA
        case valueB
        case valueC
    }
    
    class SampleCodable: Codable {
        var number = 0
        init(number: Int) {
            self.number = number
        }
    }
}
