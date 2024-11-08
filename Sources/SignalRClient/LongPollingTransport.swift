//
//  LongPollingTransport.swift
//  SignalRClient
//
//  Created by David Robertson on 13/07/2020.
//

import Foundation

public class LongPollingTransport: Transport {
    public var delegate: TransportDelegate?
    
    private let logger: Logger
    private let closeQueue = DispatchQueue(label: "LongPollingTransportCloseQueue")
    
    private var active = false
    private var opened = false
    private var closeCalled = false
    private var url: URL?
    private var closeError: Error?
    private var options: HttpConnectionOptions!
    
    public let inherentKeepAlive = true

    init(logger: Logger) {
        self.logger = logger
    }
    
    public func start(url: URL, options: HttpConnectionOptions) async {
        logger.log(logLevel: .info, message: "Starting LongPolling transport")
        self.options = options
        self.url = url
        opened = false
        closeError = nil
        closeCalled = false
        active = true
        await triggerPoll()
    }
    
    public func send(data: Data, sendDidComplete: @Sendable @escaping (Error?) -> Void) async throws {
        guard active, let url = url else {
            sendDidComplete(SignalRError.invalidState)
            return
        }
        let httpClient = options.httpClientFactory(options)
        let httpResponse = try await httpClient.post(url: url, body: data)
        if let response = httpResponse {
            if response.statusCode == 200 {
                sendDidComplete(nil)
            } else {
                sendDidComplete(SignalRError.webError(statusCode: response.statusCode))
            }
        }
    }
    
    public func close() {
        let httpClient = options.httpClientFactory(options)
        Task {
            if !closeCalled {
                closeCalled = true
                active = false
                self.logger.log(logLevel: .debug, message: "Sending LongPolling session DELETE request...")
                
                Task {
                    do {
                        let _ = try await httpClient.delete(url: self.url!)
                    } catch {
                        self.logger.log(logLevel: .error, message: "Error while DELETE-ing long polling session: \(error)")
                        self.delegate?.transportDidClose(error)
                    }
                    self.logger.log(logLevel: .info, message: "LongPolling transport stopped.")
                    self.delegate?.transportDidClose(self.closeError)
                }
            } else {
                self.logger.log(logLevel: .debug, message: "closeCalled flag is already set")
            }
        }
    }
    
    private func triggerPoll() async {
        if self.active {
            let pollUrl = self.getPollUrl()
            self.logger.log(logLevel: .debug, message: "Polling \(pollUrl)")
            let httpClient = options.httpClientFactory(options)
            do {
                let _ = try await httpClient.get(url: pollUrl)
            } catch {
                
            }
            self.handlePollResponse(response: nil, error: nil)
        } else {
            self.logger.log(logLevel: .debug, message: "Long Polling transport polling complete.")
            self.close()
        }
    }
    
    private func handlePollResponse(response: HttpResponse?, error: Error?) {
        if let error = error {
            if (error as? URLError)?.errorCode == NSURLErrorTimedOut {
                self.logger.log(logLevel: .debug, message: "Poll timed out (client side), reissuing.")
            } else {
                self.logger.log(logLevel: .error, message: "Error during polling: \(error)")
                self.closeError = error
                self.active = false
            }
            
        } else if let response = response {
            switch response.statusCode {
            case 204:
                self.logger.log(logLevel: .info, message: "LongPolling transport terminated by server.")
                self.closeError = nil
                self.active = false
                
            case 200:
                if !self.opened {
                    // First response must be discarded.
                    self.opened = true
                    self.delegate?.transportDidOpen()
                } else if let data = response.contents, data.count > 0 {
                    self.logger.log(logLevel: .debug, message: "Message received: \(data)")
                    self.delegate?.transportDidReceiveData(data)
                } else {
                    self.logger.log(logLevel: .debug, message: "Poll timed out (server side), reissuing.")
                }
                
                
            case 404:
                // If we have a poll request in progress when .close() is called, the session will be destroyed and the server
                // will respond with 404. So if we get a 404 when the active flag is false, this is normal. Otherwise,
                // we should treat this as an unexpected response.
                if self.active {
                    fallthrough
                }
            default:
                self.logger.log(logLevel: .error, message: "Unexpected response code \(response.statusCode)")
                self.closeError = SignalRError.webError(statusCode: response.statusCode)
                self.active = false
            }
        }
        
        Task {
            await self.triggerPoll()
        }
    }
    
    
    private func getPollUrl() -> URL {
        var components = URLComponents.init(url: self.url!, resolvingAgainstBaseURL: true)!
        if components.queryItems == nil {
            components.queryItems = []
        }
        let millisecondUnixTime = Int64(Date().timeIntervalSince1970 * 1000)
        components.queryItems?.append(URLQueryItem(name: "_", value: String(millisecondUnixTime)))
        let pollUrl = components.url
        return pollUrl!
    }
    
}
