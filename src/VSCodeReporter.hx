import checkstyle.CheckMessage;
import checkstyle.reporter.BaseReporter;

class VSCodeReporter extends BaseReporter {

    override public function addMessage(m:CheckMessage) {
        var option:Vscode.DecorationOptions = {
            range: new Vscode.Range(m.line-1, m.startColumn, m.line-1, m.endColumn),
            hoverMessage: m.message
        };

        var decoration = Vscode.window.createTextEditorDecorationType({
            borderWidth: '1px',
            borderStyle: 'solid',
            overviewRulerColor: 'orange',
            overviewRulerLane: Vscode.OverviewRulerLane.Full,
            borderColor: 'orange'
        });

        Vscode.window.activeTextEditor.setDecorations(decoration, [option]);
    }

}