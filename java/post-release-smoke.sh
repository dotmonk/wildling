#!/bin/sh
# Post-release consumer smoke for java (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_java() {
    channel java git smoke_java_git
    channel java registry smoke_java_registry
}

smoke_java_git() {
    smoke_clone_build_cli java
    _wd="${SMOKE_ROOT}/java-git"
    run_docker_root "eclipse-temurin:21-jdk-alpine" "${_wd}/repo/java" '
set -eu
cat > LibSmoke.java <<EOF
import wildling.Wildling;
import java.util.List;
import java.util.Map;
public class LibSmoke {
  public static void main(String[] args) {
    Wildling w = Wildling.create(List.of("ab"), Map.of());
    if (w.count() != 1) System.exit(1);
    if (!"ab".equals(w.get(0))) System.exit(2);
  }
}
EOF
javac -cp dist/wildling.jar LibSmoke.java
java -cp "dist/wildling.jar:." LibSmoke
java -jar dist/wildling.jar --version | grep -F "'"${VERSION}"'"
[ "$(java -jar dist/wildling.jar ab)" = ab ]
'
}

smoke_java_registry() {
    _wd="$(workdir java-registry)"
    run_docker_root "maven:3.9-eclipse-temurin-21" "${_wd}" '
set -eu
mkdir -p src/main/java
cat > pom.xml <<EOF
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>smoke</groupId>
  <artifactId>smoke</artifactId>
  <version>1</version>
  <dependencies>
    <dependency>
      <groupId>io.github.dotmonk</groupId>
      <artifactId>wildling</artifactId>
      <version>'"${VERSION}"'</version>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <artifactId>maven-jar-plugin</artifactId>
        <version>3.4.2</version>
        <configuration>
          <archive>
            <manifest>
              <mainClass>LibSmoke</mainClass>
            </manifest>
          </archive>
        </configuration>
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
                  <mainClass>LibSmoke</mainClass>
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
cat > src/main/java/LibSmoke.java <<EOF
import wildling.Wildling;
import java.util.List;
import java.util.Map;
public class LibSmoke {
  public static void main(String[] args) throws Exception {
    Wildling w = Wildling.create(List.of("ab"), Map.of());
    if (w.count() != 1) System.exit(1);
    if (!"ab".equals(w.get(0))) System.exit(2);
    System.out.println("ok");
  }
}
EOF
mvn -q -B package
java -jar target/smoke-1.jar | grep -q ok
'
}

smoke_java

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for java." >&2
    exit 1
fi
