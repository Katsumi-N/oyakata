# コードスタイルと規約

## Swift/SwiftUIコーディング規約

### 命名規約
- **クラス・構造体**: PascalCase（例: `ImageGridView`, `ImageData`）
- **変数・関数**: camelCase（例: `showingImagePicker`, `deleteGroup`）
- **定数**: camelCase（例: `maxDimension`）
- **列挙型ケース**: camelCase（例: `questionPaper`, `answerExample`）

### ファイル構成
- 1ファイル1主要コンポーネント
- 関連する小さなヘルパー構造体は同じファイルに含める（例: `SearchBar`, `FilterChip`など）
- プライベートメソッドは `private func` で定義

### SwiftUIビューの構造
```swift
struct ViewName: View {
    // Environment/Query プロパティ
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [ItemType]
    
    // State プロパティ
    @State private var stateProperty = false
    
    // Computed プロパティ
    var computedProperty: Type {
        // 実装
    }
    
    var body: some View {
        // UI実装
    }
    
    // プライベートメソッド
    private func helperMethod() {
        // 実装
    }
}
```

### SwiftDataモデル
- `@Model` アノテーションを使用
- `final class` で定義
- リレーションシップは `@Relationship` で定義
- 削除ルール（`deleteRule`）を明示的に指定

### コメント規約
- 日本語コメントを使用
- 複雑なロジックには詳細な説明を記載
- TODOコメントは適切に使用

### エラーハンドリング
- `do-catch` ブロックを使用
- エラーは `print()` でコンソールに出力
- ユーザー向けエラーメッセージは日本語

### リソース管理
- 画像はドキュメントディレクトリに保存
- ファイル削除時は適切にクリーンアップ
- メモリ効率を考慮した画像読み込み（ダウンサンプリング）

## アーキテクチャパターン
- **MVVM**: ViewとModelを分離
- SwiftDataの `@Query` でデータバインディング
- Environmentを通じた依存性注入