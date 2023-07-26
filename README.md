# ELSwift for Swift Package Manager

ECHONET Lite通信プロトコルをサポートするパッケージです。


# 使い方

XCodeなら次のようにして使う

File > AddPackages... > 右上の[Search or Enter Package URL] にGithubのURLをコピペ

パッケージ更新は、左型ペインのパッケージのところを右クリックして Upgrade package する


# らいせんす

えむあいてー

```
Copyright (c) 2023 SUGIMURA Hiroshi
```

# for Developper

テストしたいとき
$ swift test

# API Document

- Swift-DocCにてアノテーションして、Github Actionsで自動生成しています。

[ELSwift](https://hiroshi-sugimura.github.io/ELSwift/documentation/elswift/)

# Versions

- 0.3.4 sendQueue処理をデフォルト１秒とする
- 0.3.3 sendDetailsのバグ修正
- 0.3.2 PDCバグ修正
- 0.3.1 見やすく
- 0.3.0 非同期送信
- 0.2.9 無駄なdebugprint削除
- 0.2.8 renewFacilitiesのdebug
- 0.2.7 renewFacilitiesのdebug[x]
- 0.2.6 Self.isDebug
- 0.2.5 0.2.4で埋め込んでしまったdebug
- 0.2.4 facilitiesのDictionaryとOptionalの関係を整理、GET_SNAの取れなかったプロパティの格納を避ける
- 0.2.3 GET_SNAも更新してよいのでdebug
- 0.2.2 facilities更新のdebug
- 0.2.1 Swift-DocC対応していく。d7のdebug
- 0.2.0 結構修正した。やっぱり0.1.0と互換性は無くなっていく
- 0.1.0 とりあえずReleaseできた。エラーケースがチェック完璧じゃない。まだ色々、互換性を考えないで開発がすすむつもり


