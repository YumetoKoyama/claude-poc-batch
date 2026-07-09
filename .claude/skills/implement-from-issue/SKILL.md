---
name: implement-from-issue
description: 採択済み GitHub Issue をもとにバッチ実装・単体テスト・静的解析・PR 作成・Issue ステータス更新まで一気通貫で自動化するときに使う。製造フェーズ向け。E2E は実行しない。
context: fork
argument-hint: <ISSUE-NUMBER>
---

# GitHub Issue からバッチ実装・品質チェック・PR 作成を行う

> **パス解決（マルチリポジトリ対応）**: 本スキル内の `docs/requirements/`・`docs/design/` は **docs リポジトリ（claude-poc-docs）ルート相対**の**読み取り入力**。製造フェーズの出力（テストマトリクス・RTM）は **own リポジトリの `docs/test/`** に書き PR に含める（docs リポジトリには書かない）。
> - docs リポジトリをカレントとして実行している場合: そのまま使う。
> - 親アンブレラ（claude-poc-rules）から実行している場合（カレント直下に `claude-poc-docs/` が存在する場合）: docs 読み取りパスに `claude-poc-docs/` を前置する。
> - CI（子リポジトリ単体のチェックアウト）で docs リポジトリが存在しない場合: workflow が追加チェックアウトした docs のパスを使う。それも無い場合は Issue 本文に埋め込まれた設計情報を入力とする。

入力（Issue）と出力（コード・テスト・PR）がファイル経由のため `context: fork` で実行する。`/implement-loop` の **produce 段**を担う（review は `/review-implementation` が担当）。

対象 Issue: $ARGUMENTS

## 前提条件

- GitHub Issue が「採択済み」状態（例: ラベル `status:ready` が付与されている）であること
- 設計フェーズが採択済みであること（**採択＝docs リポジトリの `main` へのマージ**。ローカルでは対象設計書が docs の `main` にマージ済みかを確認し、未マージなら中断）
- `gh` CLI がインストール・認証済みであること（`GH_TOKEN` 環境変数）
- `git` が利用可能で、リモート `origin` が GitHub に設定済みであること
- リモートの `main` には **Branch protection rules** が設定されており、PR 経由でしかマージできない状態であること

## 手順

### 1. Issue 情報の取得

1. `gh issue view $ARGUMENTS --json number,title,body,labels,assignees,url` で Issue を取得する
2. 以下を展開して内部メモに整理する
   - Title / Body / 受け入れ条件（AC-XXX）/ 付与ラベル（`type:*`）/ Assignee
   - 関連する設計書ファイルパス（Body に記載されていれば参照）
   - 関連するバッチ設計 ID（バッチ名・ジョブ名・ステップ名）と業務ルール（BR-XXX）

### 2. 要件定義・設計書の確認

- `docs/requirements/` 配下から関連要件を読む
- `docs/design/バッチ設計.md` を必ず読む（トランザクション単位・再実行・件数規模・失敗時挙動）
- DB Issue（`type:table`）: `docs/design/tables/[テーブル名].md` と `docs/design/DB定義.md`
- 要件定義または設計書が存在しない場合はユーザーに確認を取り、作業を中断する

### 2.5. プロジェクト初期化チェック（ビルド定義の存在確認）

```bash
ls pom.xml config/ 2>/dev/null || echo "MISSING"
```

`pom.xml` または静的解析設定（`config/`）が**存在しない**場合は **実装を開始せず中断**する:

> ビルド定義（`pom.xml`）／静的解析設定（`config/`）が見つかりません。事前配置が必要です。

また `.claude/rules/batch-00-stack.md` が存在しない場合も中断し、CLAUDE.md の「ハードゲート」に従いルール整備を人間に依頼する。

### 3. ブランチの作成

```bash
git checkout main
git pull --rebase origin main
git checkout -b feature/issue-$ARGUMENTS
```

ブランチ名規約: `feature/issue-<ISSUE-NUMBER>`

`main` への直接 push は deny ルールおよび Branch protection で禁止されている。

### 3.5. テスト設計ドラフト（実装と並行・設計由来）

`/test-design-from-issue $ARGUMENTS draft` を呼び、設計書（AC-XXX・バッチ設計）から TC-XXX と区分を先出しする。実コード突合・ハードゲートは手順 5.5 で行う。

### 4. 実装（単一セッション・Agent Teams 不使用）

> 本プロジェクトは Agent Teams（experimental の teammate 機能）を使用しない。実装はこの単一セッション内で設計書に従って進める。

実装前に既存コードを Glob / Grep で調査し、変更影響範囲を特定する。次の順序で進める（依存方向 DB → Job Configuration → Step）。

1. **DB**: migration ファイル / Entity マッピング（`ddl-auto` 運用のため Entity のみでよい）
   - 入力: `docs/design/tables/[テーブル名].md` と `docs/design/DB定義.md`
2. **Job Configuration**: `XxxJobConfig.java`（`@Configuration`）に Job / Step Bean を定義
   - 入力: `docs/design/バッチ設計.md` の対象バッチ仕様
   - Job: `@Bean` で `Job` 定義、ステップを組み上げる
   - Step: チャンク指向（大量データ）またはタスクレット（単純処理）を選択する
     - チャンク指向: `ItemReader` / `ItemProcessor` / `ItemWriter` + `chunk(サイズ)`
     - タスクレット: `Tasklet` 実装クラス + `RepeatStatus.FINISHED`
