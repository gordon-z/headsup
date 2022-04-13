//
//  CBUUID.swift
//  headsup
//
//  Created by Benjamin Stephens on 2022-03-22.
//

import Foundation
import CoreBluetooth

struct CBUUIDs{

    //Original
//    static let kBLEService_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
//    static let kBLE_Characteristic_uuid_Tx = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
//    static let kBLE_Characteristic_uuid_Rx = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
    //Mac
//    static let kBLEService_UUID = "DCB663AB-18A1-5299-A0DA-F118318F1E68"
//    static let kBLE_Characteristic_uuid_Tx = "DCB663AB-18A1-5299-A0DA-F118318F1E68"
//    static let kBLE_Characteristic_uuid_Rx = "DCB663AB-18A1-5299-A0DA-F118318F1E68"
    //Windows
//    static let kBLEService_UUID = "032E02B4-0499-0538-5B06-610700080009"
//    static let kBLE_Characteristic_uuid_Tx = "032E02B4-0499-0538-5B06-610700080009"
//    static let kBLE_Characteristic_uuid_Rx = "032E02B4-0499-0538-5B06-610700080009"
    
//    static let kBLEService_UUID = "86A22DA3-74E2-495A-9AA7-92B0AD57312A"
//    static let kBLE_Characteristic_uuid_Tx = "86A22DA3-74E2-495A-9AA7-92B0AD57312A"
//    static let kBLE_Characteristic_uuid_Rx = "86A22DA3-74E2-495A-9AA7-92B0AD57312A"
    
    //Pi identifier
    static let kBLEService_UUID = "C3B07651-1EB2-CBC0-C770-2381A49C19CE"
    static let kBLE_Characteristic_uuid_Tx = "2B37"
    static let kBLE_Characteristic_uuid_Rx = "2A37"
    static let heartServiceID = "180D"

    static let heartServiceUUID = CBUUID(string: heartServiceID)
    static let BLEService_UUID = CBUUID(string: kBLEService_UUID)
    static let BLE_Characteristic_uuid_Tx = CBUUID(string: kBLE_Characteristic_uuid_Tx)//(Property = Write without response)
    static let BLE_Characteristic_uuid_Rx = CBUUID(string: kBLE_Characteristic_uuid_Rx)// (Property = Read/Notify)

}
