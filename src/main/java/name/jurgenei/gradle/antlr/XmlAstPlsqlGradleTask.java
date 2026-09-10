package name.jurgenei.gradle.antlr;

import name.jurgenei.gradle.antlr.XmlAstGradleTask;
import org.gradle.api.model.ObjectFactory;

import javax.inject.Inject;
import java.util.List;

import org.gradle.work.DisableCachingByDefault;

/**
 * PL/SQL-flavored {@link XmlAstGradleTask} with parser defaults preconfigured.
 */
@DisableCachingByDefault(because = "XmlAstGradleTask performs external parser loading and file-system driven conversion not yet declared for safe caching")
public abstract class XmlAstPlsqlGradleTask extends XmlAstGradleTask {

    /**
     * Creates a preconfigured PL/SQL XML AST task.
     *
     * @param objects Gradle object factory.
     */
    @Inject
    public XmlAstPlsqlGradleTask(final ObjectFactory objects) {
        super(objects);
        LanguageTaskDefaults.of(
                "plsql",
                "name.jurgenei.parsers.PlSqlParser",
                "name.jurgenei.parsers.PlSqlLexer",
                "script",
                List.of("**/*.sql", "**/*.pks", "**/*.pkb", "**/*.pls"))
            .applyTo(this);
    }
}

