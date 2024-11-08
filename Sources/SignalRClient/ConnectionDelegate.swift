//
//  ConnectionDelegate.swift
//  SignalRClient
//
//  Created by Pawel Kadluczka on 2/26/17.
//  Copyright © 2017 Pawel Kadluczka. All rights reserved.
//

import Foundation

public protocol ConnectionDelegate: AnyObject {
    func connectionDidOpen(connection: Connection) async
    func connectionDidFailToOpen(error: Error) async
    func connectionDidReceiveData(connection: Connection, data: Data) async
    func connectionDidClose(error: Error?) async
    func connectionWillReconnect(error: Error) async
    func connectionDidReconnect() async
}

public extension ConnectionDelegate {
    func connectionWillReconnect(error: Error) {}
    func connectionDidReconnect() {}
}
