---
name: integration-test-from-design
description: フィーチャ単位でバッチ結合テストを設計（結合テストマトリクス/IT-XXX）し、コンポーネントが組み上がった後に @SpringBatchTest + Testcontainers で実施する独立工程。製造（implement-from-issue）とは分離した結合テスト工程向け。
context: fork
argument-hint: <フィーチャ名 または 結合テスト Issue 番号>
---

# バッチ結合テスト工程（設計＋実施）

> **なぜ製造と分けるか**: 製造の単位は 1 Issue（1 Job / 1 Step）であり、その時点では結合の相手コンポーネントが揃っていないため結合テストは完結しない。フィーチャ単位で複数 Issue が `main` に組み上がった後に独立工程として行う。

> **責務**: 結合テストの **設計（IT マトリクス）と実施（実行）** の両方を担う。単体テスト（TC-XXX）は製造の責務。

> **パス解決**: 読み取り入力（`docs/requirements/`・`docs/design/`）は docs ルート相対。書き込み出力（`docs/test/結合テストマトリクス.md`・RTM・結合テストコード）は own リポジトリのワーキングツリー直下。

対象: $ARGUMENTS

## 手順

### 1. 結合スコープの確定

1. 対象フィーチャの Job 設計（`docs/design/バッチ設計.md`・対象 Job/Step）・関連 Issue 群を洗い出す。
2. 結合点を特定する:
   - Job 全体実行（JobLauncher → Job → Step1 → Step2 → ... → 完了）
   - Step 間データ渡し（ExecutionContext）
   - 実 DB への書き込み・読み込みの整合
   - Skip / Retry 発動時のコミット間隔・件数整合
   - 再実行（同一 JobParameters で再起動）のべき等性
3. 構成コンポーネント（Job/Step の実装）が `main` に組み上がっているか確認。未マージの依存があれば中断。

### 2. 結合テストマトリクスの設計（IT-XXX）

`docs/test/結合テストマトリクス.md` を [test-design-matrix-template.md](../test-design-from-issue/test-design-matrix-template.md) の結合テスト節の様式で作成・更新する。

- 各ケースに **IT-XXX（3 桁ゼロ埋め）** を採番し、AC-XXX・Job名・Step名 と相互参照する。
- 区分は **正常系 / 異常系 / 境界値 / スキップ / リトライ / 再実行**。
- 結合点が無いフィーチャはファイルを作成し `対象外` 区分と理由を明記する。

### 3. 結合テストの実施

`@SpringBatchTest` + `@SpringBootTest` + Testcontainers（実 PostgreSQL 16）で結合テストを実装・実行する。

#### セットアップパターン

```java
@SpringBatchTest
@SpringBootTest
@Testcontainers
class XxxJobIntegrationTest {
    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16");

    @Autowired
    private JobLauncherTestUtils jobLauncherTestUtils;

    @Autowired
    private JobRepositoryTestUtils jobRepositoryTestUtils;

    @BeforeEach
    void cleanUp() {
        jobRepositoryTestUtils.removeJobExecutions();
    }

    @Test
    void testJobCompleted() throws Exception {
        JobExecution execution = jobLauncherTestUtils.launchJob();
        assertThat(execution.getStatus()).isEqualTo(BatchStatus.COMPLETED);
    }
}
```

- Job 全体実行: `JobLauncherTestUtils.launchJob()` → `JobExecution.getStatus() == COMPLETED`
- 個別 Step: `JobLauncherTestUtils.launchStep(stepName)` → `StepExecution.getStatus() == COMPLETED`
- DB 検証: `@Autowired JdbcTemplate` で実際の書き込み結果を確認
- Skip 検証: `StepExecution.getSkipCount()` が設計書の期待値と一致
- 再実行: 同一 JobParameters で 2 回実行してべき等性を確認

#### テストコードの配置

`src/test/java/...` 配下に `*IntegrationTest.java` の命名で配置する（Unit テスト `*Test.java` と区別）。

### 4. RTM の更新（IT-XXX 列）

`docs/test/トレーサビリティマトリクス.md` の該当 AC / Job 行の **IT-XXX 列** を埋める（製造で TC-XXX は記入済み）。

### 5. ハードゲート（必須）

```bash
bash .claude/skills/_common/scripts/check-test-matrix.sh docs/test <ISSUE> integration
```

exit 0 になるまで完了しない。

### 6. コミットと push

結合テストマトリクス・RTM・結合テストコードを commit/push して PR に含める。

## 完了条件

- 結合テストマトリクス（IT-XXX、または対象外＋理由）が作成されている
- @SpringBatchTest + Testcontainers で Job 全体実行テストが実装・通過している
- RTM の IT-XXX 列が更新されている
- `check-test-matrix.sh ... integration` が exit 0

## 凡例

| 略号 | 正式名称 | 補足 |
| --- | --- | --- |
| IT-XXX | 結合テストケース ID | 3 桁ゼロ埋め |
| TC-XXX | 単体テストケース ID | 製造で採番済み |
| RTM | トレーサビリティマトリクス | 横串カバレッジの正典 |

## 注意事項

- 単体テスト（TC）は製造の責務。本工程では扱わない。
- 結合点が成立する前（構成 Issue 未マージ）に起動しない。
- 強調表記は鉤括弧 `「...」` を使う。
