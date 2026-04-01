## 0.1.0

- 初回リリース
- `pubspec.lock` の存在チェック（LockFileChecker）
- `pubspec.yaml` のバージョン制約チェック（ConstraintChecker）
- 公開から 3 日以内のパッケージを警告する新規バージョンチェック（NewVersionChecker）
- 前バージョンとの依存差分によるサプライチェーン攻撃検出（DepDiffChecker）
- コンソール出力（カラー対応）と JSON 出力に対応
- 問題あり時の終了コード 1、なし時の終了コード 0
