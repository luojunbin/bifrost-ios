# Bifrost iOS

Bifrost 是一款 iOS 端的 HTTP 代理客户端，通过系统级 VPN（Packet Tunnel）将设备流量转发到指定的代理服务器，主要用于移动端开发调试场景。

目前仅支持 HTTP/HTTPS 代理服务器，不支持 SOCKS 代理；支持市面上已知的 PC 代理软件，如：Charles、Whistle 和 Bifrost。

## 功能特性

- **一键连接** — 输入代理服务器地址即可建立系统级 VPN 隧道
- **扫码添加** — 通过扫描二维码快速导入代理服务器配置
- **历史记录** — 自动保存使用过的代理地址，支持快速切换和删除
- **连通性检测** — 连接前自动 ping 目标服务器，不可达时及时提示

## 项目结构

```
bifrost-open-ios/
├── bifrost_open_iosApp.swift     # App 入口
├── Biz/
│   ├── Home.swift                # 主界面（连接控制、代理列表、扫码）
│   └── VPNController.swift       # VPN 连接管理（NETunnelProviderManager）
├── Base/
│   ├── Constants.swift           # UserDefaults 存储键名
│   ├── Request.swift             # 网络请求 & TCP 连通性检测
│   ├── ScannerView.swift         # 二维码扫描（AVFoundation）
│   └── CustomAlert.swift         # 带输入框的弹窗组件
└── Assets.xcassets/              # 图标与颜色资源

vpn/
├── PacketTunnelProvider.swift    # Network Extension 隧道实现
├── vpn.entitlements              # 网络扩展权限声明
└── Info.plist                    # 扩展配置
```

## 技术栈

| 类别         | 技术                                       |
| ------------ | ------------------------------------------ |
| UI 框架      | SwiftUI                                    |
| 语言         | Swift 5                                    |
| VPN 实现     | NetworkExtension（Packet Tunnel Provider） |
| 网络层       | Network.framework（NWConnection）          |
| 扫码         | AVFoundation（AVCaptureSession）           |
| 最低部署版本 | iOS 16.0+                                  |
| 支持设备     | iPhone / iPad                              |

## 工作原理

1. 用户输入或扫码获取代理服务器地址（格式：`[name@]ip:port`）
2. App 通过 TCP 连接检测目标服务器可达性
3. 通过 `NETunnelProviderManager` 创建系统级 VPN 配置
4. `PacketTunnelProvider`（Network Extension）建立隧道，将 HTTP/HTTPS 流量转发至代理服务器
5. 路由表排除了主要公网 IP 段，仅代理内网相关流量

## 环境要求

- Xcode 15.0+
- iOS 16.0+ 真机（VPN 功能不支持模拟器）
- Apple Developer 账号（需要 Network Extension 权限）

## 快速开始

1. 克隆项目

   ```bash
   git clone <repo-url>
   cd bifrost-open-ios
   ```

2. 在 Xcode 中打开 `bifrost-open-ios.xcodeproj`

3. 配置签名
   - 分别为 `bifrost-open-ios` 和 `vpn` 两个 target 设置开发团队
   - 确保 Bundle Identifier 中 vpn extension 是主 App 的子标识符

4. 选择真机设备，Run ▶️

## 代理地址格式

```
ip:port          # 例如 192.168.1.100:8888
name@ip:port     # 例如 my-pc@192.168.1.100:8888
```

支持通过二维码扫描导入以上格式的地址。

## License

MIT
