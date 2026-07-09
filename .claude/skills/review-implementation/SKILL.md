---
name: review-implementation
description: 現在の feature ブランチのバッチ実装差分（コード + 品質ゲート結果）をレビューし、BLOCK/SUGGEST/NIT の重大度付き JSON を出力する。implement-loop オーケストレータから呼ばれる。
context: fork
allowed-tools: Bash, Read, Glob, Grep, Write
---

# バッチ実装レビュー

> **パス解決（マルチリポジトリ対応）**: 本スキル内の `docs/requirements/`・`docs/design/`・`docs/test/` は **docs リポジトリ（claude-poc-docs）ルート相対**のパスを指す。親アンブレラからの場合は `claude-poc-docs/` を前置する。

**`context: fork` 必須**: produce skill（`/implement-from-issue`）の判断に引きずられず独立評価するため。

## 役割

feature ブランチのバッチ実装差分・設計書との整合・品質ゲート通過状況をレビューし、機械可読 JSON を生成する。

## 入出力

- 入力: 現在の feature ブランチ（`git diff main...HEAD`）
- 入力: `docs/design/バッチ設計.md`（バッチ仕様）+ 関連 `docs/design/tables/*.md`
- 入力: 品質ゲートの実行結果（`target/` 配下のレポート）
- 入力: `.skills-state/implement/state.json`
- 出力: `.skills-state/implement/round-<N>-review.json`
- 出力（標準出力）: 生成した review JSON のパスを 1 行

## 手順

1. **state を Read**: iteration を取得。
2. **差分の特定**: `git diff --name-only main...HEAD` で変更ファイル一覧を取得。
3. **バッチ設計書を特定**: state または Issue 本文から Job 名・Step 名を抽出し、`docs/design/バッチ設計.md` の該当箇所を Read。
4. **品質ゲート結果の確認**（実行済みかをレポートの更新時刻で判定する。`implement-from-issue` 手順 5 の固定パスより新しいレポートが無ければ category=`quality_gate` の BLOCK とする）:
   - `mvn verify` の最新結果（`target/surefire-reports/`）
   - JaCoCo カバレッジレポート（`target/site/jacoco/jacoco.xml`）
   - SpotBugs / Checkstyle / PMD レポート（`target/`）
5. **コードレビュー**: 差分ファイルを Read し、バッチ設計書と突き合わせる
5.5. **切断チェック（必須）**:
   ```bash
   FILES=$(git diff --name-only main...HEAD | tr '\n' ' ')
   if [[ -d docs/test ]]; then FILES="$FILES docs/test/"; fi
   if [[ -n "$FILES" ]]; then
     bash .claude/skills/_common/scripts/check-truncation.sh $FILES
   fi
   ```
   - 出力は findings JSON 配列（BLOCK / SUGGEST / NIT）。手動レビューの findings に merge して Write する。

6. **JSON を Write**
7. **JSON 検証（必須）**:
   ```bash
   bash .claude/skills/_common/scripts/validate-review-json.sh <output-path>
   ```
   パース失敗時は最大 3 回自己修正を試み、それでも通らない場合は `ERROR: invalid JSON after 3 attempts` を出力して停止する。
8. **標準出力に JSON パスを 1 行**

## レビュー観点

### BLOCK

- `quality_gate`: 単体テスト・静的解析のいずれかが**失敗**（E2E は対象外）
- `coverage`: バッチ単体テストのカバレッジが `batch-00-stack.md` #11 の閾値（INSTRUCTION 100% / BRANCH 90%、除外後）未満、または明確な未テストパス
- `design_mismatch`: 実装がバッチ設計書と矛盾（Job名・Step名・チャンクサイズ・コミット間隔・スキップ/リトライ設定の不一致）
- `batch_structure`: Job/Step 構成が `batch-01-architecture.md` に違反（JobConfig が薄くない、Processor に副作用、ItemWriter に業務ロジック等）
- `job_resilience`: 設計書で要求されている Skip/Retry ポリシーが未実装、または再実行時のべき等性が保証されていない
- `security`: SQL インジェクション・機密情報のログ出力・ファイルパストラバーサル・ハードコードされたシークレット
- `traceability`: Issue の受け入れ条件 AC-XXX に対応するテストがない、コミットメッセージに Issue 参照がない
- `git`: `main` / `master` / `develop` への直接 commit、`.github/workflows/**` の編集

### SUGGEST

- `readability`: メソッドが長すぎる（>50 行）、命名が説明的でない
- `duplication`: 同じロジックの複数箇所重複
- `error_handling`: 例外を握り潰している、エラーログが不十分
- `performance`: チャンクサイズが過小（1件ずつ）、不要な N+1 クエリ
- `test_design`: 単体テストマトリクス（TC-XXX）が AC-XXX と対応づいていない、正常系/異常系/境界値/スキップ/リトライ区分が欠けている
- `traceability_matrix`: `docs/test/トレーサビリティマトリクス.md`（RTM）が無い、または今回 Issue の行が未反映

### NIT

- `style`: Checkstyle/Spotless で直せる範囲
- `typo`: コメント・変数名の軽微な誤字

## 出力 JSON スキーマ

`phase: "implement"`、`category` には上記カテゴリを使う。スキーマは review-requirements と同じ。

## 注意事項

- このスキルではコードを書き換えない（diagnostics のみ）。
- 品質ゲートが**実行されていない**場合は、それ自体を `BLOCK` category=`quality_gate` として報告する。
- 差分が巨大（>30 ファイル）の場合は「巨大変更につき抜本見直しを推奨」と明記。
- `message` / `title` / `recommendation` などの自然言語フィールドは鉤括弧 `「...」` で強調（`"..."` 禁止）。
