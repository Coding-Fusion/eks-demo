# ============================================================
# STAGE 1: Maven build (this is the "mvn package" step KITT does)
# ============================================================
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app

# Copy pom first so dependency download is cached between builds
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source and build the fat jar
COPY src ./src
RUN mvn package -DskipTests -B

# ============================================================
# STAGE 2: Runtime image (jar gets "embedded" here)
# ============================================================
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Run as non-root (EKS security best practice, like WCNP enforces)
RUN addgroup -S app && adduser -S app -G app
USER app

COPY --from=build /app/target/inventory-demo-1.0.0.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
