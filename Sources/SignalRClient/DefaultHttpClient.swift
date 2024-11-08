//
//  DefaultHttpClient.swift
//  SignalRClient
//
//  Created by Pawel Kadluczka on 2/26/17.
//  Copyright © 2017 Pawel Kadluczka. All rights reserved.
//

import Foundation

class DefaultHttpClient: HttpClientProtocol {
    private let options: HttpConnectionOptions
    private let session: URLSession

    public init(options: HttpConnectionOptions) {
        self.options = options
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = options.requestTimeout
        DefaultHttpClientSessionDelegate.shared.authenticationChallengeHandler = options.authenticationChallengeHandler
        self.session = URLSession(
            configuration: sessionConfig,
            delegate: DefaultHttpClientSessionDelegate.shared,
            delegateQueue: nil
        )
    }
    
    func get(url: URL) async throws -> HttpResponse? {
        try await sendHttpRequest(url:url, method: "GET", body: nil)
    }

    func post(url: URL, body: Data?) async throws -> HttpResponse? {
        try await sendHttpRequest(url:url, method: "POST", body: body)
    }
    
    func delete(url: URL) async throws -> HttpResponse? {
        try await sendHttpRequest(url:url, method: "DELETE", body: nil)
    }
    
    func sendHttpRequest(url: URL, method: String, body: Data?) async throws -> HttpResponse? {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.httpBody = body
        populateHeaders(headers: options.headers, request: &urlRequest)
        setAccessToken(accessTokenProvider: options.accessTokenProvider, request: &urlRequest)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let httpResponse =  HttpResponse(statusCode: (response as! HTTPURLResponse).statusCode, contents: data)
        return httpResponse
    }

    @inline(__always) private func populateHeaders(headers: [String : String], request: inout URLRequest) {
        headers.forEach { (key, value) in
            request.addValue(value, forHTTPHeaderField: key)
        }
    }

    @inline(__always) private func setAccessToken(accessTokenProvider: () -> String?, request: inout URLRequest) {
        if let accessToken = accessTokenProvider() {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
    }
}

fileprivate final class DefaultHttpClientSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    static let shared = DefaultHttpClientSessionDelegate()
    
    var authenticationChallengeHandler: ((_ session: URLSession, _ challenge: URLAuthenticationChallenge, _ completionHandler: @Sendable @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void)?
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @Sendable @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let challengeHandler = authenticationChallengeHandler {
            challengeHandler(session, challenge, completionHandler)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
