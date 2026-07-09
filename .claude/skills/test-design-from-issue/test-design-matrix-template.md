# テスト設計マトリクステンプレート（結合テスト・RTM）

単体テストマトリクスの様式は [unit-test-from-design/unit-test-matrix-template.md](../unit-test-from-design/unit-test-matrix-template.md) を参照する。本ファイルは **結合テストマトリクス** と **トレーサビリティマトリクス（RTM）** の様式を示す。

## 凡例

| 略号 | 正式名称 | 補足 |
| --- | --- | --- |
| TC-XXX | 単体テストケース ID | 3 桁ゼロ埋め |
| IT-XXX | 結合テストケース ID | 3 桁ゼロ埋め |
| AC-XXX | 受け入れ条件 | 要件定義 `functional/*.md` で定義 |
| IMPL-XX | 実装内容項目 | AC が無い基盤 Issue で設計書「実装内容」を観点化した一時 ID |
| BR-XXX | 業務ルール | 要件定義 `業務ルール.md` で定義 |

---

## 結合テストマトリクス（docs/test/結合テストマトリクス.md）

Job 全体実行・Step 間連携・Testcontainers（実 DB）での永続化確認を IT-XXX で採番する。単体（モック）と E2E の中間層を埋める。

| IT-ID | 対応 AC / 実装内容項目 | 結合範囲（操作） | Job名 / Step名 | 区分 | シナリオ | 期待結果 |
| --- | --- | --- | --- | --- | --- | --- |
| IT-001 | AC-001 | Job 全体実行（JobLauncher→Job→Step→DB） | xxxJob | 正常系 | 有効入力データで Job 実行 | COMPLETED / DB に永続化 |
| IT-002 | AC-002 | Step スキップ発動 | xxxJob / processStep | スキップ | 不正データ混入で skip 発動 | COMPLETED / スキップカウント=1 |

### 当該 Issue で結合テストを後続送りにする場合

| IT-ID | 区分 | 対象 | 理由 |
| --- | --- | --- | --- |
| — | 対象外 | 共通バッチ部品（JobConfig 基底クラス等） | 結合点は後続 Job Issue で @SpringBatchTest + Testcontainers で検証する |

---

## トレーサビリティマトリクス / RTM（docs/test/トレーサビリティマトリクス.md）

要件→設計→Issue→テストを 1 表に集約し、横串でカバレッジ漏れを検出する正典。Issue 起票・実装ループで更新する。

| UC | AC / 実装内容項目 | BR | Job名・Step名 | Issue# | TC-XXX | IT-XXX | E2E-XXX |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UC-001 | AC-001 | BR-002 | xxxJob / processStep | #12 | TC-001, TC-002 | IT-001 | — |
| —（基盤） | IMPL-01 JobConfig 基盤 | — | — | #4 | TC-001〜TC-005 | 対象外 | — |

- AC が無い基盤 Issue は「AC / 実装内容項目」列に実装内容項目（IMPL-XX ＋ 項目名）を入れ、空欄にしない。
- E2E は現環境では別工程のため `—` を入れてよい。
