# バッチテスト規約（spring-batch-test + Testcontainers）

> protect-canon 保護対象。編集は人手（または `ALLOW_RULES_EDIT=1` セッション）で行う。

## 使用ライブラリ（`batch-00-stack.md` #8・#9 と整合）

| 用途 | ライブラリ |
| --- | --- |
| 単体テスト基盤 | JUnit 5 + `spring-boot-starter-test`（Mockito・AssertJ） |
| バッチテスト補助 | `spring-batch-test`（`JobLauncherTestUtils` / `JobRepositoryTestUtils` / `StepScopeTestUtils`） |
| 結合テスト DB | Testcontainers `postgresql` モジュール |

## 単体テスト（`*Test.java`）

- **ItemProcessor**: 純粋関数のため Spring Context 不要でテスト可。`process()` が `null` を返すとスキップ扱い
- **Job/Step**: `@SpringBatchTest` + `@SpringBootTest` → `JobLauncherTestUtils.launchJob()` / `launchStep()`
- **@StepScope Bean**: `StepScopeTestUtils.doInStepScope()` で StepScope を手動生成してテスト
- テスト前に `JobRepositoryTestUtils.removeJobExecutions()` で前回実行履歴をクリア

## 結合テスト（`*IntegrationTest.java`）

```java
@SpringBatchTest
@SpringBootTest
@Testcontainers
class XxxJobIntegrationTest {
    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16");

    @Autowired JobLauncherTestUtils jobLauncherTestUtils;
    @Autowired JobRepositoryTestUtils jobRepositoryTestUtils;
    @Autowired JdbcTemplate jdbcTemplate;

    @BeforeEach
    void setUp() { jobRepositoryTestUtils.removeJobExecutions(); }
}
```

- Job 全体実行: `JobExecution.getStatus() == COMPLETED` を確認
- Skip 検証: `StepExecution.getSkipCount()` が設計書の期待値と一致
- 再実行べき等性: 同一 `JobParameters` での 2 回実行を確認

## カバレッジ除外対象（pom jacoco excludes に 1 行理由コメント必須）

```xml
<exclude>**/*JobConfig.class</exclude>   <!-- Bean 定義のみ・業務ロジックなし -->
<exclude>**/*Application.class</exclude> <!-- Spring Boot メインクラス -->
<exclude>**/generated/**</exclude>       <!-- 生成コード -->
```

分岐は 90% 基準（`batch-00-stack.md` #11）。到達不能分岐のためだけのテストは書かない。
