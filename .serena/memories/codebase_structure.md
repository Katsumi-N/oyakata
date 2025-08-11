# コードベース構造

## ディレクトリ構成

### メインディレクトリ
- `oyakata-app/`: メインアプリケーションコード
  - `oyakata_appApp.swift`: アプリエントリーポイント、SwiftDataコンテナ設定
  - `ContentView.swift`: メインTabView（図面一覧、ミスリスト）
  - `Item.swift`: 旧データモデル（現在は使用されていない可能性）

### Modelsディレクトリ (`oyakata-app/Models/`)
- `ImageData.swift`: 画像データのメインモデル（SwiftData）
- `TagType.swift`: タグの列挙型定義（4種類のタグ）
- `TaskName.swift`: タスク名モデル
- `MissListItem.swift`: ミスリストアイテムモデル
- `TimeRecord.swift`: 時間記録モデル
- `MigrationManager.swift`: データベースマイグレーション管理

### Viewsディレクトリ (`oyakata-app/Views/`)
- `ImageGridView.swift`: 画像一覧表示（メイン画面）
- `ImageDetailView.swift`: 画像詳細表示
- `ImageEditView.swift`: 画像編集機能
- `ImagePickerView.swift`: 画像選択UI
- `GroupDetailView.swift`: グループ詳細表示
- `MissListView.swift`: ミスリスト表示
- `TimeRecordEditView.swift`: 時間記録編集
- `Views/Components/`: 再利用可能なコンポーネント

### テストディレクトリ
- `oyakata-appTests/`: ユニットテスト
  - `oyakata_appTests.swift`: テストクラス（基本テンプレート）
- `oyakata-appUITests/`: UIテスト
  - `oyakata_appUITests.swift`: UIテストメイン
  - `oyakata_appUITestsLaunchTests.swift`: 起動テスト

### ドキュメント (`docs/`)
- `requirements.md`: 機能要件・非機能要件
- `architecture.md`: アーキテクチャ設計
- `miss-list.md`: ミスリスト機能の詳細仕様
- `development.md`: 開発ガイド（推測）

### その他
- `CLAUDE.md`: プロジェクト指示書（Claude Code用）
- `oyakata-app.xcodeproj/`: Xcodeプロジェクトファイル

## データモデル関係
- `ImageData` が中心的なモデル
- `TaskName` との関係（多対一）
- `MissListItem` との関係（一対多、カスケード削除）
- `TimeRecord` との関係（一対一、カスケード削除）
- グループ化機能によりImageData同士を関連付け