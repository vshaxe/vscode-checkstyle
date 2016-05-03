import haxe.io.Path;
import vscode.ExtensionContext;
import vscode.TextDocument;
import vscode.DiagnosticCollection;

class Main {
    static inline var CONFIG_OPTION = "configurationFile";

    var context:ExtensionContext;
    var diagnostics:DiagnosticCollection;

    function new(ctx) {
        context = ctx;
        diagnostics = Vscode.languages.createDiagnosticCollection("checkstyle");
        Vscode.workspace.onDidSaveTextDocument(onDidSaveTextDocument);
        Vscode.workspace.onDidOpenTextDocument(onDidOpenTextDocument);
    }

    @:access(checkstyle)
    function check(event:TextDocument) {
        var fileName = event.fileName;

        if (event.languageId != "haxe" || !sys.FileSystem.exists(fileName)) {
            return;
        }

        var checker = new checkstyle.Main();

        var configuration = Vscode.workspace.getConfiguration("haxecheckstyle");
        if (configuration.has(CONFIG_OPTION) && configuration.get(CONFIG_OPTION) != "") {
            try {
                checker.configPath = Path.join([Vscode.workspace.rootPath, configuration.get(CONFIG_OPTION)]);
                checker.loadConfig(checker.configPath);
            }
            catch (e:Dynamic) {
                checker.configPath = null;
            }
        }

        if (checker.configPath == null) {
            checker.addAllChecks();
        }

        var file:Array<checkstyle.CheckFile> = [{ name: fileName, content: null, index: 0 }];
        var reporter = new VSCodeReporter(1, checker.getCheckCount(), checker.checker.checks.length, null, false);
        checker.checker.addReporter(reporter);

        checker.checker.process(file, checker.excludesMap);
        diagnostics.set(vscode.Uri.file(fileName), reporter.diagnostics);
    }

    function onDidSaveTextDocument(event:TextDocument) {
        check(event);
    }

    function onDidOpenTextDocument(event:TextDocument) {
        check(event);
    }

    @:keep
    @:expose("activate")
    static function main(context:ExtensionContext) {
        new Main(context);
    }
}
