//
//  Request.swift
//  bifrost-open-ios
//

import Network
import Foundation

struct Request {
    static func get<T: Decodable>(rawUrl: String, callback: @escaping (Error?, T?) -> Void) {
        var component = URLComponents(string: rawUrl)!

        if component.queryItems == nil {
            component.queryItems = []
        }

        component.queryItems!.append(URLQueryItem(name: "platform", value: "ios"))
        component.queryItems!.append(URLQueryItem(name: "version_code", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String))
        component.queryItems!.append(URLQueryItem(name: "version_name", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String))

        var request = URLRequest(url: component.url!)
        request.timeoutInterval = 3

        print("component.url", component.url!)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                print("request_error")
                callback(error, nil)
                return
            }

            if let data = data {
                if let decodedResponse = try? JSONDecoder().decode(T.self, from: data) {
                    DispatchQueue.main.async {
                        callback(nil, decodedResponse)
                    }
                    return
                }
            }
        }.resume()
    }

    static func ping(ip: String, port: String, callback: @escaping (Bool) -> Void) {
        let connection = NWConnection(host: NWEndpoint.Host(ip), port: NWEndpoint.Port(port)!, using: .tcp)
        connection.stateUpdateHandler = { (newState) in
            switch(newState) {
            case .ready:
                callback(true)
                connection.forceCancel()

            case .failed(_):
                callback(false)
                connection.forceCancel()

            default:
                break
            }
        }
        connection.start(queue: .main)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if connection.state != .ready && connection.state != .cancelled {
                callback(false)
                connection.forceCancel()
            }
        }
    }
}
