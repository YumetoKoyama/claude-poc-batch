# バッチ技術スタック確定表

> 本ファイルはバッチ技術スタックの**正典**であり、設計着手前ハードゲートの機械チェック対象である。
> 「状態」列に `要確定` が 1 行でも残る間は、`design-from-requirements` 以降に進んではならない
> （`.claude/skills/_common/scripts/check-stack-decided.sh` が検査する）。
> 確定の記入は**人間が行う**。Claude は既定値で補完しない（候補の提案までは可）。

## 凡例

| 略号・値 | 正式名称（日本語） | 補足 |
|---|---|---|
| 確定 | 人間が確定済み | 確定値・確定日を記入済みであること |
| 要確定 | 未確定（設計着手ブロック） | 人間が確定値を記入し `確定` に書き換えるまで設計に進まない |

## 確定表

| # | 項目 | 確定値 | 状態 | 確定日 | 根拠・備考 |
|---|------|--------|------|--------|------------|
| 1 | 言語 | Java | 確定 | 2026-06-26 | Spring Batch で統一 |
| 2 | Java バージョン | 25.0.3 | 確定 | 2026-06-26 | バックエンドと統一 |
| 3 | フレームワーク | Spring Batch + Spring Boot | 確定 | 2026-06-26 | Job/Step/ItemReader/ItemProcessor/ItemWriter 構成 |
| 4 | フレームワークバージョン | Spring Boot 3.5.14 | 確定 | 2026-06-26 | バックエンドと統一。BOM 管理に従う |
| 5 | ビルドツール | Maven（独立 pom.xml） | 確定 | 2026-06-26 | バックエンドとは別リポジトリ・別 pom.xml で管理 |
| 6 | DB 製品・バージョン | PostgreSQL 16 | 確定 | 2026-06-26 | Testcontainers の postgres:16 と同一バージョン |
| 7 | DB マイグレーション | なし（デモ期間限定・`ddl-auto` 運用） | 確定 | 2026-06-26 | バックエンドと同方針。本番移行時は Flyway 導入を再検討する |
| 8 | 単体テストフレームワーク | JUnit 5 + spring-batch-test + Mockito（+ AssertJ） | 確定 | 2026-06-26 | spring-boot-starter-test 同梱 + spring-batch-test 追加 |
| 9 | 結合テストの DB 方式 | Testcontainers（PostgreSQL 16） | 確定 | 2026-06-26 | @ServiceConnection で接続自動化。IT-XXX 実行の前提 |
| 10 | 静的解析ツール | Checkstyle + PMD + SpotBugs（config/ をバックエンドからコピーして独立管理） | 確定 | 2026-06-26 | バージョンはバックエンド確定表 #12 と同一。設定ファイルは config/ 配下に固定配置 |
| 11 | カバレッジ計測・閾値 | JaCoCo / INSTRUCTION 100% / BRANCH 90%（除外後） | 確定 | 2026-06-26 | バックエンドと同じ閾値。除外は pom jacoco excludes に 1 行理由コメント必須 |
| 12 | 品質ゲート実行方式 | `mvn verify` 一括 | 確定 | 2026-06-26 | test→jacoco→checkstyle→pmd→spotbugs を verify に束縛。個別ゴールの CLI 直叩き禁止 |

## 運用ルール

- 行の追加は可（項目の細分化など）。行の削除・「状態」列の廃止は不可（機械チェックの前提が壊れる）。
- 確定時は「確定値」「確定日」を記入し、「状態」を `確定` に書き換える。
- 本ファイルは `.claude/rules/` 配下のため protect-canon の保護対象。編集は人手（または `ALLOW_RULES_EDIT=1` セッション）で行う。
