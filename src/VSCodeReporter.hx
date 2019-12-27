import checkstyle.CheckMessage;
import checkstyle.reporter.BaseReporter;
import vscode.Diagnostic;
import vscode.Range;

class VSCodeReporter extends BaseReporter {
	public var diagnostics:Array<Diagnostic> = [];

	override public function start() {}

	override public function finish() {}

	override public function addMessage(m:CheckMessage) {
		var range = new Range(m.startLine - 1, m.startColumn, m.endLine - 1, m.endColumn);
		var diag = new Diagnostic(range, m.moduleName + " - " + m.message, Information);
		diag.source = "checkstyle";
		diag.code = m.code;
		diagnostics.push(diag);
	}
}
