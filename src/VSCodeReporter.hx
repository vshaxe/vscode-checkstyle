import checkstyle.CheckMessage;
import checkstyle.reporter.BaseReporter;
import vscode.Range;
import vscode.Diagnostic;

class VSCodeReporter extends BaseReporter {
    public var diagnostics:Array<Diagnostic> = [];

    override public function addMessage(m:CheckMessage) {
        var range = new Range(m.line - 1, m.startColumn, m.line - 1, m.endColumn);
        var diag = new Diagnostic(range, m.message, Information);
        diag.source = "checkstyle";
        diagnostics.push(diag);
    }
}
