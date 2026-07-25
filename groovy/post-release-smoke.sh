#!/bin/sh
# Post-release consumer smoke for groovy (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_groovy() {
    channel groovy git smoke_groovy_git
    channel groovy registry smoke_groovy_registry
}

smoke_groovy_git() {
    smoke_clone_build_cli groovy
}

smoke_groovy_registry() {
    _wd="$(workdir groovy-registry)"
    run_docker_root "maven:3.9-eclipse-temurin-17" "${_wd}" '
set -eu
mkdir -p src/main/groovy
cat > pom.xml <<EOF
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>smoke</groupId>
  <artifactId>smoke</artifactId>
  <version>1</version>
  <dependencies>
    <dependency>
      <groupId>io.github.dotmonk</groupId>
      <artifactId>wildling-groovy</artifactId>
      <version>'"${VERSION}"'</version>
    </dependency>
    <dependency>
      <groupId>org.apache.groovy</groupId>
      <artifactId>groovy</artifactId>
      <version>4.0.24</version>
    </dependency>
  </dependencies>
  <build>
    <sourceDirectory>src/main/groovy</sourceDirectory>
    <plugins>
      <plugin>
        <groupId>org.codehaus.gmavenplus</groupId>
        <artifactId>gmavenplus-plugin</artifactId>
        <version>3.0.2</version>
        <executions>
          <execution>
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
cat > src/main/groovy/LibSmoke.groovy <<EOF
import wildling.Wildling
class LibSmoke {
  static void main(String[] args) {
    def w = Wildling.createWildling(["ab"])
    assert w.count() == 1
    assert w.get(0) == "ab"
    println "ok"
  }
}
EOF
mvn -q -B package
java -jar target/smoke-1.jar | grep -q ok
'
}

smoke_groovy

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for groovy." >&2
    exit 1
fi
