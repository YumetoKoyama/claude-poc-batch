---
name: test-design-from-issue
description: 採択済み Issue とバッチ設計書から、製造フェーズのテスト設計成果物（単体テストマトリクス・トレーサビリティマトリクス/RTM）を docs/test/ に生成・更新するときに使う。テスト「設計（ケース化）」専用で、テスト「実施（実行）」は対象外。結合テストは別工程（/integration-test-from-design）。製造フェーズの必須サブステップ。
context: fork
argument-hint: <ISSUE-NUMBER> [draft|finalize]
---

# Issue・バッチ設計書からテスト設計（マトリクス）を作成する

> **責務の切り分け**: 本スキルは **テスト「設計（ケース化）」** だけを担う。テスト実施（実行・カバレッジ取得）は別責務。**結合テストは設計・実施とも別工程**（`/integration-test-from-design`）。

> **パス解決（マルチリポジトリ対応）**:
> - **読み取り入力（docs リポジトリ）**: `docs/requirements/`・`docs/design/` は docs ルート相対。親アンブレラからなら `claude-poc-docs/` を前置。
> - **書き込み出力（own リポジトリ）**: `docs/test/` は own リポジトリのワーキングツリー直下。feature ブランチへ commit/push して PR に含める。

> **呼び出し元**: `/implement-from-issue` から 2 タッチで呼ばれる（手順3.5 で `draft`、手順5.5 で `finalize`）。

## モード（2 タッチ）

| モード | 呼び出し位置 | 実コードとの突合 | ハードゲート |
| --- | --- | --- | --- |
| `draft` | 実装と**並行** | しない（計画ケースのみ） | スキップ |
| `finalize` | 実装・テスト実施の**後** | する（テストメソッドと TC を突合・件数一致） | **必須** |

対象 Issue: $ARGUMENTS

## 手順

### 1. 入力の収集とテスト観点の確定

1. `gh issue view <ISSUE> --json number,title,body,labels` で Issue を取得し、受け入れ条件 AC-XXX・Job 名・Step 名・BR-XXX を抽出する。
2. `docs/design/バッチ設計.md` と関連 `docs/design/tables/*.md` を読み、テスト対象クラス・メソッド・分岐・スキップ/リトライ条件・例外を特定する。
3. **AC-XXX が無い共通基盤 Issue**: 設計書の「実装内容」項目をテスト観点として採用し、各項目を `IMPL-XX` として列挙してから TC-XXX を採番する。RTM の「AC」列に実装内容項目 ID を入れ、空欄にしない。

### 2. 単体テストマトリクスの作成（TC-XXX）

`docs/test/単体テストマトリクス.md` を [unit-test-matrix-template.md](../unit-test-from-design/unit-test-matrix-template.md) の様式で作成または更新する。

- 各テストケースに **TC-XXX（3 桁ゼロ埋め）** を採番し、対応する AC-XXX（または IMPL-XX）・BR-XXX を紐付ける。
- 「区分」は **正常系 / 異常系 / 境界値 / スキップ / リトライ** のいずれかを必ず指定する（バッチ特有のスキップ・リトライ観点を忘れない）。
- **finalize モード**: 実装済みのテストメソッドと TC-XXX を突合し、件数とシナリオを一致させる。

### 3. 結合テストは対象外（別工程）

結合テスト（IT-XXX）は `/integration-test-from-design` が担う。本スキルでは `結合テストマトリクス.md` を作成しない。

### 4. トレーサビリティマトリクス（RTM）の更新

`docs/test/トレーサビリティマトリクス.md` に当該 Issue の行を追記・更新する（様式は [test-design-matrix-template.md](test-design-matrix-template.md)）。

- 列: `UC / AC（または IMPL-XX）/ BR / Job名・Step名 / Issue# / TC-XXX / IT-XXX / E2E-XXX`
- IT-XXX 列は結合テスト工程が記入するため製造時点では `—`。E2E も `—`。

### 5. ハードゲート（finalize モードで必須）

`draft` モードではゲートをスキップ。`finalize` モードでは機械検証し exit 0 になるまで完了しない。

```bash
bash .claude/skills/_common/scripts/check-test-matrix.sh docs/test <ISSUE> unit
```

NG（exit 1）の場合は不足（TC 行・RTM の Issue 行）を補ってから再実行する。

### 6. コミットと push（own リポジトリ）

```bash
git add docs/test/単体テストマトリクス.md docs/test/トレーサビリティマトリクス.md
git commit -m "docs(test): テスト設計マトリクス (#<ISSUE>)" || true
git push || true
```

## 完了条件

- 単体テストマトリクス（TC-XXX）が AC-XXX（または IMPL-XX）に対応づけて作成されている
- RTM に当該 Issue の行（TC-XXX）が反映されている
- `check-test-matrix.sh ... unit` が exit 0
- マトリクスが feature ブランチへ commit/push され PR に含まれている

## 凡例

| 略号 | 正式名称 | 補足 |
| --- | --- | --- |
| TC-XXX | 単体テストケース ID | 3 桁ゼロ埋め |
| IT-XXX | 結合テストケース ID | 3 桁ゼロ埋め |
| RTM | トレーサビリティマトリクス | 要件→設計→Issue→テストの追跡表 |
| AC-XXX | 受け入れ条件 | 要件定義 `functional/*.md` で定義 |
| IMPL-XX | 実装内容項目 | AC が無い基盤 Issue で設計書「実装内容」を観点化した一時 ID |

## 注意事項

- テスト実施（実行・カバレッジ）は本スキルの対象外。
- マトリクスは own リポジトリの `docs/test/` に書く。docs リポジトリには書かない。
- 強調表記は鉤括弧 `「...」` を使う（`"..."` 禁止）。
