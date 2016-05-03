import vscode.ExtensionContext;
import vscode.TextDocument;
import vscode.DiagnosticCollection;

class Main {
    var context:ExtensionContext;
    var diagnostics:DiagnosticCollection;

    function new(ctx) {
        context = ctx;
        diagnostics = Vscode.languages.createDiagnosticCollection("checkstyle");
        Vscode.workspace.onDidSaveTextDocument(onDidSaveTextDocument);
        Vscode.workspace.onDidOpenTextDocument(onDidOpenTextDocument);
    }

    @:access(checkstyle)
    function check(fileName:String) {
        if (!sys.FileSystem.exists(fileName)) {
            return;
        }
        var checker = new checkstyle.Main();
        checker.addAllChecks();
        var file:Array<checkstyle.CheckFile> = [{ name: fileName, content: null, index: 0 }];
        var reporter = new VSCodeReporter(1, checker.getCheckCount(), checker.checker.checks.length, null, false);
        checker.checker.addReporter(reporter);
        checker.checker.process(file, checker.excludesMap);
        diagnostics.set(vscode.Uri.file(fileName), reporter.diagnostics);
    }

    function onDidSaveTextDocument(event:TextDocument):Dynamic {
        check(event.fileName);
        return null;
    }

    function onDidOpenTextDocument(event:TextDocument):Dynamic {
        check(event.fileName);
        return null;
    }

    @:keep
    @:expose("activate")
    static function main(context:ExtensionContext) {
        new Main(context);
    }
}
