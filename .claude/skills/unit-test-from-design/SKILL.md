---
name: unit-test-from-design
description: 設計書またはバッチ設計書から単体テストを作成し、失敗時は根本原因を調査して修正するときに使う。設計から UT 資産へ落とし込むフェーズ向け。
context: fork
argument-hint: [設計書または要件定義書のパス]
---

# バッチ設計書から単体テストを作成する

> **パス解決（マルチリポジトリ対応）**: 本スキル内の `docs/requirements/`・`docs/design/`・`docs/test/` は **docs リポジトリ（claude-poc-docs）ルート相対**のパスを指す。親アンブレラからの場合は `claude-poc-docs/` を前置する。

> **呼び出し元**: `/implement-from-issue` の品質ゲート（手順 5）から「単体テスト」担当として呼ばれる補助 skill。単独起動も可。Agent Teams は使わない。

次の入力をもとに単体テストを作成または更新する: $ARGUMENTS

## 指示

1. 設計書を読む。
   - バッチ設計書: `docs/design/バッチ設計.md`（Job/Step 定義・チャンクサイズ・コミット間隔・スキップ/リトライ・失敗時挙動）
   - 関連要件の受け入れ条件: `docs/requirements/functional/[機能名].md` の AC-XXX
   - DB の仕様: `docs/design/tables/[テーブル名].md`

2. 要件と単体テストの対応表がない場合は [unit-test-matrix-template.md](unit-test-matrix-template.md) を使って作成する。

3. 以下の観点でテストを追加する。テストフレームワークは **JUnit 5 + spring-batch-test + Mockito（AssertJ）**。
   - **ItemProcessor 単体**: 正常系・バリデーションエラー・境界値（ItemProcessor は純粋関数的に実装するためモックが最小）
   - **Job 実行（JobLauncherTestUtils）**: `@SpringBatchTest` + `@SpringBootTest` で Job を起動し、`JobExecution.getStatus()` が `COMPLETED` であることを確認
   - **Step 実行**: `JobLauncherTestUtils.launchStep()` で個別 Step の動作確認
   - **Skip/Retry**: スキップ/リトライが設計通りに発動することを確認
   - **StepScope Bean**: `StepScopeTestUtils.doInStepScope()` で `@StepScope` Bean を単体テスト
   - **ItemReader/ItemWriter**: `@SpringBatchTest` の `StepScopeTestExecutionListener` を活用

4. 最も狭い関連テストコマンドを実行する（例: `mvn test -Dtest=XxxJobTest`）。

5. テスト失敗時は、アプリケーションコード・テスト設計・セットアップのどこに原因があるかを判断し、根本原因を修正する。

6. 修正ごとに同じ焦点の検証を再実行する。

## 追加資料

- テンプレート: [unit-test-matrix-template.md](unit-test-matrix-template.md)
