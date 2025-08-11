# 推奨開発コマンド

## プロジェクト管理

### プロジェクトを開く
```bash
# Xcodeでプロジェクトを開く
open oyakata-app.xcodeproj
```

## ビルドとテスト

### ビルド
```bash
# iPhone 15 Simulatorでビルド
xcodebuild -project oyakata-app.xcodeproj -scheme oyakata-app -destination 'platform=iOS Simulator,name=iPhone 15' build

# iPad Simulatorでビルド
xcodebuild -project oyakata-app.xcodeproj -scheme oyakata-app -destination 'platform=iOS Simulator,name=iPad Air (5th generation)' build
```

### テスト実行
```bash
# 全テスト実行
xcodebuild test -project oyakata-app.xcodeproj -scheme oyakata-app -destination 'platform=iOS Simulator,name=iPhone 15'

# 特定のテストクラス実行
xcodebuild test -project oyakata-app.xcodeproj -scheme oyakata-app -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:oyakata-appTests/oyakata_appTests

# UIテスト実行
xcodebuild test -project oyakata-app.xcodeproj -scheme oyakata-app -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:oyakata-appUITests
```

## 開発用コマンド

### ファイル管理
```bash
# プロジェクト構造確認
find . -name "*.swift" -not -path "./.build/*" | head -20

# Swiftファイル検索
find oyakata-app -name "*.swift" -exec basename {} \;
```

### Git操作
```bash
# 現在のブランチとステータス確認
git status
git branch

# 変更確認
git diff
git log --oneline -10
```

## システムコマンド（Darwin/macOS）

### 基本操作
```bash
# ディレクトリ一覧（macOS版ls）
ls -la
ls -laG  # カラー表示

# ファイル検索
find . -name "*.swift" -type f

# テキスト検索
grep -r "searchterm" oyakata-app/ --include="*.swift"

# ディスク使用量
du -sh .
```

### Xcode関連
```bash
# Xcodeキャッシュクリア
rm -rf ~/Library/Developer/Xcode/DerivedData

# Simulatorリセット
xcrun simctl erase all
```

## 注意点
- このプロジェクトにはSwiftLintやSwiftFormatの設定は含まれていない
- コードフォーマットはXcodeの標準機能を使用
- テスト実行前にSimulatorが起動していることを確認