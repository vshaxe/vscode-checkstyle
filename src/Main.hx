import vscode.ExtensionContext;
import vscode.TextDocument;

using StringTools;

class Main {
    var context:ExtensionContext;

    function new(ctx) {
        context = ctx;
        context.subscriptions.push(Vscode.commands.registerCommand("haxecheckstyle.check", check));
        Vscode.workspace.onDidSaveTextDocument(onDidSaveTextDocument);
        Vscode.workspace.onDidOpenTextDocument(onDidOpenTextDocument);
    }

    function check() {
        doCheck(Vscode.window.activeTextEditor.document.fileName);
    }

    function clearDecorations() {
        for (decoration in VSCodeReporter.decorations) {
            decoration.dispose();
        }

        VSCodeReporter.decorations = [];
    }

    @:access(checkstyle)
    function doCheck(fileName:String) {
        clearDecorations();

        var checker = new checkstyle.Main();
        checker.addAllChecks();
        var file:Array<checkstyle.CheckFile> = [{ name: fileName, content: null, index: 0 }];
        var reporter = new VSCodeReporter(1, checker.getCheckCount(), checker.checker.checks.length, null, false);
        checker.checker.addReporter(reporter);
        checker.checker.process(file, checker.excludesMap);
    }

    function onDidSaveTextDocument(event:TextDocument):Dynamic {
        doCheck(event.fileName);
        return null;
    }

    function onDidOpenTextDocument(event:TextDocument):Dynamic {
        doCheck(event.fileName);
        return null;
    }

    @:keep
    @:expose("activate")
    static function main(context:ExtensionContext) {
        new Main(context);
    }
}
