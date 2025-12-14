# 画像最適化機能 実装計画

## 概要

現在完全ローカルストレージのアプリに、Cloudflare Workers + R2による画像の外部ストレージ機能を追加します。

**主な変更点：**
- 新規画像を3サイズ（thumbnail: 300px, medium: 1024px, large: 2048px）で外部保存
- ローカルにはthumbnailのみ保存してストレージを削減
- 既存のローカル画像はそのまま維持（移行なし）
- アップロード失敗時はローカル保存のみ、バックグラウンドで再試行

## アーキテクチャ

### レイヤー構造
```
Network Layer (APIClient, APIEndpoint, NetworkError)
    ↓
Auth Layer (AuthManager, KeychainManager)
    ↓
Image Service Layer (ImageUploadManager, ImageCacheManager, ImageSizeGenerator, ImageStorageStrategy)
    ↓
View Layer (ImagePickerView, ImageGridView, ImageDetailView)
```

### データフロー

**アップロード:**
1. ユーザーが画像を選択 (ImagePickerView)
2. 3サイズを生成 (ImageSizeGenerator)
3. thumbnailをローカル保存 (ImageCacheManager)
4. 認証トークン取得 (AuthManager)
5. アップロードURL取得 → R2へPUT (ImageUploadManager)
6. メタデータ更新 (ImageData)

**表示:**
1. thumbnail: ローカルから読み込み
2. medium/large: リモートから取得 → キャッシュ
3. 既存画像: 従来通りローカルから読み込み

## 新規作成ファイル

### 1. Config
- `oyakata-app/Config/APIConfig.swift` - API基本設定（BaseURL等）

### 2. Network Layer
- `oyakata-app/Services/Network/APIClient.swift` - HTTPリクエスト処理
- `oyakata-app/Services/Network/APIEndpoint.swift` - エンドポイント定義
- `oyakata-app/Services/Network/NetworkError.swift` - ネットワークエラー型

### 3. Auth Layer
- `oyakata-app/Services/Auth/AuthManager.swift` - 認証管理・トークンリフレッシュ
- `oyakata-app/Services/Auth/KeychainManager.swift` - Keychain操作

### 4. Image Service Layer
- `oyakata-app/Services/Image/ImageUploadManager.swift` - アップロードオーケストレーション
- `oyakata-app/Services/Image/ImageCacheManager.swift` - ローカルキャッシュ管理
- `oyakata-app/Services/Image/ImageSizeGenerator.swift` - 3サイズ生成
- `oyakata-app/Services/Image/ImageStorageStrategy.swift` - 画像取得戦略（ローカル/リモート判定）

### 5. Dependency Injection
- `oyakata-app/Services/ServiceLocator.swift` - 依存性管理

## 既存ファイルの変更

### 1. Models/ImageData.swift
新規プロパティ追加：
```swift
var remoteImageId: String?              // 外部画像ID
var uploadStatus: ImageUploadStatus     // アップロード状態
var uploadedAt: Date?                   // アップロード日時
var lastUploadAttempt: Date?            // 最後の試行日時
var uploadRetryCount: Int = 0           // 再試行回数
var storedSizes: [ImageSize] = []       // ローカル保存サイズ
```

新規Enum定義：
```swift
enum ImageUploadStatus: String, Codable {
    case localOnly, uploading, completed, failed, retryScheduled
}

enum ImageSize: String, Codable {
    case thumbnail, medium, large
}
```

### 2. Views/ImagePickerView.swift
`saveImageToDocuments()`メソッドに変更：
- ローカル保存後にバックグラウンドでアップロード処理を追加
- `ServiceLocator.shared.imageUploadManager.uploadImage()`を呼び出し
- エラー時もローカル保存は維持（ユーザー体験を損なわない）

### 3. Views/ImageGridView.swift
サムネイル表示ロジックを変更：
- `ImageStorageStrategy.getImage()`を使用
- リモート画像とローカル画像を透過的に扱う
- 読み込み中のProgressView表示

### 4. oyakata_appApp.swift
アプリ起動時の処理追加：
- 失敗したアップロードの再試行をバックグラウンドで実行
- `ImageUploadManager.retryFailedUploads()`を呼び出し

## 実装ステップ

### Phase 1: 基盤レイヤー（Network + Auth）

#### Step 1.1: APIConfig作成
- BaseURL、タイムアウト設定
- 環境変数は将来的に対応（現在はハードコード）

#### Step 1.2: NetworkError作成
- エラー型定義（unauthorized, tokenExpired, nonceReused等）
- APIErrorResponse構造体定義

#### Step 1.3: APIEndpoint作成
- 5つのエンドポイント定義（register, refresh, uploadURL, getImage, deleteImage）
- HTTPメソッド、パス、クエリパラメータ、ボディを構造化

