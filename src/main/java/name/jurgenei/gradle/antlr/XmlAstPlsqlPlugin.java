package name.jurgenei.gradle.antlr;

import org.gradle.api.Plugin;
import org.gradle.api.Project;

/**
 * Registers a PL/SQL-specific XML AST task type preconfigured from {@link XmlAstPlsqlGradleTask}.
 */
public final class XmlAstPlsqlPlugin implements Plugin<Project> {

    /**
     * Creates the PL/SQL XML AST plugin.
     */
    public XmlAstPlsqlPlugin() {
    }

    @Override
    public void apply(final Project project) {
        LanguagePluginSupport.registerXmlAstTask(
                project,
                "plsqlXmlAst",
                XmlAstPlsqlGradleTask.class,
                "Convert PL/SQL file trees to XML AST output.");
        LanguagePluginSupport.wireJavaRuntimeClasspath(project, XmlAstPlsqlGradleTask.class);
    }
}

