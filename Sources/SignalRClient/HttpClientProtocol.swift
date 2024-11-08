//
//  HttpClientProtocol.swift
//  SignalRClient
//
//  Created by Pawel Kadluczka on 7/30/18.
//  Copyright © 2018 Pawel Kadluczka. All rights reserved.
//

import Foundation

/**
 Http Client protocol.
 */
public protocol HttpClientProtocol {
    /**
     Sends a `GET` HTTP request.

     - parameter url: URL
     - parameter completionHandler: callback invoked after the HTTP request has been completed
     */
    func get(url: URL) async throws -> HttpResponse?

    /**
     Sends a `POST` HTTP request with body data.

     - parameter url: URL
     - parameter body: Body data to send to server
     - parameter completionHandler: callback invoked after the HTTP request has been completed
     */
    func post(url: URL, body: Data?) async throws -> HttpResponse?

    
    /**
     Sends a `DELETE` HTTP request.

     - parameter url: URL
     - parameter completionHandler: callback invoked after the HTTP request has been completed
     */
    func delete(url: URL) async throws -> HttpResponse?
}
