# Spring Batch アーキテクチャルール

> 本ファイルはバッチアーキテクチャの正典。protect-canon 保護対象。編集は人手（または `ALLOW_RULES_EDIT=1` セッション）で行う。

## 基本構成

Spring Batch の Job/Step/ItemReader/ItemProcessor/ItemWriter 構成を基本とする。

```
JobConfig (@Configuration)
└── Job (@Bean)
    ├── Step1: チャンク指向 (ItemReader → ItemProcessor → ItemWriter)
    └── Step2: タスクレット (Tasklet)
```

## チャンク指向 vs タスクレットの使い分け

| 方式 | 使用基準 |
| --- | --- |
| チャンク指向 | 大量データ処理（100件以上）、トランザクション単位で分割、進捗追跡が必要 |
| タスクレット | 単純な1回限りの処理（前処理クリーンアップ・ファイル移動・通知送信等） |

## レイヤー責務

| レイヤー | 責務 | 禁止事項 |
| --- | --- | --- |
| JobConfig | `@Configuration` で Job/Step の Bean 定義 | 業務ロジックの記述 |
| ItemReader | データの読み込みのみ | 変換・バリデーション・DB 書き込み |
| ItemProcessor | 業務ロジック（変換・バリデーション） | DB 書き込み（副作用禁止）|
| ItemWriter | データの書き込みのみ | 業務ロジックの記述 |
| Tasklet | 1 ステップで完結する単純処理 | チャンク処理と混在 |

## 命名規約

| 種別 | 命名規則 | 例 |
| --- | --- | --- |
| JobConfig クラス | `[機能名]JobConfig.java` | `ShipmentMatchingJobConfig.java` |
| Job Bean 名 | `[機能名]Job` | `shipmentMatchingJob` |
| Step Bean 名 | `[機能名]Step` | `matchingStep` |
| ItemReader クラス | `[機能名]ItemReader.java` | `ShipmentItemReader.java` |
| ItemProcessor クラス | `[機能名]ItemProcessor.java` | `MatchingItemProcessor.java` |
| ItemWriter クラス | `[機能名]ItemWriter.java` | `MatchingResultItemWriter.java` |
| Tasklet クラス | `[機能名]Tasklet.java` | `CleanupTasklet.java` |

## パッケージ構成

```
src/main/java/com/example/logisticsmatching/batch/
├── [機能名]/
│   ├── [機能名]JobConfig.java
│   ├── [機能名]ItemReader.java
│   ├── [機能名]ItemProcessor.java
│   └── [機能名]ItemWriter.java
└── common/
    └── （共通コンポーネント）
```

## JobRepository

- Spring Batch のメタデータ（JobInstance / JobExecution / StepExecution）はアプリ DB（PostgreSQL）に保存する
- デモ期間は `spring.batch.jdbc.initialize-schema=always` で自動生成（`batch-00-stack.md` #7 と整合）
- 本番移行時は Flyway/Liquibase で明示的な初期化スクリプトに切り替える

## エラーハンドリング方針

- **Skip**: `docs/design/バッチ設計.md` で明示されている場合のみ `SkipPolicy` を実装する
- **Retry**: `docs/design/バッチ設計.md` で明示されている場合のみ `RetryPolicy` を実装する
- 設計書に記載がない場合はスキップ/リトライなし（デフォルト: 例外発生で `FAILED`）
- **再実行べき等性**: Job は `JobParameters` を変えれば再実行可能にし、同一パラメータでの重複実行は `JobInstanceAlreadyCompleteException` で防止する

## 禁止事項

- ItemProcessor 内での DB 書き込み（ItemWriter の責務を侵害する）
- JobConfig クラスへの業務ロジックの記述
- 静的フィールドへの JobExecution 状態の格納（スレッドアンセーフ）
- `@EnableBatchProcessing` と Spring Boot の自動構成の混在（Spring Boot 3.x では `@EnableBatchProcessing` を使わず自動構成に任せる）
