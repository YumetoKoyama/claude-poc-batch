# =============================================================
# バッチ (Spring Batch / Java 25) mvn verify 実行用イメージ
#
# ビルドコンテキスト: claude-poc-batch/docker/
# 実行: claude-poc-batch/ から
#   docker compose run --rm batch-verify
# =============================================================

FROM maven:3.9-eclipse-temurin-25

WORKDIR /workspace

# 依存関係のみ先に解決してレイヤーキャッシュを活用する
COPY pom.xml .
COPY config ./config
RUN mvn -B dependency:go-offline -q

# ソース・テスト・設定をコピーして verify
COPY src ./src

CMD ["mvn", "verify", "-B"]
