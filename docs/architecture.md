## アーキテクチャ
##　画像配信
- CDN に Cloudflare Images を採用する。
- 画像は S3 に保存
- 画像保存 / 取得 API は AWS ECS にホスティングする
  - Go で実装する’z

## 認証機能
認証機能は Supabase Auth を使用する