3. **ItemReader**: データ読み込み実装（`JdbcCursorItemReader` / `JpaPagingItemReader` / カスタム）
4. **ItemProcessor**: 変換・バリデーション業務ロジック（純粋関数・副作用なし推奨）
5. **ItemWriter**: データ書き込み実装（`JdbcBatchItemWriter` / `JpaItemWriter` / カスタム）
6. **エラーハンドリング**: Skip / Retry ポリシーを設計書に従い実装

各レイヤー完了ごとにコンパイル確認（`mvn compile`）を回してから次へ進む。

### 5. 品質ゲート（Pattern 2 並列ファンアウト）

実装完了後、次の独立した品質チェックを **並列**（Pattern 2 Parallel Fan-Out）で実行する。

| 品質ゲート | 内容 | 参照する補助 skill |
| --- | --- | --- |
| 単体テスト + カバレッジ | JUnit 5 + spring-batch-test + Mockito。閾値は `batch-00-stack.md` #11（INSTRUCTION 100% / BRANCH 90%、除外後） | `/unit-test-from-design` |
| 静的解析 | Checkstyle / PMD / SpotBugs（`config/` 配下の設定を使用） | `/static-analysis-remediation` |
| セキュリティレビュー | OWASP ベースの自己点検（SQL インジェクション・機密情報のログ出力・ファイルパストラバーサル）。PR 作成前に必須 | `docs/design/セキュリティテスト観点.md` |

- **E2E は本スキルでは実行しない**。
- **結合テスト（IT-XXX）も本スキルでは設計・実施しない**（結合テスト工程 `/integration-test-from-design` で行う）。
- カバレッジが `batch-00-stack.md` #11 の閾値に届かない場合は `/coverage-to-100` で補う。
- すべてのゲートが成功するまで次のステップへ進まない。

#### 品質ゲートのレポート出力パス（固定）

| ゲート | 出力パス |
| --- | --- |
| 単体テスト（Surefire） | `target/surefire-reports/` |
| カバレッジ（JaCoCo） | `target/site/jacoco/jacoco.xml` |
| 静的解析 | `target/`（SpotBugs / Checkstyle / PMD の各レポート） |

### 5.5. テスト設計の確定（実コード整合）と出力ゲート（必須）

手順3.5 のドラフトを、実装・テスト実施の結果に整合させて **確定** する。`/test-design-from-issue $ARGUMENTS finalize` を呼び、`docs/test/` の次を確定する。

- `docs/test/単体テストマトリクス.md`（TC-XXX）
- `docs/test/トレーサビリティマトリクス.md`（RTM）

**AC-XXX が無い共通基盤 Issue でも省略しない**（設計書「実装内容」を観点化して TC-XXX を採番する）。

```bash
/test-design-from-issue $ARGUMENTS finalize
bash .claude/skills/_common/scripts/check-test-matrix.sh docs/test $ARGUMENTS unit
```

exit 0 になるまで手順6（コミット）以降に進まない。

### 6. コミットと push

```bash
git add <変更ファイルを個別に指定>
git commit -m "feat(#$ARGUMENTS): <Issue タイトル>

<実装内容の日本語サマリ>

Refs: #$ARGUMENTS"
git push -u origin feature/issue-$ARGUMENTS
```

### 7. Pull Request 作成

```bash
gh pr create --base main --head feature/issue-$ARGUMENTS \
  --title "feat(#$ARGUMENTS): <Issue タイトル>" \
  --body-file <一時ファイル>
```

PR 本文テンプレート:

```markdown
## 対応 Issue
- Closes #$ARGUMENTS

## 概要
<日本語で機能概要を 3〜5 行で記載>

## 実装内容
- <変更点 1>
- <変更点 2>

## 品質チェック結果
- 静的解析: ✅ 0 violations
- Unit Test: ✅ <件数> passed（命令カバレッジ <xx>%）
- Test Design ゲート: ✅ check-test-matrix.sh unit 通過
- Security Review: ✅ OWASP 観点点検済み

## 関連リンク
- Issue: #$ARGUMENTS
- バッチ設計書: docs/design/バッチ設計.md
```

### 8. Issue ステータスの更新

```bash
gh issue comment $ARGUMENTS --body "<レビュー依頼コメント>"
gh issue edit $ARGUMENTS --remove-label status:ready --add-label status:in-review
```

### 9. 最終報告

```
| 項目 | 値 |
| --- | --- |
| Issue | #$ARGUMENTS |
| ブランチ | feature/issue-$ARGUMENTS |
| PR URL | https://github.com/<org>/<repo>/pull/<n> |
| Issue ラベル | status:in-review |
| 品質チェック | static-analysis ✅ / unit-test ✅ / test-design(unit ゲート) ✅ / security ✅ |
```

その後、人手レビューが必要であることを明記する。

## 完了条件

- Issue 情報・関連要件定義・バッチ設計書が確認されている
- feature ブランチが作成されている
- バッチ設計書（`docs/design/バッチ設計.md`）に従って Job / Step / Reader / Processor / Writer の実装が完了している
- 単体テスト・静的解析・セキュリティレビューがすべて通過している（結合テスト・E2E は別工程）
- テスト設計（単体マトリクス・RTM）が出力され、`check-test-matrix.sh ... unit` が exit 0
- PR が作成され、Body に `Closes #$ARGUMENTS` が含まれている
- Issue ラベルが `status:in-review` に更新されている

## 注意事項

- 品質チェックで 1 つでも失敗した場合は push / PR 作成を行わない
- `batch-00-stack.md` が存在しない（ルール未整備）場合は中断して人間にルール整備を依頼する
- 認証情報は環境変数から参照し、リポジトリにコミットしない
- `.github/workflows/**` の編集は deny ポリシーで禁止
