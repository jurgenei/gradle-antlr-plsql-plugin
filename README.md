# Gradle ANTLR PL/SQL Plugin

[![Plugin Portal](https://img.shields.io/gradle-plugin-portal/v/name.jurgenei.gradle.antlr.plsql?label=Plugin%20Portal)](https://plugins.gradle.org/plugin/name.jurgenei.gradle.antlr.plsql)
![Java](https://img.shields.io/badge/Java-21%2B-007396?logo=openjdk&logoColor=white)
![Gradle](https://img.shields.io/badge/Gradle-8%2B-02303A?logo=gradle&logoColor=white)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

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
    id 'name.jurgenei.gradle.antlr.plsql' version '0.1.1'
}
```

Plugin Portal page: https://plugins.gradle.org/plugin/name.jurgenei.gradle.antlr.plsql

Legacy id remains available for compatibility:

```groovy
plugins {
    id 'name.jurgenei.grammars.plsql' version '0.1.1'
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
    id 'name.jurgenei.gradle.antlr.plsql' version '0.1.1'
}

tasks.named('plsqlXmlAst', name.jurgenei.grammars.plsql.XmlAstPlsqlGradleTask) {
    sourceDirectory.set(layout.projectDirectory.dir('src/test/resources/plsql'))
    destinationDirectory.set(layout.buildDirectory.dir('xmlast-plsql'))
    targetExtension.set('.xml')
    continueOnError.set(true)
}
```

Run:

```bash
./gradlew plsqlXmlAst
```

## Common Workflow

```bash
./gradlew clean check plsqlXmlAst
```

Supporting tasks commonly used in this repository:

- `generateLexerSources`
- `generateParserSources`
- `compileAntlrSources`
- `verifyGrammarSources`
- `xmlast` (wrapper task for sample conversions)

## Repository Rename

This project follows the renamed repository convention from grammar modules to Gradle plugin naming:

- previous: `https://github.com/jurgenei/antlr-grammars-plsql`
- current: `https://github.com/jurgenei/gradle-antlr-plsql-plugin`

## Development

```bash
./gradlew clean test
./gradlew publishToMavenLocal
```

## Troubleshooting

- `ClassNotFoundException` for parser/lexer classes:
  - Ensure `compileAntlrSources` ran
  - Ensure runtime classpath includes generated classes
- Parse starts but no output files:
  - Verify `sourceDirectory` and `includes`
  - Set `force = true` for a full pass
- Start rule issues:
  - Confirm parser entry method exists (default is `script`)
