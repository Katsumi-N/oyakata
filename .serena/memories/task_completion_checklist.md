# タスク完了時のチェックリスト

## 開発タスク完了後に実行すべきこと

### 1. ビルドテスト
タスク完了後は必ずビルドが成功することを確認する：

```bash
# iPhone Simulatorでビルドテスト
xcodebuild -project oyakata-app.xcodeproj -scheme oyakata-app -destination 'platform=iOS Simulator,name=iPhone 15' build

# iPad Simulatorでもテスト（レスポンシブ対応のため）
xcodebuild -project oyakata-app.xcodeproj -scheme oyakata-app -destination 'platform=iOS Simulator,name=iPad Air (5th generation)' build
```

### 2. テスト実行
既存機能が破綻していないことを確認：

```bash
# ユニットテスト実行
xcodebuild test -project oyakata-app.xcodeproj -scheme oyakata-app -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:oyakata-appTests

# UIテスト実行（重要な機能変更の場合）
xcodebuild test -project oyakata-app.xcodeproj -scheme oyakata-app -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:oyakata-appUITests
```

### 3. コード品質チェック
- SwiftDataモデルの整合性確認
- メモリリークがないか確認（特に画像処理部分）
- エラーハンドリングが適切に実装されているか確認
- 日本語コメントが適切に記載されているか確認

### 4. 機能テスト（手動）
- 新機能が正常に動作することを確認
- 既存機能に影響がないことを確認
- iPhone/iPad両方でのレスポンシブ動作確認
- Apple Pencil機能（該当する場合）の動作確認

### 5. データ整合性確認
SwiftDataを使用しているため、以下を確認：
- データマイグレーションが正常に動作すること
- リレーションシップが正しく維持されること
- カスケード削除が適切に動作すること

### 6. パフォーマンステスト
- 大量の画像データでの動作確認
- スムーズなスクロール性能
- 適切な画像最適化（2048px制限）

## 注意事項
- **リント/フォーマットツールなし**: このプロジェクトにはSwiftLintやSwiftFormatは設定されていないため、手動でコード品質を確認
- **コミット前確認**: 変更をコミットする前に必ずビルドとテストが通ることを確認
- **バックアップ**: 重要なデータ変更を伴う場合は、事前にバックアップを推奨

## ビルドエラーが発生した場合
1. Xcode DerivedDataをクリア: `rm -rf ~/Library/Developer/Xcode/DerivedData`
2. Simulatorリセット: `xcrun simctl erase all`
3. Xcodeで再ビルド