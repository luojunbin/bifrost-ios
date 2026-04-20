//
//  Home.swift
//  bifrost-open-ios
//

import SwiftUI
import NetworkExtension

let SCHEME_PATTERN = "^(?:(.+)@)?((?:\\d+\\.?)+):(\\d+)$"

enum InvalidError: Error {
    case invalid(message: String)
}

struct Home: View {
    let vpn = VPNController()

    @State var status = NEVPNStatus.disconnected
    @State var showInputDialog = false

    @State var showScanner = false
    @State var showMenu = false
    @State var showAboutAlert = false

    @State var loading = false

    @State var toastText = "" {
        willSet {
            if newValue.isEmpty {
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if toastText == newValue {
                    toastText = ""
                }
            }
        }
    }

    @State var currentScheme = UserDefaults.standard.string(forKey: Constants.current_scheme) ?? "" {
        willSet {
            UserDefaults.standard.set(newValue, forKey: Constants.current_scheme)

            let newUsername = extractUsername(from: newValue)

            if let username = newUsername,
               let existingIndex = schemeHistory.firstIndex(where: { extractUsername(from: $0) == username }) {
                // username 相同时，替换已有项
                schemeHistory[existingIndex] = newValue
            } else if schemeHistory.firstIndex(of: newValue) == nil {
                schemeHistory.append(newValue)
            }
        }
    }

    @State var currentSchemeHost = UserDefaults.standard.string(forKey: Constants.current_scheme_host) ?? "" {
        willSet {
            UserDefaults.standard.set(newValue, forKey: Constants.current_scheme_host)
        }
    }

    @State var currentSchemePort = UserDefaults.standard.string(forKey: Constants.current_scheme_port) ?? "" {
        willSet {
            UserDefaults.standard.set(newValue, forKey: Constants.current_scheme_port)
        }
    }

    @State var schemeHistory = UserDefaults.standard.stringArray(forKey: Constants.scheme_history) ?? [] {
        willSet {
            UserDefaults.standard.set(newValue, forKey: Constants.scheme_history)
        }
    }


    /// 从 scheme 字符串中提取 username 部分（@ 之前的内容）
    func extractUsername(from scheme: String) -> String? {
        guard let atIndex = scheme.firstIndex(of: "@") else {
            return nil
        }
        let username = String(scheme[scheme.startIndex..<atIndex])
        return username.isEmpty ? nil : username
    }

    func removeScheme(willRemoveScheme: String) {
        schemeHistory.removeAll(where: { item in
            return item == willRemoveScheme
        })

        if currentScheme == willRemoveScheme {
            vpn.disconnect()
        }
    }

    func destructScheme(scheme: String) throws -> [String] {
        let RE = try NSRegularExpression(pattern: SCHEME_PATTERN, options: .caseInsensitive)
        let matchs = RE.matches(in: scheme, options: .reportProgress, range: NSRange(location: 0, length: scheme.count))

        if matchs.count <= 0 {
            throw InvalidError.invalid(message: scheme)
        }

        let result : [String] = matchs.map { match in
            return (0..<match.numberOfRanges).map {
                let rangeBounds = match.range(at: $0)
                guard let range = Range(rangeBounds, in: scheme) else {
                    return ""
                }
                return String(scheme[range])
            }
        }[0]

        return Array(result[1..<result.count])
    }

