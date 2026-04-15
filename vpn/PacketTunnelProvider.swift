//
//  PacketTunnelProvider.swift
//  bifrost-open-ios vpn extension
//

import NetworkExtension
import Network

class PacketTunnelProvider: NEPacketTunnelProvider {
    var connection: NWConnection? = nil

    private func initTunnelSettings(proxyHost: String, proxyPort: Int) -> NEPacketTunnelNetworkSettings {
        let settings: NEPacketTunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        let proxySettings: NEProxySettings = NEProxySettings()
        let proxyServer = NEProxyServer(
            address: proxyHost,
            port: proxyPort
        )
        proxySettings.httpServer = proxyServer
        proxySettings.httpsServer = proxyServer
        proxySettings.autoProxyConfigurationEnabled = false
        proxySettings.httpEnabled = true
        proxySettings.httpsEnabled = true
        proxySettings.excludeSimpleHostnames = true
        proxySettings.exceptionList = []
        settings.proxySettings = proxySettings

        let ipv4Settings: NEIPv4Settings = NEIPv4Settings(
            addresses: [settings.tunnelRemoteAddress],
            subnetMasks: ["255.255.255.255"]
        )

        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        ipv4Settings.excludedRoutes = [
            NEIPv4Route(destinationAddress: "1.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "2.0.0.0", subnetMask: "254.0.0.0"),
            NEIPv4Route(destinationAddress: "4.0.0.0", subnetMask: "252.0.0.0"),
            NEIPv4Route(destinationAddress: "8.0.0.0", subnetMask: "254.0.0.0"),
            NEIPv4Route(destinationAddress: "11.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "12.0.0.0", subnetMask: "252.0.0.0"),
            NEIPv4Route(destinationAddress: "16.0.0.0", subnetMask: "240.0.0.0"),
            NEIPv4Route(destinationAddress: "32.0.0.0", subnetMask: "224.0.0.0"),
            NEIPv4Route(destinationAddress: "64.0.0.0", subnetMask: "224.0.0.0"),
            NEIPv4Route(destinationAddress: "96.0.0.0", subnetMask: "252.0.0.0"),
            NEIPv4Route(destinationAddress: "128.0.0.0", subnetMask: "224.0.0.0"),
            NEIPv4Route(destinationAddress: "160.0.0.0", subnetMask: "248.0.0.0"),
            NEIPv4Route(destinationAddress: "176.0.0.0", subnetMask: "240.0.0.0"),
            NEIPv4Route(destinationAddress: "192.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "193.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "194.0.0.0", subnetMask: "254.0.0.0"),
            NEIPv4Route(destinationAddress: "196.0.0.0", subnetMask: "254.0.0.0"),
            NEIPv4Route(destinationAddress: "198.0.0.0", subnetMask: "254.0.0.0"),
            NEIPv4Route(destinationAddress: "200.0.0.0", subnetMask: "254.0.0.0"),
            NEIPv4Route(destinationAddress: "202.0.0.0", subnetMask: "254.0.0.0"),
            NEIPv4Route(destinationAddress: "204.0.0.0", subnetMask: "252.0.0.0"),
            NEIPv4Route(destinationAddress: "208.0.0.0", subnetMask: "240.0.0.0"),
            NEIPv4Route(destinationAddress: proxyHost, subnetMask: "255.255.255.255")
        ]
        settings.ipv4Settings = ipv4Settings

        settings.mtu = 1500

        return settings
    }

    func readPackets(connection: NWConnection) {
        packetFlow.readPackets {(packets, protocols) in
            for packet in packets {
                connection.send(content: packet, completion: .contentProcessed({ _ in }))
            }

            self.readPackets(connection: connection)
        }
    }

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let conf = (protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration! as [String : AnyObject]

        let proxyHost = conf["proxyHost"] as! String
        let proxyPort = conf["proxyPort"] as! String
        let proxyPortInt = Int(proxyPort)!

        let networkSettings = initTunnelSettings(proxyHost: proxyHost, proxyPort: proxyPortInt)

        setTunnelNetworkSettings(networkSettings)

        let host = NWEndpoint.Host(proxyHost)
        let port = NWEndpoint.Port(proxyPort)!

        let tcpConnection = NWConnection(host: host, port: port, using: .tcp)
        self.connection = tcpConnection
        tcpConnection.start(queue: .main)

        readPackets(connection: tcpConnection)

        reasserting = false
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        connection?.cancel()
        connection = nil
        super.stopTunnel(with: reason, completionHandler: completionHandler)
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        if let handler = completionHandler {
            handler(messageData)
        }
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    override func wake() {
    }
}
