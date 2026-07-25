#!/bin/sh
# Post-release consumer smoke for scala (git/GitHub + registry as documented).
set -eu

LANG_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$LANG_DIR/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/scripts/post-release-smoke-lib.sh"
post_release_smoke_init

SMOKE_FAIL=0

smoke_scala() {
    channel scala git smoke_scala_git
    channel scala registry smoke_scala_registry
}

smoke_scala_git() {
    smoke_clone_build_cli scala
}

smoke_scala_registry() {
    _wd="$(workdir scala-registry)"
    run_docker_root "maven:3.9-eclipse-temurin-21" "${_wd}" '
set -eu
mkdir -p src/main/scala
cat > pom.xml <<EOF
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>smoke</groupId>
  <artifactId>smoke</artifactId>
  <version>1</version>
  <dependencies>
    <dependency>
      <groupId>io.github.dotmonk</groupId>
      <artifactId>wildling-scala</artifactId>
      <version>'"${VERSION}"'</version>
    </dependency>
    <dependency>
      <groupId>org.scala-lang</groupId>
      <artifactId>scala-library</artifactId>
      <version>2.13.15</version>
    </dependency>
  </dependencies>
  <build>
    <sourceDirectory>src/main/scala</sourceDirectory>
    <plugins>
      <plugin>
        <groupId>net.alchim31.maven</groupId>
        <artifactId>scala-maven-plugin</artifactId>
        <version>4.9.2</version>
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
cat > src/main/scala/LibSmoke.scala <<EOF
object LibSmoke {
  def main(args: Array[String]): Unit = {
    val w = wildling.Wildling(Seq("ab"))
    assert(w.count() == 1)
    assert(w.get(0) == "ab")
    println("ok")
  }
}
EOF
mvn -q -B package
java -jar target/smoke-1.jar | grep -q ok
'
}

smoke_scala

if [ "$SMOKE_FAIL" -ne 0 ]; then
    echo "Post-release smoke failed for scala." >&2
    exit 1
fi
