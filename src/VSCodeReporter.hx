import checkstyle.CheckMessage;
import checkstyle.reporter.BaseReporter;
import vscode.DecorationOptions;
import vscode.OverviewRulerLane;
import vscode.Range;

class VSCodeReporter extends BaseReporter {

    override public function addMessage(m:CheckMessage) {
        var option:DecorationOptions = {
            range: new Range(m.line-1, m.startColumn, m.line-1, m.endColumn),
            hoverMessage: m.message
        };

        var decoration = Vscode.window.createTextEditorDecorationType({
            borderWidth: '1px',
            borderStyle: 'solid',
            overviewRulerColor: 'orange',
            overviewRulerLane: OverviewRulerLane.Full,
            borderColor: 'orange'
        });

        Vscode.window.activeTextEditor.setDecorations(decoration, [option]);
    }

}