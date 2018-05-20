import checkstyle.reporter.ReporterManager;
import checkstyle.config.Config;
import checkstyle.config.ConfigParser;
import haxe.io.Path;
import vscode.ExtensionContext;
import vscode.TextDocument;
import vscode.DiagnosticCollection;

class Main {
    static inline var CONFIG_OPTION = "configurationFile";
    static inline var SOURCE_FOLDERS = "sourceFolders";

    var context:ExtensionContext;
    var diagnostics:DiagnosticCollection;
    var codeActions:CheckstyleCodeActions;

    function new(ctx) {
        context = ctx;
        diagnostics = Vscode.languages.createDiagnosticCollection("checkstyle");

        codeActions = new CheckstyleCodeActions();
        Vscode.languages.registerCodeActionsProvider("haxe", {provideCodeActions:codeActions.provideCodeActions});

        Vscode.workspace.onDidSaveTextDocument(onDidSaveTextDocument);
        Vscode.workspace.onDidOpenTextDocument(onDidOpenTextDocument);
    }

    @:access(checkstyle)
    function check(event:TextDocument) {
        var fileName = event.fileName;
        if (event.languageId != "haxe" || !sys.FileSystem.exists(fileName)) {
            return;
        }

        var rootFolder = determineRootFolder(fileName);
        if (rootFolder == null) {
            return;
        }

        var checker = new checkstyle.Main();
        addSourcePaths(checker.configParser);

        if (!fileInSourcePaths(fileName, rootFolder, checker.configParser.paths)) {
            return;
        }

        var configuration = Vscode.workspace.getConfiguration("haxecheckstyle");
        if (configuration.has(CONFIG_OPTION) && configuration.get(CONFIG_OPTION) != "") {
            try {
                var file = configuration.get(CONFIG_OPTION);
                if (sys.FileSystem.exists(file)) {
                    checker.configPath = file;
                } else {
                    checker.configPath = Path.join([rootFolder, file]);
                }
                checker.configParser.loadConfig(checker.configPath);
            }
            catch (e:Dynamic) {
                checker.configPath = null;
            }
        }

        if (checker.configPath == null) {
            // TODO make it a configuration option with a default config, so people can use checkstyle without checkstyle.json file
            var config:Config = CompileTime.parseJsonFile("checkstyle.json");
            try {
                checker.configParser.parseAndValidateConfig(config, rootFolder);
            }
            catch (e:Dynamic) {
                checker.configParser.addAllChecks();
            }
        }

        var file:Array<checkstyle.CheckFile> = [{ name: fileName, content: null, index: 0 }];
        var reporter = new VSCodeReporter(1, checker.configParser.getCheckCount(), checker.checker.checks.length, null, false);
        ReporterManager.INSTANCE.clear();
        ReporterManager.INSTANCE.addReporter(reporter);

        checker.checker.process(file, checker.configParser.excludesMap);
        diagnostics.set(vscode.Uri.file(fileName), reporter.diagnostics);
    }

    function determineRootFolder(fileName:String):String {
        if (Vscode.workspace.workspaceFolders == null) {
            return null;
        }
        for (i in 0...Vscode.workspace.workspaceFolders.length) {
            var workspaceFolder = Vscode.workspace.workspaceFolders[i];
            if (StringTools.startsWith(fileName, workspaceFolder.uri.fsPath)) {
                return workspaceFolder.uri.fsPath;
            }
        }
        return null;
    }

    function addSourcePaths(configParser:ConfigParser) {
        var configuration = Vscode.workspace.getConfiguration("haxecheckstyle");
        if (!configuration.has(SOURCE_FOLDERS)) {
            return;
        }
        var folders:Array<String> = configuration.get(SOURCE_FOLDERS);
        if (folders == null) {
            return;
        }
        for (folder in folders) {
            configParser.paths.push(folder);
        }
    }

    function fileInSourcePaths(fileName:String, rootFolder:String, paths:Array<String>):Bool {
        fileName = normalizePath(fileName);
        for (path in paths) {
            var rootPath = normalizePath(Path.join([rootFolder, path]));
            if (StringTools.startsWith(fileName, rootPath)) {
                return true;
            }
        }
        return false;
    }

    function normalizePath(path:String):String {
        path = Path.normalize(path);
        if (Sys.systemName() == "Windows") {
            path = path.toLowerCase();
        }
        return path;
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
