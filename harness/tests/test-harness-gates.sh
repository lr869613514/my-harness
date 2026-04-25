#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIRS=()
trap 'rm -rf "${TMP_DIRS[@]:-}"' EXIT

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

make_workspace() {
    local tmp
    tmp="$(mktemp -d)"
    mkdir -p "$tmp/.harness/scripts" "$tmp/.harness/core/02-tech-stacks" "$tmp/.harness/docs/reports/verification" "$tmp/.harness/docs/reports/unit-test/reports-latest"
    cp "$ROOT_DIR/.harness/scripts/run-verification-gates.sh" "$tmp/.harness/scripts/run-verification-gates.sh"
    cp "$ROOT_DIR/.harness/scripts/run-bdd.sh" "$tmp/.harness/scripts/run-bdd.sh"
    cp "$ROOT_DIR/.harness/scripts/run-security-scan.sh" "$tmp/.harness/scripts/run-security-scan.sh"
    cp "$ROOT_DIR/.harness/scripts/run-release-gate.sh" "$tmp/.harness/scripts/run-release-gate.sh"
    cat > "$tmp/.harness/.env" <<'ENV'
STACK_ID=java8-spring2-gradle
CMD_SECURITY_SCAN="./gradlew dependencyCheckAnalyze"
CMD_BDD_DRY_RUN="./gradlew cucumber -Pcucumber.options='--dry-run'"
CMD_BDD_RUN="./gradlew cucumber"
ENV
    cat > "$tmp/.harness/core/02-tech-stacks/java8-spring2-gradle.yaml" <<'YAML'
commands:
  security_scan: "./gradlew dependencyCheckAnalyze"
YAML
    cat > "$tmp/build.gradle" <<'GRADLE'
plugins {
    id 'java'
}
GRADLE
    TMP_DIRS+=("$tmp")
    printf '%s\n' "$tmp"
}

write_fake_gradlew() {
    local tmp="$1"
    local mode="$2"
    cat > "$tmp/gradlew" <<EOF
#!/bin/bash
set -e
case "\$*" in
  "tasks --all")
    printf '%s\n' test check jacocoTestCoverageVerification dependencyCheckAnalyze cucumber contractTest resilienceTest
    ;;
  "test")
    if [ "$mode" = "skipped" ]; then
      echo "> Task :test SKIPPED"
    else
      mkdir -p build/test-results/test
      cat > build/test-results/test/TEST-example.xml <<'XML'
<testsuite tests="1" failures="0" errors="0" skipped="0"></testsuite>
XML
      echo "> Task :test"
    fi
    echo "BUILD SUCCESSFUL"
    ;;
  "jacocoTestCoverageVerification")
    if [ "$mode" = "skipped" ]; then
      echo "> Task :jacocoTestCoverageVerification SKIPPED"
    else
      mkdir -p build/reports/jacoco/test
      echo "coverage" > build/reports/jacoco/test/jacocoTestReport.xml
      echo "> Task :jacocoTestCoverageVerification"
    fi
    echo "BUILD SUCCESSFUL"
    ;;
  "dependencyCheckAnalyze")
    if [ "$mode" = "placeholder-security" ]; then
      echo "dependencyCheckAnalyze: placeholder task executed."
    else
      echo "Dependency scan complete"
    fi
    echo "BUILD SUCCESSFUL"
    ;;
  "cucumber -Pcucumber.options='--dry-run'"|"cucumber -Pcucumber.options=--dry-run")
    echo "> Task :cucumber"
    echo "BUILD SUCCESSFUL"
    ;;
  "cucumber"|"contractTest"|"resilienceTest")
    if [ "$mode" = "zero-g2g3g4-tests" ]; then
      case "\$*" in
        "contractTest")
          mkdir -p build/test-results/contractTest
          cat > build/test-results/contractTest/TEST-contract.xml <<'XML'
<testsuite tests="0" failures="0" errors="0" skipped="0"></testsuite>
XML
          ;;
        "cucumber")
          mkdir -p build/test-results/cucumber
          cat > build/test-results/cucumber/TEST-cucumber.xml <<'XML'
<testsuite tests="0" failures="0" errors="0" skipped="0"></testsuite>
XML
          ;;
        "resilienceTest")
          mkdir -p build/test-results/resilienceTest
          cat > build/test-results/resilienceTest/TEST-resilience.xml <<'XML'
<testsuite tests="0" failures="0" errors="0" skipped="0"></testsuite>
XML
          ;;
      esac
    fi
    echo "> Task :\$*"
    echo "BUILD SUCCESSFUL"
    ;;
  *)
    echo "unexpected gradle args: \$*" >&2
    exit 1
    ;;
esac
EOF
    chmod +x "$tmp/gradlew"
}

test_verify_blocks_skipped_tasks() {
    local tmp
    tmp="$(make_workspace)"
    write_fake_gradlew "$tmp" "skipped"

    if (cd "$tmp" && bash .harness/scripts/run-verification-gates.sh >/tmp/harness-verify-skipped.out 2>&1); then
        fail "verify should fail when Gradle reports SKIPPED tasks"
    fi
    grep -qi "SKIPPED" /tmp/harness-verify-skipped.out || fail "verify failure should mention SKIPPED"
    pass "verify blocks skipped tasks"
}

