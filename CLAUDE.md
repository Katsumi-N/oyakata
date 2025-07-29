# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

このプロジェクトは製図試験の勉強用プリント管理アプリです。SwiftUIとSwiftDataを使用したiOSアプリケーションで、以下の機能を提供します：

- 画像のアップロード・編集（Apple Pencil対応）
- タグとタイトルによる画像管理
- 6つの定義済みタグ（問題用紙、赤入れした問題用紙、エスキスの例、エスキス、製図、解答例）
- ミスリスト機能（製図後の振り返り用）
- 検索機能
- ローカルストレージ

## アーキテクチャ

- **フレームワーク**: SwiftUI
- **データ永続化**: SwiftData
- **アーキテクチャパターン**: MVVM
- **ターゲット**: iOS

## 開発コマンド

### ビルドとテスト
```bash
# プロジェクトをXcodeで開く
open oyakata-app.xcodeproj

# コマンドラインでビルド
xcodebuild -project oyakata-app.xcodeproj -scheme oyakata-app -destination 'platform=iOS Simulator,name=iPhone 15' build

# テスト実行
xcodebuild test -project oyakata-app.xcodeproj -scheme oyakata-app -destination 'platform=iOS Simulator,name=iPhone 15'

# 特定のテストクラス実行
xcodebuild test -project oyakata-app.xcodeproj -scheme oyakata-app -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:oyakata-appTests/oyakata_appTests

# UIテスト実行
xcodebuild test -project oyakata-app.xcodeproj -scheme oyakata-app -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:oyakata-appUITests
```

## データモデル構造

現在のデータモデルは `Item.swift` の基本的なテンプレートですが、要件に基づいて以下のモデルに拡張予定：

- **Image**: 画像データと関連メタデータ
- **Tag**: 定義済み6つのタグ（列挙型）
- **Title**: タイトル（ユーザー定義、必須）
- **MissList**: ミスリスト項目

## プロジェクト構造

- `oyakata-app/`: メインアプリケーションコード
  - `oyakata_appApp.swift`: アプリエントリーポイント、SwiftDataコンテナ設定
  - `ContentView.swift`: メインビュー（SwiftDataクエリ使用）
  - `Item.swift`: データモデル定義
- `oyakata-appTests/`: ユニットテスト
- `oyakata-appUITests/`: UIテスト

## 開発時の注意点

- SwiftDataの `@Model` を使用してデータモデルを定義
- `@Query` を使用してSwiftDataからデータを取得
- `modelContext` を使用してデータの挿入・削除・更新を実行
- Apple Pencil対応のためPencilKitフレームワークの追加が必要
- 画像処理とファイル管理の実装が重要
- テストは XCTest フレームワークを使用