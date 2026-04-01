# pub_sentinel

**pub_sentinel** は Dart/Flutter プロジェクトのサプライチェーン攻撃やリスクのある依存パッケージの変更を検出するセキュリティスキャナです。

[![pub package](https://img.shields.io/pub/v/pub_sentinel.svg)](https://pub.dev/packages/pub_sentinel)

## 機能

- **ロックファイルチェック** — `pubspec.lock` が存在しない場合に警告します。ロックファイルがないと、環境によって異なるバージョンがインストールされる可能性があります。
- **バージョン制約チェック** — `any`・空文字・`>=0.0.0` などの無制限な制約を検出します。任意のバージョンが解決される恐れがあります。
- **新規バージョンチェック** — 公開から 3 日以内のパッケージを警告します。公開直後はセキュリティ審査が十分でない可能性があります。
- **依存差分チェック** — ロックされた各パッケージの依存リストを前バージョンと比較し、突然追加された依存を検出します。これはサプライチェーン攻撃の典型的なパターンです。

## インストール

```sh
dart pub global activate pub_sentinel
```

または dev_dependencies に追加：

```yaml
dev_dependencies:
  pub_sentinel: ^0.1.0
```

## 使い方

Dart/Flutter プロジェクトのルートディレクトリでスキャンを実行します：

```sh
pub-sentinel
```

特定のディレクトリを指定する場合：

```sh
pub-sentinel --path /path/to/your/project
```

### オプション

| フラグ / オプション | 短縮形 | デフォルト | 説明 |
|---|---|---|---|
| `--path` | `-p` | `.` | スキャン対象のプロジェクトディレクトリ |
| `--format` | `-f` | `console` | 出力フォーマット：`console` または `json` |
| `--no-color` | | | カラー出力を無効化 |
| `--verbose` | `-v` | | スキャン中の進捗メッセージを表示 |
| `--help` | `-h` | | ヘルプを表示 |

### コンソール出力の例

```
✗ CRITICAL  [some_package] v1.2.3 で不審な依存パッケージが追加されました: shady_lib
             前バージョン (v1.2.2) にはなかった依存が追加されています。…
⚠ WARNING   [another_pkg] v0.9.1 は公開から 4 時間しか経っていません
ℹ INFO      [big_package] v2.0.0 で依存パッケージが追加されました: compat_shim

3 件の問題が見つかりました (critical: 1, warning: 1, info: 1)
```

### JSON 出力の例

```sh
pub-sentinel --format json
```

```json
[
  {
    "package": "some_package",
    "severity": "critical",
    "message": "v1.2.3 で不審な依存パッケージが追加されました: shady_lib",
    "detail": "前バージョン (v1.2.2) にはなかった依存が追加されています。..."
  }
]
```

### 終了コード

| コード | 意味 |
|---|---|
| `0` | 問題なし |
| `1` | `warning` または `critical` の問題が 1 件以上ある |
| `2` | 引数が不正、またはプロジェクトパスが見つからない |

## CI との連携

```yaml
# GitHub Actions の例
- name: pub-sentinel を実行
  run: |
    dart pub global activate pub_sentinel
    pub-sentinel --format json > sentinel-report.json
```

## 動作要件

- Dart SDK `>=3.0.0`
- [pub.dev](https://pub.dev) API へのインターネットアクセス（新規バージョンチェック・依存差分チェックで使用）

## コントリビューション

バグ報告やプルリクエストは [GitHub](https://github.com/manami-shindo/pub_sentinel) までお寄せください。

## ライセンス

MIT ライセンスのもとで公開されています。詳細は [LICENSE](LICENSE) ファイルを参照してください。