    func connect(scheme: String = "") {
        do {
            if status == .connected && currentScheme == scheme {
                return
            }

            let result = try destructScheme(scheme: scheme)

            loading = true
            currentScheme = scheme
            currentSchemeHost = result[1]
            currentSchemePort = result[2]

            Request.ping(ip: currentSchemeHost, port: currentSchemePort, callback: { reachable in
                if reachable {
                    vpn.connect(proxyHost: result[1], proxyPort: result[2])
                } else if currentScheme == scheme {
                    vpn.disconnect()
                    toastText = "目标服务器不可达"
                }
                loading = false
            })
        } catch InvalidError.invalid(_) {
            toastText = "请输入合法的 ip v4 地址"
        }

        catch {
            print(error)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                // 顶部主题色背景（延伸到安全区域顶部）
                GeometryReader { geo in
                    Color("main")
                        .frame(height: geo.safeAreaInsets.top + 220)
                        .ignoresSafeArea(edges: .top)
                }

                VStack(spacing: 0) {
                    // 顶部连接按钮区域
                    VStack(spacing: 0) {
                        Button(action: {
                            if vpn.connected {
                                vpn.disconnect()
                            } else {
                                connect(scheme: currentScheme)
                            }
                        }) {
                            if status == .connected {
                                Image(systemName: "checkmark.icloud.fill")
                                    .font(.system(size: 45))
                            } else {
                                Image(systemName: "power")
                                    .font(.system(size: 45))
                            }
                        }
                        .frame(width: 90, height: 90, alignment: .center)
                        .foregroundColor(Color("main"))
                        .background(Color.white)
                        .clipShape(Circle())
                        .onAppear {
                            vpn.onChange {
                                status = vpn.status
                            }
                        }

                        Text(status == .connected ? "已连接" : "未连接")
                            .foregroundColor(.white)
                            .padding(.top, 10)
                            .padding(.bottom, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                    .background(Color("main"))

                    // 列表区域
                    VStack(alignment: .leading, spacing: 0) {
                        Text("最近使用的 PC")
                            .padding(13)
                            .foregroundColor(.secondary)

                        Divider()

                        List(schemeHistory, id: \.self) { item in
                            Button(action:{
                                if !loading {
                                    connect(scheme: item)
                                }
                            }) {
                                HStack(alignment: .top, spacing: 12) {
                                    if item == currentScheme {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 22))

                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 22))
                                    }

                                    Text(item)
                                        .font(.system(size: 17))
                                        .foregroundColor(Color.primary)

                                    Spacer()
                                }.contextMenu {
                                    Button(action: {
                                        removeScheme(willRemoveScheme: item)
                                    }) {
                                        Text("删除")
                                            .foregroundColor(.red)
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(Color(.systemBackground))

                    Divider()

                    // 底部扫码按钮
                    Button(action: {
                        showScanner.toggle()
                    }) {
                        Spacer()
                        Image(systemName: "qrcode")
                            .font(.system(size: 23))
                        Text("扫码添加代理")
                        Spacer()
                    }
                    .sheet(isPresented: $showScanner) {
                        ScannerView() { result in
                            let scheme = result.first {
                                do {
                                    let _ = try destructScheme(scheme: $0)
                                    return true
                                } catch {
                                    return false
                                }
                            }

                            connect(scheme: scheme ?? "")
                        }
                    }
                    .frame(height: 50, alignment: .center)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            showInputDialog.toggle()
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showMenu = true
                        }) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        .actionSheet(isPresented: $showMenu) {
                            ActionSheet(
                                title: Text("Bifrost"),
                                buttons: [
                                    .default(Text("关于 Bifrost")) {
                                        showAboutAlert = true
                                    },
                                    .cancel()
                                ]
                            )
                        }
                        .alert(isPresented: $showAboutAlert) {
                            Alert(
                                title: Text(""),
                                message: Text("当前版本: \((Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0")"),
                                dismissButton: .default(
                                    Text("确定"),
                                    action: {}
                                )
                            )
                        }
                    }
                }

                // TextAlert (隐藏 host)
                HStack {}
                    .textAlert(
                        isPresented: $showInputDialog,
                        TextAlert(
                            title: "Bifrost",
                            message: "请输入代理服地址",
                            placeholder: "代理地址 (ipv4:port)",
                            keyboardType: .default
                        ) { result in
                            if let text = result {
                                connect(scheme: text)
                            }
                        }
                    )
                    .frame(width: 0, height: 0)

                // Toast
                if !toastText.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Text(toastText).foregroundColor(.black)
                                .font(.system(size: 14))
                        }
                        .padding(10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .gray, radius: 3)
                        .transition(.opacity)
                        Spacer()
                    }
                    .zIndex(100)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct Home_Previews: PreviewProvider {
    static var previews: some View {
        Home()
    }
}
