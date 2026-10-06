# Gradle ANTLR PL/SQL Plugin

![Conformance](https://img.shields.io/badge/Conformance-Check--All%20Passing-brightgreen)

[![Plugin Portal](https://img.shields.io/gradle-plugin-portal/v/name.jurgenei.gradle.antlr.plsql?label=Plugin%20Portal)](https://plugins.gradle.org/plugin/name.jurgenei.gradle.antlr.plsql)
[![Build and Test](https://github.com/jurgenei/gradle-antlr-plsql-plugin/actions/workflows/ci.yml/badge.svg?branch=release%2F0.1.3)](https://github.com/jurgenei/gradle-antlr-plsql-plugin/actions/workflows/ci.yml?query=branch%3Arelease%2F0.1.3)
[![Coverage CI](https://github.com/jurgenei/gradle-antlr-plsql-plugin/actions/workflows/coverage.yml/badge.svg?branch=release%2F0.1.3)](https://github.com/jurgenei/gradle-antlr-plsql-plugin/actions/workflows/coverage.yml?query=branch%3Arelease%2F0.1.3)
[![Coverage](https://codecov.io/gh/jurgenei/gradle-antlr-plsql-plugin/graph/badge.svg?branch=release%2F0.1.3)](https://app.codecov.io/gh/jurgenei/gradle-antlr-plsql-plugin?branch=release%2F0.1.3)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Java](https://img.shields.io/badge/java-21+-green.svg)](https://www.oracle.com/java/)
[![Gradle](https://img.shields.io/badge/gradle-8+-blue.svg)](https://gradle.org/)

`gradle-antlr-plsql-plugin` provides preconfigured XML AST task support for PL/SQL parsing workflows.

It builds on `name.jurgenei.gradle.antlr` and offers task defaults tailored for `PlSqlLexer`/`PlSqlParser` use cases.

## Use Cases

- Convert large PL/SQL corpora to XML AST for lineage extraction
- Validate parser compatibility in CI against benchmark SQL files
- Run parser checks with sensible defaults and minimal Gradle setup
- Keep conversion as first-class Gradle tasks (repeatable and automatable)

## Install

```groovy
plugins {
    id 'name.jurgenei.gradle.antlr.plsql'
}
```

## What the Plugin Adds

- `XmlAstPlsqlGradleTask` task type
- `plsqlXmlAst` pre-registered task
- Runtime classpath and `classes` dependency wiring when `java` plugin is present

Default task conventions:

- `grammar = plsql`
- `parserClassName = name.jurgenei.parsers.PlSqlParser`
- `lexerClassName = name.jurgenei.parsers.PlSqlLexer`
- `startRule = script`
- `includes = ['**/*.sql', '**/*.pks', '**/*.pkb', '**/*.pls']`

## Quick Start

```groovy
plugins {
    id 'java'
    id 'name.jurgenei.gradle.antlr.plsql' 
}

tasks.named('plsqlXmlAst', name.jurgenei.grammars.plsql.XmlAstPlsqlGradleTask) {
    sourceDirectory.set(layout.projectDirectory.dir('src/test/resources/plsql'))
    destinationDirectory.set(layout.buildDirectory.dir('xmlast-plsql'))
    targetExtension.set('.xml')
    continueOnError.set(true)
}
```

S-expression output variant:

```groovy
tasks.named('plsqlXmlAst', name.jurgenei.gradle.antlr.XmlAstPlsqlGradleTask) {
    targetExtension.set('.xir')
    outputFormat.set('beautified')
}
```

- `targetExtension`: `.xml` (default) or `.xir`
- `outputFormat`: `compact` (default) or `beautified`

Run:

```bash
./gradlew plsqlXmlAst
```

## Benchmark and Profiling

Run repeatable benchmark/profile matrix with JFR capture:

```bash
./scripts/profile-xmlast.sh
```

Fast-mode profiling default disables per-file line-count reread (`enableLineCountMetrics=false`).
Set `DECISION_PROFILING=true` to emit grammar decision hotspots in report.

Guide and tunables: `PERF_PROFILING.md`

## Troubleshooting

- `ClassNotFoundException` for parser/lexer classes:
  - Ensure `compileAntlrSources` ran
  - Ensure runtime classpath includes generated classes
- Parse starts but no output files:
  - Verify `sourceDirectory` and `includes`
  - Set `force = true` for a full pass
- Start rule issues:
  - Confirm parser entry method exists (default is `script`)
