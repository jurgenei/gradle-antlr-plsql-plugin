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

public class XmlAstPlsqlPluginFunctionalTest {

    @Rule
    public TemporaryFolder temporaryFolder = new TemporaryFolder();

    @Test
    public void registersPlsqlXmlAstTask() throws Exception {
        final File projectDir = temporaryFolder.newFolder("functional-registers-plsql-xmlast-new");
        writeSettings(projectDir);
        writeBuildFile(projectDir, """
                plugins {
                    id 'java'
                    id 'name.jurgenei.gradle.antlr.plsql'
                }
                """);

        final BuildResult result = run(projectDir, "tasks", "--all");

        Assert.assertTrue("Expected plsqlXmlAst task to be listed", result.getOutput().contains("plsqlXmlAst"));
    }

    @Test
    public void preconfiguredDefaultsAreApplied() throws Exception {
        final File projectDir = temporaryFolder.newFolder("functional-plsql-defaults-new");
        writeSettings(projectDir);
        writeBuildFile(projectDir, """
                plugins {
                    id 'java'
                    id 'name.jurgenei.gradle.antlr.plsql'
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
}

