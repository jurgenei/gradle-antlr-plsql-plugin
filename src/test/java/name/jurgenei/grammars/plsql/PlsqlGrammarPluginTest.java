package name.jurgenei.grammars.plsql;

import org.gradle.api.Project;
import org.gradle.testfixtures.ProjectBuilder;
import org.junit.Assert;
import org.junit.Test;

public class PlsqlGrammarPluginTest {

    @Test
    public void registersPreconfiguredTaskType() {
        final Project project = ProjectBuilder.builder().build();
        project.getPluginManager().apply("java");

        new PlsqlGrammarPlugin().apply(project);

        Assert.assertTrue(project.getTasks().getByName("plsqlXmlAst") instanceof XmlAstPlsqlGradleTask);
    }

    @Test
    public void preconfiguresPlsqlDefaults() {
        final Project project = ProjectBuilder.builder().build();
        project.getPluginManager().apply("java");

        new PlsqlGrammarPlugin().apply(project);

        final XmlAstPlsqlGradleTask task = (XmlAstPlsqlGradleTask) project.getTasks().getByName("plsqlXmlAst");
        Assert.assertEquals("plsql", task.getGrammar().get());
        Assert.assertEquals("name.jurgenei.parsers.PlSqlParser", task.getParserClassName().get());
        Assert.assertEquals("name.jurgenei.parsers.PlSqlLexer", task.getLexerClassName().get());
        Assert.assertEquals("script", task.getStartRule().get());
        Assert.assertTrue(task.getIncludes().get().contains("**/*.sql"));
    }
}