test_security_scan_blocks_placeholder_success() {
    local tmp
    tmp="$(make_workspace)"
    write_fake_gradlew "$tmp" "placeholder-security"

    if (cd "$tmp" && bash .harness/scripts/run-security-scan.sh >/tmp/harness-security-placeholder.out 2>&1); then
        fail "security scan should fail when dependencyCheckAnalyze is a placeholder"
    fi
    grep -q "placeholder" /tmp/harness-security-placeholder.out || fail "security scan failure should mention placeholder"
    pass "security scan blocks placeholder success"
}

test_release_gate_blocks_failed_verification_summary() {
    local tmp
    tmp="$(make_workspace)"
    cat > "$tmp/.harness/docs/reports/verification/gates-summary-20990101-000000.log" <<'LOG'
===== Verification Result =====
BLOCKED (task未配置): 1
FAILED  (执行失败):   0
LOG
    cat > "$tmp/.harness/docs/reports/static-analysis-20990101-000000.log" <<'LOG'
BUILD SUCCESSFUL
LOG
    cat > "$tmp/.harness/docs/reports/security-scan-20990101-000000.log" <<'LOG'
No vulnerabilities found
LOG
    cat > "$tmp/.harness/docs/reports/adversarial-review-20990101-000000.md" <<'MD'
# Adversarial Review Report
- CRITICAL: 0
- HIGH: 0
MD
    cat > "$tmp/.harness/docs/reports/unit-test/reports-latest/TEST-example.xml" <<'XML'
<testsuite tests="1" failures="0" errors="0" skipped="0"></testsuite>
XML

    if (cd "$tmp" && bash .harness/scripts/run-release-gate.sh >/tmp/harness-release-blocked.out 2>&1); then
        :
    fi
    grep -q "NO-GO" /tmp/harness-release-blocked.out || fail "release gate should be NO-GO when verification summary is blocked"
    pass "release gate blocks failed verification summary"
}

test_verify_blocks_zero_g2_g3_g4_tests() {
    local tmp
    tmp="$(make_workspace)"
    write_fake_gradlew "$tmp" "zero-g2g3g4-tests"

    if (cd "$tmp" && bash .harness/scripts/run-verification-gates.sh >/tmp/harness-verify-zero-g234.out 2>&1); then
        fail "verify should fail when G2/G3/G4 report zero executed tests"
    fi
    grep -q "JUnit 结果无效" /tmp/harness-verify-zero-g234.out || fail "verify failure should mention invalid JUnit results"
    pass "verify blocks zero G2/G3/G4 tests"
}

test_verify_ignores_stale_g2_g3_g4_results() {
    local tmp
    tmp="$(make_workspace)"
    write_fake_gradlew "$tmp" "zero-g2g3g4-tests"
    mkdir -p "$tmp/build/test-results/contractTest" "$tmp/build/test-results/cucumber" "$tmp/build/test-results/resilienceTest"
    cat > "$tmp/build/test-results/contractTest/TEST-stale.xml" <<'XML'
<testsuite tests="1" failures="0" errors="0" skipped="0"></testsuite>
XML
    cat > "$tmp/build/test-results/cucumber/TEST-stale.xml" <<'XML'
<testsuite tests="1" failures="0" errors="0" skipped="0"></testsuite>
XML
    cat > "$tmp/build/test-results/resilienceTest/TEST-stale.xml" <<'XML'
<testsuite tests="1" failures="0" errors="0" skipped="0"></testsuite>
XML

    if (cd "$tmp" && bash .harness/scripts/run-verification-gates.sh >/tmp/harness-verify-stale-g234.out 2>&1); then
        fail "verify should fail when current G2/G3/G4 reports zero tests even if stale XML exists"
    fi
    grep -q "JUnit 结果无效" /tmp/harness-verify-stale-g234.out || fail "verify failure should ignore stale XML and mention invalid JUnit results"
    pass "verify ignores stale G2/G3/G4 XML"
}

test_bdd_default_full_run_requires_scenarios() {
    local tmp
    tmp="$(make_workspace)"
    write_fake_gradlew "$tmp" "zero-g2g3g4-tests"

    if (cd "$tmp" && bash .harness/scripts/run-bdd.sh >/tmp/harness-bdd-default.out 2>&1); then
        fail "run-bdd without MODE should default to full run and fail on zero scenarios"
    fi
    grep -q "BDD 结果无效" /tmp/harness-bdd-default.out || fail "BDD default run should validate scenario count"
    pass "BDD default full run requires scenarios"
}

test_verify_blocks_skipped_tasks
test_security_scan_blocks_placeholder_success
test_release_gate_blocks_failed_verification_summary
test_verify_blocks_zero_g2_g3_g4_tests
test_verify_ignores_stale_g2_g3_g4_results
test_bdd_default_full_run_requires_scenarios
