#!/usr/bin/env bash
# Phase C — regenerate per-platform SDKs from packages/clients/openapi.json
#
# Backed by `openapi-generator` (brew install openapi-generator). Java
# ships with the JDK at /opt/homebrew/opt/openjdk on Apple Silicon.
#
# Targets:
#   swift     → packages/clients/swift/   (consumed by apps/ios)
#   kotlin    → packages/clients/kotlin/  (Phase F Android)
#   arkts     → packages/clients/arkts/   (Phase G HarmonyOS, post-processed
#                                          from typescript-fetch)
#
# Idempotent: rerun freely. CI gate `make codegen-verify` regenerates
# and `git diff --exit-code`s — uncommitted SDK drift fails the build.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPEC="$ROOT/packages/clients/openapi.json"

if [[ ! -f "$SPEC" ]]; then
  echo "missing $SPEC — run \`make openapi-snapshot\` first" >&2
  exit 1
fi

JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk}"
if [[ ! -x "$JAVA_HOME/bin/java" ]]; then
  echo "JDK not found at $JAVA_HOME — brew install openjdk" >&2
  exit 1
fi
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"

if ! command -v openapi-generator >/dev/null 2>&1; then
  echo "openapi-generator missing — brew install openapi-generator" >&2
  exit 1
fi

ALL_TARGETS=(swift kotlin arkts)
REQUESTED=("${@:-${ALL_TARGETS[@]}}")

# ----- Swift -----------------------------------------------------------------
gen_swift() {
  local out="$ROOT/packages/clients/swift"
  echo "==> Swift → $out"
  rm -rf "$out"
  mkdir -p "$out"
  openapi-generator generate \
    --input-spec "$SPEC" \
    --generator-name swift5 \
    --output "$out" \
    --skip-validate-spec \
    --additional-properties=projectName=TePlannerAPI,responseAs=AsyncAwait,podVersion=1.0.0,useSPMFileStructure=true,swiftPackagePath=Sources/TePlannerAPI \
    --global-property=skipFormModel=false \
    >/tmp/codegen-swift.log 2>&1 || { tail -20 /tmp/codegen-swift.log; exit 1; }
  # openapi-generator writes its own Package.swift at $out — we keep it
  # so apps/ios can `.package(path: "../../packages/clients/swift")`.
  if [[ ! -f "$out/Package.swift" ]]; then
    echo "swift codegen produced no Package.swift" >&2
    exit 1
  fi

  # Post-process: drop the FastAPI-derived ValidationError /
  # HTTPValidationError model files. They clash with the generator's
  # own generic ValidationError<T> in Validation.swift (used by the
  # static `Rule` validators on every model). iOS APIService maps
  # error responses to APIError strings — these structs are unused
  # and the name clash makes the whole package fail to compile.
  rm -f "$out/Sources/TePlannerAPI/Models/HTTPValidationError.swift"
  rm -f "$out/Sources/TePlannerAPI/Models/ValidationError.swift"

  # Post-process: rewrite stray `AnyOf` references the generator emits
  # for Optional[Any]/Union schemas. `AnyOf` was never declared, so
  # the compiler can't resolve it. Map to AnyCodable (already imported
  # at the top of every model). Keeps the field nullable + codable.
  # BSD sed lacks \b — match the surrounding non-identifier chars
  # explicitly: `: AnyOf?` and `, value: AnyOf?` are the patterns
  # the generator emits.
  while IFS= read -r f; do
    /usr/bin/sed -i '' -E 's/(: |, [a-zA-Z_][a-zA-Z0-9_]*: )AnyOf\?/\1AnyCodable?/g' "$f"
  done < <(grep -lr 'AnyOf' "$out/Sources/TePlannerAPI/Models" 2>/dev/null || true)

  echo "    ok ($(find "$out/Sources" -name '*.swift' | wc -l | tr -d ' ') files)"
}

# ----- Kotlin -----------------------------------------------------------------
gen_kotlin() {
  local out="$ROOT/packages/clients/kotlin"
  echo "==> Kotlin → $out"
  rm -rf "$out"
  mkdir -p "$out"
  openapi-generator generate \
    --input-spec "$SPEC" \
    --generator-name kotlin \
    --output "$out" \
    --skip-validate-spec \
    --additional-properties=library=jvm-retrofit2,packageName=cloud.teplanner.api,artifactId=teplanner-api,artifactVersion=1.0.0,serializationLibrary=moshi,useCoroutines=true \
    >/tmp/codegen-kotlin.log 2>&1 || { tail -20 /tmp/codegen-kotlin.log; exit 1; }
  echo "    ok ($(find "$out/src" -name '*.kt' 2>/dev/null | wc -l | tr -d ' ') files)"
}

# ----- ArkTS (HarmonyOS NEXT) — typescript-fetch + post-process ---------------
gen_arkts() {
  local out="$ROOT/packages/clients/arkts"
  echo "==> ArkTS → $out (typescript-fetch + post-process)"
  rm -rf "$out"
  mkdir -p "$out"
  openapi-generator generate \
    --input-spec "$SPEC" \
    --generator-name typescript-fetch \
    --output "$out" \
    --skip-validate-spec \
    --additional-properties=npmName=@teplanner/sdk,npmVersion=1.0.0,modelPropertyNaming=original,supportsES6=true \
    >/tmp/codegen-arkts.log 2>&1 || { tail -20 /tmp/codegen-arkts.log; exit 1; }
  if [[ -f "$ROOT/scripts/post-process-arkts.mjs" ]] && command -v node >/dev/null 2>&1; then
    node "$ROOT/scripts/post-process-arkts.mjs" "$out"
  else
    echo "    note: scripts/post-process-arkts.mjs or node missing — skipping ArkTS rewrite (Phase G prerequisite)"
  fi
  echo "    ok ($(find "$out" -name '*.ts' 2>/dev/null | wc -l | tr -d ' ') files)"
}

for t in "${REQUESTED[@]}"; do
  case "$t" in
    swift)  gen_swift ;;
    kotlin) gen_kotlin ;;
    arkts)  gen_arkts ;;
    *) echo "unknown target: $t (expected one of: ${ALL_TARGETS[*]})" >&2; exit 1 ;;
  esac
done

echo
echo "✓ codegen complete"
