package name.jurgenei.gradle.antlr;

import org.gradle.api.Project;
import org.gradle.testfixtures.ProjectBuilder;
import org.junit.Assert;
import org.junit.Test;

public class XmlAstPlsqlPluginTest {

    @Test
    public void registersPreconfiguredTaskType() {
        final Project project = ProjectBuilder.builder().build();
        project.getPluginManager().apply("java");

        new XmlAstPlsqlPlugin().apply(project);

        final Object task = project.getTasks().getByName("plsqlXmlAst");
        Assert.assertNotNull(task);
        Assert.assertTrue(task instanceof XmlAstPlsqlGradleTask);
    }

    @Test
    public void preconfiguresPlsqlDefaults() {
        final Project project = ProjectBuilder.builder().build();
        project.getPluginManager().apply("java");

        new XmlAstPlsqlPlugin().apply(project);

        final XmlAstPlsqlGradleTask task = (XmlAstPlsqlGradleTask) project.getTasks().getByName("plsqlXmlAst");
        Assert.assertEquals("plsql", task.getGrammar().get());
        Assert.assertEquals("name.jurgenei.parsers.PlSqlParser", task.getParserClassName().get());
        Assert.assertEquals("name.jurgenei.parsers.PlSqlLexer", task.getLexerClassName().get());
        Assert.assertEquals("script", task.getStartRule().get());
        Assert.assertTrue(task.getIncludes().get().contains("**/*.sql"));
        Assert.assertEquals(".xml", task.getTargetExtension().get());
        Assert.assertEquals("compact", task.getOutputFormat().get());
    }

    @Test
    public void supportsXirOutputConfiguration() {
        final Project project = ProjectBuilder.builder().build();
        project.getPluginManager().apply("java");

        new XmlAstPlsqlPlugin().apply(project);

        final XmlAstPlsqlGradleTask task = (XmlAstPlsqlGradleTask) project.getTasks().getByName("plsqlXmlAst");
        task.getTargetExtension().set(".xir");
        task.getOutputFormat().set("beautified");

        Assert.assertEquals(".xir", task.getTargetExtension().get());
        Assert.assertEquals("beautified", task.getOutputFormat().get());
    }
}
