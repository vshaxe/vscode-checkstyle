import checkstyle.Message;
import checkstyle.reporter.BaseReporter;
import vscode.Diagnostic;
import vscode.DiagnosticRelatedInformation;
import vscode.Location;
import vscode.Range;

class VSCodeReporter extends BaseReporter {
	public var diagnostics:Array<Diagnostic> = [];

	public var fileNameFilter:String = "";

	override public function start() {}

	override public function finish() {}

	override public function addMessage(m:Message) {
		var range = new Range(m.range.start.line - 1, m.range.start.column, m.range.end.line - 1, m.range.end.column);
		var diag = new Diagnostic(range, m.moduleName + " - " + m.message, Information);
		diag.source = "checkstyle";
		diag.code = m.code;
		diag.relatedInformation = [];
		var filterMatched:Bool = m.fileName == fileNameFilter;

		for (mesg in m.related) {
			if (mesg.fileName == fileNameFilter) {
				filterMatched = true;
			}
			var relatedInfo:DiagnosticRelatedInformation = new DiagnosticRelatedInformation(new Location(vscode.Uri.file(mesg.fileName),
				new Range(mesg.range.start.line - 1, mesg.range.start.column, mesg.range.end.line - 1, mesg.range.end.column)),
				m.message);
			diag.relatedInformation.push(relatedInfo);
		}

		if (filterMatched) {
			diagnostics.push(diag);
		}
	}
}