#### Step 1.4: APIClient作成
- ジェネリックなrequestメソッド実装
- エラーレスポンスのパース
- R2へのPUTリクエスト処理

#### Step 1.5: KeychainManager作成
- deviceId/deviceSecretの保存・読み込み・削除
- tokenExpiryの保存・読み込み
- Security frameworkを使用

#### Step 1.6: AuthManager作成
- `ensureAuthenticated()` - トークンの自動取得・リフレッシュ
- `register()` - デバイス登録
- `refreshToken()` - トークン更新
- `isTokenExpired()` - 期限チェック（5分前にバッファ）

### Phase 2: Image Service Layer

#### Step 2.1: ImageSizeGenerator作成
- `generateSizes()` - 3サイズを並列生成（TaskGroup使用）
- `resize()` - アスペクト比を保持してリサイズ
- JPEG圧縮品質: thumbnail 0.7, medium 0.8, large 0.85

#### Step 2.2: ImageCacheManager作成
- `saveThumbnail()` - Documents/Thumbnails/にサムネイル保存
- `loadThumbnail()` - メモリキャッシュ → ディスクキャッシュの順で取得
- `loadImage()` - 任意サイズの画像をキャッシュから取得
- NSCacheでメモリキャッシュ、Caches/ImageCache/でディスクキャッシュ

#### Step 2.3: ImageUploadManager作成
- `uploadImage()` - メイン処理
  1. uploadStatusを`.uploading`に更新
  2. 3サイズ生成
  3. thumbnailをローカル保存
  4. 各サイズをR2にアップロード（nonce生成含む）
  5. 成功時: `.completed`、失敗時: `.failed`に更新
- `retryFailedUploads()` - 失敗したアップロードをバックグラウンド再試行

#### Step 2.4: ImageStorageStrategy作成
- `getImage()` - 画像取得のメインロジック
  - thumbnail: ローカル優先
  - remoteImageId == nil: 既存ローカル画像（互換性）
  - remoteImageId != nil: リモートから取得 → キャッシュ
- `deleteRemoteImage()` - リモート画像削除（DELETE /v1/images/:imageId）

#### Step 2.5: ServiceLocator作成
- シングルトンパターンでサービスインスタンス管理
- 依存性注入の中心

### Phase 3: データモデル更新

#### Step 3.1: ImageData拡張
- 新規プロパティ追加（remoteImageId, uploadStatus等）
- 新規Enum追加（ImageUploadStatus, ImageSize）
- 計算プロパティ追加（isRemoteAvailable, thumbnailPath）

#### Step 3.2: SwiftData Schema更新
- `oyakata_appApp.swift`のschemaは自動更新（@Modelマクロ）
- マイグレーションは不要（新規プロパティはOptionalまたはデフォルト値あり）

### Phase 4: View Layer統合

#### Step 4.1: ImagePickerView変更
- `saveImageToDocuments()`の最後にアップロード処理追加
- Task.detachedでバックグラウンド実行
- エラーハンドリング（printのみ、UIには影響させない）

#### Step 4.2: ImageGridView変更
- `ImageGridItemView`にサムネイル読み込み処理追加
- `.task {}`でImageStorageStrategyから取得
- ProgressView表示

#### Step 4.3: ImageDetailView変更（オプション）
- medium/large取得時にImageStorageStrategyを使用
- ローカル画像との互換性を維持

### Phase 5: アプリ起動時の処理

#### Step 5.1: oyakata_appApp.swift変更
- `init()`でバックグラウンド再試行処理を追加
- `Task { await ServiceLocator.shared.imageUploadManager.retryFailedUploads() }`

## データモデル詳細

### ImageData新規プロパティ

| プロパティ | 型 | デフォルト | 説明 |
|----------|-----|----------|------|
| remoteImageId | String? | nil | 外部ストレージのULID/UUIDv7 |
| uploadStatus | ImageUploadStatus | .localOnly | アップロード状態 |
| uploadedAt | Date? | nil | アップロード完了日時 |
| lastUploadAttempt | Date? | nil | 最後のアップロード試行日時 |
| uploadRetryCount | Int | 0 | 再試行回数 |
| storedSizes | [ImageSize] | [] | ローカル保存サイズリスト |

### ImageUploadStatus

- `.localOnly` - ローカルのみ（未アップロード）
- `.uploading` - アップロード中
- `.completed` - アップロード完了
- `.failed` - アップロード失敗（再試行可能）
- `.retryScheduled` - 再試行予定

### ImageSize

- `.thumbnail` - 300px（必ずローカル保存）
- `.medium` - 1024px（リモートのみ）
- `.large` - 2048px（リモートのみ）

## 認証フロー

