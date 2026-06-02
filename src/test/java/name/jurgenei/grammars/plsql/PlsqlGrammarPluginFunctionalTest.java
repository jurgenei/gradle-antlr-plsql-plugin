package name.jurgenei.grammars.plsql;

import org.gradle.testkit.runner.BuildResult;
import org.gradle.testkit.runner.GradleRunner;
import org.junit.Assert;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

public class PlsqlGrammarPluginFunctionalTest {

    @Rule
    public TemporaryFolder temporaryFolder = new TemporaryFolder();

    @Test
    public void registersPlsqlXmlAstTask() throws Exception {
        final File projectDir = temporaryFolder.newFolder("functional-registers-plsql-xmlast");
        writeSettings(projectDir);
        writeBuildFile(projectDir, """
                plugins {
                    id 'java'
                    id 'name.jurgenei.grammars.plsql'
                }
                """);

        final BuildResult result = run(projectDir, "tasks", "--all");

        Assert.assertTrue("Expected plsqlXmlAst task to be listed", result.getOutput().contains("plsqlXmlAst"));
    }

    @Test
    public void preconfiguredDefaultsAreApplied() throws Exception {
        final File projectDir = temporaryFolder.newFolder("functional-plsql-defaults");
        writeSettings(projectDir);
        writeBuildFile(projectDir, """
                plugins {
                    id 'java'
                    id 'name.jurgenei.grammars.plsql'
                }

                tasks.register('printPlsqlDefaults') {
                    doLast {
                        def t = tasks.named('plsqlXmlAst').get()
                        println "grammar=${t.grammar.get()}"
                        println "parserClassName=${t.parserClassName.get()}"
                        println "lexerClassName=${t.lexerClassName.get()}"
                        println "startRule=${t.startRule.get()}"
                    }
                }
                """);

        final BuildResult result = run(projectDir, "printPlsqlDefaults");
        final String output = result.getOutput();

        Assert.assertTrue(output.contains("grammar=plsql"));
        Assert.assertTrue(output.contains("parserClassName=name.jurgenei.parsers.PlSqlParser"));
        Assert.assertTrue(output.contains("lexerClassName=name.jurgenei.parsers.PlSqlLexer"));
        Assert.assertTrue(output.contains("startRule=script"));
    }

    @Test
    public void plsqlXmlAstDependsOnClassesWhenJavaPluginApplied() throws Exception {
        final File projectDir = temporaryFolder.newFolder("functional-plsql-depends-classes");
        writeSettings(projectDir);
        writeBuildFile(projectDir, """
                plugins {
                    id 'java'
                    id 'name.jurgenei.grammars.plsql'
                }
                """);

        final BuildResult result = run(projectDir, "plsqlXmlAst", "--dry-run");
        final String output = result.getOutput();

        Assert.assertTrue("Expected classes task in execution plan", output.contains(":classes SKIPPED"));
        Assert.assertTrue("Expected plsqlXmlAst task in execution plan", output.contains(":plsqlXmlAst SKIPPED"));
    }

    private static BuildResult run(final File projectDir, final String... args) {
        return GradleRunner.create()
                .withProjectDir(projectDir)
                .withArguments(args)
                .withPluginClasspath()
                .build();
    }

    private static void writeSettings(final File projectDir) throws Exception {
        Files.writeString(
                projectDir.toPath().resolve("settings.gradle"),
                "rootProject.name = 'plsql-plugin-functional-test'\n",
                StandardCharsets.UTF_8);
    }

    private static void writeBuildFile(final File projectDir, final String content) throws Exception {
        Files.writeString(
                projectDir.toPath().resolve("build.gradle"),
                content,
                StandardCharsets.UTF_8);
    }

    private static void writeFile(final File projectDir, final String relativePath, final String content) throws Exception {
        final Path target = projectDir.toPath().resolve(relativePath);
        Files.createDirectories(target.getParent());
        Files.writeString(target, content, StandardCharsets.UTF_8);
    }
}

