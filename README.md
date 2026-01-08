# ELSwift 🌿

[![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg?style=flat)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS-lightgrey.svg)](https://developer.apple.com/swift/)

ELSwift は、Apple の `Network.framework` をベースにした、ピュア Swift 実装の **ECHONET Lite** 通信ライブラリです。最新の Swift 6 並行処理 (Structured Concurrency) に完全対応し、軽量かつ直感的な API を提供します。

---

## ✨ Features

- ⚡️ **Network.framework ベース**: モダンで安定した UDP マルチキャスト通信。
- 🛡️ **Swift 6 対応**: Actor や `nonisolated(unsafe)` などを適切に活用した安全な並行処理設計。
- 📦 **SPM サポート**: Swift Package Manager ですぐに導入可能。
- 🔌 **自動リソース管理**: `stop()` による明示的なリソース解放と、ポート再利用設定 (`allowLocalEndpointReuse`) の最適化。
- 📖 **DocC 対応**: インラインドキュメントから自動生成された API ガイド。

---

## 🚀 Getting Started

### Installation (Swift Package Manager)

1. Xcode のプロジェクト設定で **File > Add Packages...** を選択。
2. 検索バーに `https://github.com/hiroshi-sugimura/ELSwift.git` を入力して追加。

### Important: Entitlements

iOS や macOS アプリで UDP マルチキャストを使用する場合、`Entitlements` の設定が必須です。

1. **ELSwift.entitlements** をプロジェクトにコピーして設定に含めてください。
2. **Local Network**: ユーザーのローカルネットワーク上のデバイス探索を許可する設定が必要です。
3. **Multicast Networking**: Apple からの権限付与が必要な場合があります（`com.apple.developer.networking.multicast`）。

> [!NOTE]
> Apple のセキュリティポリシーは頻繁に更新されるため、最新のドキュメントもあわせて参照することをお勧めします。

---

## 💻 Usage

### 1. 初期化と受信の開始

```swift
import ELSwift

let myDevices: [UInt8] = [0x05, 0xff, 0x01] // ノードプロファイルオブジェクトなど

try ELSwift.initialize(myDevices, { (address, els, error) in
    if let els = els {
        print("Received from \(address): \(els)")
    }
}, option: (debug: true, ipVer: 0, autoGetProperties: true))
```

### 2. デバイスの探索 (Search)

```swift
// ネットワーク上の全デバイスに対して探索パケットを送信
try ELSwift.search()
```

### 3. データの送信

```swift
// 特定のデバイスに対してプロパティ取得を送信
try ELSwift.sendOPC1("192.168.1.10", 
                        [0x0e, 0xf0, 0x01], // SEOJ
                        [0x01, 0x30, 0x01], // DEOJ (例: エアコン)
                        ELSwift.GET, 
                        0x80, // EPC (動作状態)
                        [])
```

### 4. 通信の終了

```swift
// リソースを解放して終了。アプリの終了や通信の停止時に呼び出してください。
ELSwift.stop()
```

---

## 📚 API Documentation

詳細な API 仕様については、[API Document (GitHub Pages)](https://hiroshi-sugimura.github.io/ELSwift/documentation/elswift/) をご確認ください。

---

## 📄 License

**MIT License**
Copyright (c) 2023-2026 SUGIMURA Hiroshi

> [!TIP]
> アプリケーションの「バージョン情報」や「ヘルプ」などに、著作権表示を含めていただけると幸いです。

---

## 📜 Versions

- **1.2.0** ✨: `stop()` メソッド追加、Swift 6 並行処理対応、`allowLocalEndpointReuse = true` 有効化、強制アンラップ排除による安定化。
- **1.1.0** : ip取得のgetter対応。
- **1.0.0** : IPaddressの取得に対応、実績が増えてきたので一旦メジャーバージョンとしてリリース。
- **0.4.8** : facilitiesManagerでデータアクセス管理。
- **0.4.7** : actor対応のbugfix。
- **0.4.6** : Swift6、actor対応、ELSwift.facilitiesをprivateにしてgetFacilitiesを追加。
- **0.4.5** : parseのException対応。
- **0.4.4** : 不要なprint削除。
- **0.4.3** : facilitiesにセマフォ導入の試行。
- **0.4.2** : debug。
- **0.4.1** : emptyチェック追加。
- **0.4.0** : returnerをasync化。
- **0.3.9** : debug print関連修正。
- **0.3.8** : Doccおよびdebug print関連修正。
- **0.3.7** : EL format 2の解析前reject対応（三菱TV等対応）。
- **0.3.6** : delay 0.2への調整。
- **0.3.5** : queue名変更、port重複判定、sendQueue処理待ち調整。
- **0.3.4** : sendQueue処理をデフォルト1秒に設定。
- **0.3.3** : sendDetailsのバグ修正。
- **0.3.2** : PDCバグ修正。
- **0.3.1** : コードの可読性向上。
- **0.3.0** : 非同期送信のサポート。
- **0.2.x** : 初期開発フェーズにおける各種バグ修正とリファクタリング。
- **0.1.0** : 初回リリース。
