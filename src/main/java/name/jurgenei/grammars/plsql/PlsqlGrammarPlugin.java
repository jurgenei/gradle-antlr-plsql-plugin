package name.jurgenei.grammars.plsql;

import org.gradle.api.Plugin;
import org.gradle.api.Project;

/**
 * Legacy compatibility alias for the PL/SQL XML AST plugin.
 */
@Deprecated(forRemoval = false)
public final class PlsqlGrammarPlugin implements Plugin<Project> {
    @Override
    public void apply(final Project project) {
        new XmlAstPlsqlPlugin().apply(project);
    }
}