### 初回起動時
1. デバイス登録: `POST /v1/anonymous/register`
2. Keychainに保存: deviceId, deviceSecret, expiresAt
3. 以降のリクエストで使用: `Authorization: Bearer {deviceId}.{deviceSecret}`

### トークンリフレッシュ
- 有効期限24時間
- 5分前にリフレッシュ（バッファ）
- `POST /v1/auth/refresh` で新しいトークン取得
- 期限切れトークンでもリフレッシュは可能

### nonce管理
- State-changing操作（uploadURL取得等）で必須
- `UUID().uuidString`で生成
- サーバー側で5分間保持、再利用時はエラー

## エラーハンドリング

### アップロード失敗時
1. `uploadStatus`を`.failed`に設定
2. `uploadRetryCount`をインクリメント
3. `lastUploadAttempt`を記録
4. ローカル保存は維持（ユーザーには影響なし）

### 再試行戦略
- アプリ起動時にバックグラウンドで実行
- 指数バックオフ: 1分、5分、15分
- 最大3回まで再試行
- ネットワーク状態を確認してから実行

### オフライン時
- thumbnail: ローカルから即座に表示
- medium/large: 「画像を読み込めません」と表示
- アップロードは自動的に失敗 → 再試行キューに追加

## 互換性・移行戦略

### 既存ローカル画像の扱い
- `remoteImageId == nil`で既存画像と判定
- `ImageStorageStrategy.getImage()`で自動的に従来の`imageData.image`を使用
- UIでの区別は不要（透過的に処理）

### 削除時の処理
- `remoteImageId != nil`: リモート画像も削除
- `remoteImageId == nil`: ローカルのみ削除（従来通り）

### 段階的移行
- Phase 1（本実装）: 新規画像のみ外部保存
- Phase 2（将来）: 既存画像の移行UI追加（オプション）

## セキュリティ

### 認証
- Bearer トークン認証（deviceId.deviceSecret）
- Keychainで安全に保存
- トークン期限管理（24時間）

### nonce
- リプレイ攻撃防止
- UUID v4で一意性保証
- サーバー側で再利用チェック

### 通信
- HTTPS必須（Cloudflare Workers）
- R2への署名付きURL（SigV4）

## テスト

### ユニットテスト（推奨）
- AuthManager: トークン管理ロジック
- ImageSizeGenerator: リサイズ精度
- ImageCacheManager: キャッシュ読み書き

### 統合テスト（推奨）
- エンドツーエンドアップロード
- オフライン時の挙動
- トークンリフレッシュ

### 手動テスト（必須）
- 新規画像アップロード → thumbnail表示
- medium/large取得
- オフライン時の挙動
- アップロード失敗 → 再試行

## 実装上の注意点

### 1. Swift Concurrency
- `async/await`を全面的に使用
- `@MainActor`でUI更新を明示的にメインスレッドで実行
- `Task.detached`でバックグラウンド処理

### 2. SwiftDataとの連携
- `modelContext`はMainActorで実行必須
- バックグラウンドスレッドからの更新は`await MainActor.run {}`で囲む

### 3. メモリ管理
- NSCacheで自動メモリ管理
- 大きな画像はダウンサンプリング
- TaskGroupで並列処理

### 4. エラーハンドリング
- ネットワークエラーはユーザー体験を損なわない
- ローカル保存を優先
- ログは詳細に、UIには影響させない

### 5. API仕様準拠
- 日付のISO8601フォーマット（`JSONDecoder.dateDecodingStrategy`）
- Content-Typeヘッダー必須（R2 PUT時）
- クエリパラメータでリサイズ（`w`パラメータ）

## クリティカルファイル

実装時に特に注意が必要なファイル：

1. **oyakata-app/Models/ImageData.swift** - データモデルの拡張、マイグレーション影響なし
2. **oyakata-app/Services/Auth/AuthManager.swift** - 認証の中核、トークン管理ロジック
3. **oyakata-app/Services/Image/ImageUploadManager.swift** - アップロードフロー全体
4. **oyakata-app/Services/Network/APIClient.swift** - すべてのHTTPリクエストの基盤
5. **oyakata-app/Views/ImagePickerView.swift** - アップロード処理統合、ユーザー体験への影響

## API仕様リファレンス

詳細は`docs/image-optimization.md`を参照。

主要エンドポイント：
- `POST /v1/anonymous/register` → deviceId, deviceSecret
- `POST /v1/auth/refresh` → 新しいdeviceSecret
- `POST /v1/images/upload-url` (+ nonce) → uploadUrl, imageId
- `PUT {uploadUrl}` (+ Content-Type) → R2に画像保存
- `GET /v1/images/:imageId?w=300` → 画像バイナリ
- `DELETE /v1/images/:imageId` → 削除

認証ヘッダー: `Authorization: Bearer {deviceId}.{deviceSecret}`
