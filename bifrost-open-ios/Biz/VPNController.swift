//
//  VPNController.swift
//  bifrost-open-ios
//

import Foundation
import NetworkExtension

class VPNController {
    private static let tunnelExtensionPointID = "com.apple.networkextension.packet-tunnel"

    var vpnManager: NETunnelProviderManager = NETunnelProviderManager()
    var continueConnectConfig = (proxyHost: "", proxyPort: "")

    var onStatusChangeCallback : (() -> Void)? = nil

    var status : NEVPNStatus {
        return self.vpnManager.connection.status
    }

    var connected : Bool {
        return status == .connected
    }

    var disconnected : Bool {
        return status == .disconnected
    }

    init() {
        loadVPNManager()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onStatusChange(_:)),
            name: NSNotification.Name.NEVPNStatusDidChange,
            object: nil
        )
    }

    func loadVPNManager(onLoad: (() -> Void)? = nil) {
        NETunnelProviderManager.loadAllFromPreferences { (savedManagers: [NETunnelProviderManager]?, error: Error?) in
            if let error = error {
                print("loadA", error)
                return
            }

            if let savedManagers = savedManagers {
                print("count \(savedManagers.count)")

                if savedManagers.count > 0 {
                    self.vpnManager = savedManagers[0]
                }
            }

            self.vpnManager.loadFromPreferences(completionHandler: { (error:Error?) in
                if let error = error {
                    print("loadP", error)
                }

                onLoad?()
            })
        }
    }

    @objc func onStatusChange(_ notification: Notification) {
        let proxyHost = continueConnectConfig.proxyHost
        let proxyPort = continueConnectConfig.proxyPort

        if !proxyHost.isEmpty && !proxyPort.isEmpty && disconnected {
            continueConnectConfig.proxyHost = ""
            continueConnectConfig.proxyPort = ""
            connect(proxyHost: proxyHost, proxyPort: proxyPort)
        }

        self.onStatusChangeCallback?()
    }

    func onChange(callback: @escaping () -> Void) {
        self.onStatusChangeCallback = callback
    }

    func connect(proxyHost: String, proxyPort: String) {
        if connected {
            disconnect()
            continueConnectConfig.proxyHost = proxyHost
            continueConnectConfig.proxyPort = proxyPort
            return
        }

        guard let providerBundleIdentifier = tunnelBundleIdentifier() else {
            print("Unable to find packet tunnel provider bundle identifier")
            return
        }

        let providerProtocol = NETunnelProviderProtocol()
        providerProtocol.providerBundleIdentifier = providerBundleIdentifier
        providerProtocol.serverAddress = "\(proxyHost):\(proxyPort)"
        providerProtocol.providerConfiguration = ["proxyPort": proxyPort, "proxyHost": proxyHost]

        self.vpnManager.isEnabled = true
        self.vpnManager.localizedDescription = "Bifrost Proxy"
        self.vpnManager.protocolConfiguration = providerProtocol

        self.vpnManager.saveToPreferences(completionHandler: { (error: Error?) in
            if let error = error {
                print("saveError", error)
                return
            }

            do {
                try self.vpnManager.connection.startVPNTunnel()
            } catch {
                self.loadVPNManager {
                    do {
                        try self.vpnManager.connection.startVPNTunnel()
                    } catch {
                        print(error)
                    }
                }
            }
        })
    }

    func disconnect() {
        self.vpnManager.connection.stopVPNTunnel()
    }
    
    private func tunnelBundleIdentifier() -> String? {
        if let pluginURL = Bundle.main.builtInPlugInsURL,
           let pluginURLs = try? FileManager.default.contentsOfDirectory(
            at: pluginURL,
            includingPropertiesForKeys: nil
           ) {
            for url in pluginURLs where url.pathExtension == "appex" {
                guard let bundle = Bundle(url: url),
                      let extensionInfo = bundle.infoDictionary?["NSExtension"] as? [String: Any],
                      extensionInfo["NSExtensionPointIdentifier"] as? String == Self.tunnelExtensionPointID,
                      let bundleIdentifier = bundle.bundleIdentifier
                else {
                    continue
                }

                return bundleIdentifier
            }
        }

        return nil
    }

}
