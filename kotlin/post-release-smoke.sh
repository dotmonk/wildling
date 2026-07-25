#!/bin/sh
# Post-release consumer smoke for kotlin (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_kotlin() {
    channel kotlin git smoke_kotlin_git
    channel kotlin registry smoke_kotlin_registry
}

smoke_kotlin_git() {
    smoke_clone_build_cli kotlin
}

smoke_kotlin_registry() {
    _wd="$(workdir kotlin-registry)"
    run_docker_root "maven:3.9-eclipse-temurin-21" "${_wd}" '
set -eu
mkdir -p src/main/kotlin
cat > pom.xml <<EOF
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>smoke</groupId>
  <artifactId>smoke</artifactId>
  <version>1</version>
  <dependencies>
    <dependency>
      <groupId>io.github.dotmonk</groupId>
      <artifactId>wildling-kotlin</artifactId>
      <version>'"${VERSION}"'</version>
    </dependency>
    <dependency>
      <groupId>org.jetbrains.kotlin</groupId>
      <artifactId>kotlin-stdlib</artifactId>
      <version>2.0.21</version>
    </dependency>
  </dependencies>
  <build>
    <sourceDirectory>src/main/kotlin</sourceDirectory>
    <plugins>
      <plugin>
        <groupId>org.jetbrains.kotlin</groupId>
        <artifactId>kotlin-maven-plugin</artifactId>
        <version>2.0.21</version>
        <executions>
          <execution>
            <id>compile</id>
            <goals><goal>compile</goal></goals>
          </execution>
        </executions>
      </plugin>
      <plugin>
        <artifactId>maven-shade-plugin</artifactId>
        <version>3.6.0</version>
        <executions>
          <execution>
            <phase>package</phase>
            <goals><goal>shade</goal></goals>
            <configuration>
              <transformers>
                <transformer implementation="org.apache.maven.plugins.shade.resource.ManifestResourceTransformer">
                  <mainClass>LibSmokeKt</mainClass>
                </transformer>
              </transformers>
              <createDependencyReducedPom>false</createDependencyReducedPom>
            </configuration>
          </execution>
        </executions>
      </plugin>
    </plugins>
  </build>
</project>
EOF
cat > src/main/kotlin/LibSmoke.kt <<EOF
import wildling.Wildling
fun main() {
    val w = Wildling.create(listOf("ab"))
    check(w.count() == 1)
    check(w.get(0) == "ab")
    println("ok")
}
EOF
mvn -q -B package
java -jar target/smoke-1.jar | grep -q ok
'
}

smoke_kotlin

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for kotlin." >&2
    exit 1
fi
