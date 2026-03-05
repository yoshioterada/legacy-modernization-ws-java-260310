# 環境構築・ビルド・動作確認 手順書

## 1. アプリケーション概要

| 項目                     | 内容                             |
| ------------------------ | -------------------------------- |
| アプリケーション名       | Legacy Bookstore Application     |
| フレームワーク           | Struts 1.3.10 / Hibernate 3.6.10 |
| ビルドツール             | Apache Ant（Docker 内で実行）    |
| アプリケーションサーバー | Apache Tomcat 9                  |
| データベース             | MySQL 5.7                        |

---

## 2. 前提条件（共通）

- **Docker Desktop** がインストールされ、起動していること
- **Git** がインストールされていること
- ポート **8080**（アプリケーション）と **3306**（MySQL）が空いていること

> **注意**: ソースコードのビルドは Docker のマルチステージビルドで行うため、ローカルに JDK や Ant をインストールする必要はありません。

---

## 3. 環境別セットアップ

### 3.1 Mac（Apple Silicon / Intel）

#### Mac の事前準備

1. **Docker Desktop for Mac** をインストール
   - <https://www.docker.com/products/docker-desktop/> からダウンロード
   - インストール後、Docker Desktop を起動し、
     ステータスバーに Docker アイコンが表示されることを確認

2. Docker が正常に動作することを確認

   ```bash
   docker --version
   docker compose version
   ```

3. リポジトリをクローン

   ```bash
   git clone <リポジトリURL>
   cd legacy-modernization-ws-java-260310
   ```

#### Mac でのビルド・起動

```bash
docker compose -f docker-compose-mac.yml up --build
```

> **補足**: Mac 版では MySQL 5.7 の ARM64 イメージが存在しないため、
> `platform: linux/amd64` を指定してエミュレーション実行します。
> 初回起動時は Docker イメージのダウンロードにより時間がかかります。

---

### 3.2 Windows

#### Windows の事前準備

1. **Docker Desktop for Windows** をインストール
   - <https://www.docker.com/products/docker-desktop/> からダウンロード
   - インストール時に **WSL 2 バックエンド** を有効にする（推奨）
   - インストール後、Docker Desktop を起動

2. **WSL 2** が有効であることを確認（PowerShell を管理者として実行）

   ```powershell
   wsl --status
   ```

   WSL 2 が未インストールの場合:

   ```powershell
   wsl --install
   ```

3. Docker が正常に動作することを確認（PowerShell またはコマンドプロンプト）

   ```powershell
   docker --version
   docker compose version
   ```

4. リポジトリをクローン

   ```powershell
   git clone <リポジトリURL>
   cd legacy-modernization-ws-java-260310
   ```

#### Windows でのビルド・起動

```powershell
docker compose -f docker-compose-win.yml up --build
```

---

## 4. 動作確認

### 4.1 起動確認

コンテナが正常に起動すると、ログに以下のようなメッセージが表示されます:

```text
legacy-mysql      | ... [Note] mysqld: ready for connections.
legacy-bookstore  | ... Deployment of web application archive ... has finished
```

### 4.2 ブラウザでアクセス

ブラウザで以下の URL にアクセスしてください:

| 画面         | URL                                      |
| ------------ | ---------------------------------------- |
| ログイン画面 | <http://localhost:8080/login.do>         |
| ホーム画面   | <http://localhost:8080/home.do>          |

### 4.3 テスト用アカウント

| ユーザー名 | パスワード | ロール  |
| ---------- | ---------- | ------- |
| admin      | admin123   | ADMIN   |
| manager    | manager123 | MANAGER |
| clerk      | clerk123   | CLERK   |

---

## 5. よく使うコマンド

### 起動（バックグラウンド実行）

```bash
# Mac
docker compose -f docker-compose-mac.yml up --build -d

# Windows
docker compose -f docker-compose-win.yml up --build -d
```

### ログ確認

```bash
# 全サービスのログ
docker compose -f docker-compose-mac.yml logs -f

# アプリケーションのログのみ
docker compose -f docker-compose-mac.yml logs -f app

# MySQL のログのみ
docker compose -f docker-compose-mac.yml logs -f legacy-mysql
```

> Windows の場合は `-mac.yml` を `-win.yml` に読み替えてください。

### 停止

```bash
docker compose -f docker-compose-mac.yml down
```

### 停止 + データ削除（DB を初期化したい場合）

```bash
docker compose -f docker-compose-mac.yml down -v
```

### 再ビルド（ソースコード変更後）

```bash
docker compose -f docker-compose-mac.yml up --build
```

### コンテナの状態確認

```bash
docker compose -f docker-compose-mac.yml ps
```

### MySQL に直接接続

```bash
docker exec -it legacy-mysql mysql -u legacy_user -plegacy_pass legacy_db
```

---

## 6. トラブルシューティング

### ポートが既に使用されている

```text
Bind for 0.0.0.0:8080 failed: port is already allocated
```

ポート 8080 または 3306 を使用しているプロセスを停止してください:

```bash
# Mac: ポートを使用しているプロセスを確認
lsof -i :8080

# Windows (PowerShell):
netstat -ano | findstr :8080
```

### MySQL の初期化をやり直したい

DB ボリュームを削除して再起動してください:

```bash
docker compose -f docker-compose-mac.yml down -v
docker compose -f docker-compose-mac.yml up --build
```

### Docker イメージのキャッシュをクリアしたい

```bash
docker compose -f docker-compose-mac.yml build --no-cache
docker compose -f docker-compose-mac.yml up
```

---

## 7. プロジェクト構成

```text
.
├── Dockerfile                  # マルチステージビルド定義
├── docker-compose-mac.yml      # Mac 用 Docker Compose
├── docker-compose-win.yml      # Windows 用 Docker Compose
├── build.xml                   # Ant ビルドスクリプト
├── config/
│   └── mysql/
│       ├── 01-create-tables.sql   # テーブル作成 SQL
│       └── 02-seed-data.sql       # 初期データ投入 SQL
├── lib/                        # 外部ライブラリ（Docker 内で自動ダウンロード）
└── src/
    └── main/
        ├── java/               # Java ソースコード
        ├── resources/          # Hibernate 設定等
        └── webapp/             # JSP / CSS / JS / WEB-INF
```
