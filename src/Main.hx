import haxe.io.Path;
import checkstyle.checks.coding.CodeSimilarityCheck;
import checkstyle.config.Config;
import checkstyle.config.ConfigParser;
import checkstyle.config.ExcludeManager;
import checkstyle.reporter.ReporterManager;
import vscode.DiagnosticCollection;
import vscode.ExtensionContext;
import vscode.TextDocument;

using StringTools;

class Main {
	static inline var MAIN_CONFIG_KEY = "haxecheckstyle";
	static inline var CONFIG_OPTION = "configurationFile";
	static inline var SOURCE_FOLDERS = "sourceFolders";
	static inline var EXTERNAL_SOURCE_ROOTS = "externalSourceRoots";
	static inline var CODE_SIMILARITY_BUFFER_SIZE = "codeSimilarityBufferSize";
	static inline var CHECKSTYLE_JSON = "checkstyle.json";
	static inline var CHECKSTYLE_EXLCUDE_JSON = "checkstyle-excludes.json";

	var context:ExtensionContext;
	var diagnostics:DiagnosticCollection;
	var codeActions:CheckstyleCodeActions;

	function new(ctx) {
		context = ctx;
		diagnostics = Vscode.languages.createDiagnosticCollection("checkstyle");
		codeActions = new CheckstyleCodeActions();
		Vscode.languages.registerCodeActionsProvider("haxe", codeActions);
		Vscode.workspace.onDidSaveTextDocument(check);
		Vscode.workspace.onDidOpenTextDocument(check);

		for (editor in Vscode.window.visibleTextEditors) {
			check(editor.document);
		}
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

		tokentree.TokenStream.MODE = Relaxed;
		var checker = new checkstyle.Main();
		checker.configParser.validateMode = ConfigValidateMode.RELAXED;
		addSourcePaths(checker.configParser);

		if (!fileInSourcePaths(fileName, rootFolder, checker.configParser.paths)) {
			return;
		}
		var configuration = Vscode.workspace.getConfiguration(MAIN_CONFIG_KEY);
		var codeSimilariyBufferSize:Int = 100;
		if (configuration.has(CODE_SIMILARITY_BUFFER_SIZE)) {
			codeSimilariyBufferSize = configuration.get(CODE_SIMILARITY_BUFFER_SIZE);
		}

		ExcludeManager.INSTANCE.clear();
		CodeSimilarityCheck.cleanupRingBuffer(codeSimilariyBufferSize);
		CodeSimilarityCheck.cleanupFile(fileName);

		loadConfig(checker, fileName, rootFolder);

		var file:Array<checkstyle.CheckFile> = [{name: fileName, content: null, index: 0}];
		var reporter = new VSCodeReporter(1, checker.configParser.getCheckCount(), checker.checker.checks.length, null, false);
		ReporterManager.INSTANCE.clear();
		ReporterManager.INSTANCE.addReporter(reporter);

		checker.checker.process(file);
		diagnostics.set(vscode.Uri.file(fileName), reporter.diagnostics);
	}

	@:access(checkstyle)
	function loadConfig(checker:checkstyle.Main, fileName:String, rootFolder:String) {
		// use checkstyle.json from project folder
		var defaultPath = determineConfigFolder(fileName, rootFolder);
		if (defaultPath == null) {
			loadConfigFromSettings(checker, rootFolder);
			return;
		}

		try {
			checker.configPath = Path.join([defaultPath, CHECKSTYLE_JSON]);
			checker.configParser.loadConfig(checker.configPath);
			try {
				var excludeConfig = Path.join([defaultPath, CHECKSTYLE_EXLCUDE_JSON]);
				if (sys.FileSystem.exists(excludeConfig)) {
					checker.configParser.loadExcludeConfig(excludeConfig);
				}
			} catch (e:Dynamic) {
				// tolerate failures for exclude config
			}
			return;
		} catch (e:Dynamic) {
			checker.configPath = null;
		}
		loadConfigFromSettings(checker, rootFolder);
	}

	@:access(checkstyle)
	function loadConfigFromSettings(checker:checkstyle.Main, rootFolder:String) {
		// use config file set through vscode settings
		var configuration:vscode.WorkspaceConfiguration = Vscode.workspace.getConfiguration(MAIN_CONFIG_KEY);
		if (configuration.has(CONFIG_OPTION) && configuration.get(CONFIG_OPTION) != "") {
			try {
				var file = configuration.get(CONFIG_OPTION);
				if (sys.FileSystem.exists(file)) {
					checker.configPath = file;
				} else {
					checker.configPath = Path.join([rootFolder, file]);
				}
				checker.configParser.loadConfig(checker.configPath);
				return;
			} catch (e:Dynamic) {
				checker.configPath = null;
			}
		}
		// default use vscode-checkstyles own builtin config
		useInternalCheckstyleConfig(checker, rootFolder);
	}

	function determineConfigFolder(fileName:String, rootFolder:String):String {
		var path:String = Path.directory(fileName);

		while (path.length >= rootFolder.length) {
			var configFile:String = Path.join([path, CHECKSTYLE_JSON]);
			if (sys.FileSystem.exists(configFile)) {
				return path;
			}
			path = Path.normalize(Path.join([path, ".."]));
		}
		return null;
	}

	@:access(checkstyle)
	function useInternalCheckstyleConfig(checker:checkstyle.Main, rootFolder:String) {
		var config:Config = CompileTime.parseJsonFile("resources/default-checkstyle.json");
		try {
			checker.configParser.parseAndValidateConfig(config, rootFolder);
		} catch (e:Dynamic) {
			checker.configParser.addAllChecks();
		}
	}

	function determineRootFolder(fileName:String):String {
		if (Vscode.workspace.workspaceFolders == null) {
			return null;
		}
		for (i in 0...Vscode.workspace.workspaceFolders.length) {
			var workspaceFolder = Vscode.workspace.workspaceFolders[i];
			if (fileName.startsWith(workspaceFolder.uri.fsPath)) {
				return workspaceFolder.uri.fsPath;
			}
		}

		var configuration = Vscode.workspace.getConfiguration(MAIN_CONFIG_KEY);
		if (!configuration.has(EXTERNAL_SOURCE_ROOTS)) {
			return null;
		}
		var folders:Array<String> = configuration.get(EXTERNAL_SOURCE_ROOTS);
		if (folders == null) {
			return null;
		}
		for (folder in folders) {
			if (fileName.startsWith(folder)) {
				return folder;
			}
		}
		return null;
	}

	function addSourcePaths(configParser:ConfigParser) {
		var configuration = Vscode.workspace.getConfiguration(MAIN_CONFIG_KEY);
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
			if (fileName.startsWith(rootPath)) {
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

	@:keep
	@:expose("activate")
	static function main(context:ExtensionContext) {
		new Main(context);
	}
}
