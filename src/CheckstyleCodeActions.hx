import haxe.extern.EitherType;
import vscode.CancellationToken;
import vscode.CodeAction;
import vscode.CodeActionContext;
import vscode.CodeActionKind;
import vscode.Command;
import vscode.Diagnostic;
import vscode.Position;
import vscode.ProviderResult;
import vscode.Range;
import vscode.TextDocument;
import vscode.WorkspaceEdit;

class CheckstyleCodeActions {

    public function new() {}

    public function provideCodeActions(document:TextDocument, range:Range, context:CodeActionContext, token:CancellationToken):ProviderResult<Array<EitherType<Command,CodeAction>>> {
        var commands:Array<EitherType<Command,CodeAction>> = [];
        for (diag in context.diagnostics) {
            if (diag.source != "checkstyle") {
                continue;
            }
            var index = diag.message.indexOf(" - ");
            if (index <= 0) {
                continue;
            }
            var checkName:String = diag.message.substr(0, index);
            switch (checkName) {
                case "Dynamic":
                    var replace = StringTools.replace(document.getText(range), "Dynamic", "Any");
                    commands.push(makeReplaceAction("Replace with Any", document, range, diag, replace));
                case "EmptyPackage":
                    var message = diag.message.substr(index + 3);
                    if (message == "Missing package declaration") {
                        commands.push(makeInsertAction("Add package declaration", document, range.start, diag, "package;\n"));
                    }
                    if (message == "Found empty package") {
                        commands.push(makeDeleteAction("Remove package declaration", document, range, diag));
                    }
                case "Indentation":
                    var reg = ~/expected: "([^"]+)"/;
                    if (!reg.match(diag.message)) {
                        continue;
                    }
                    var replace = reg.matched(1);
                    replace = StringTools.replace(replace, "\\t", "\t");
                    commands.push(makeReplaceAction("Fix indentation", document, range, diag, replace));
                case "Trace":
                    commands.push(makeDeleteAction("Delete trace", document, range, diag));

                    var prefix = document.getText(new Range(range.start.line, 0, range.start.line, range.start.character));
                    if (~/\s+/.match(prefix)) {
                        prefix = "\n" + prefix;
                    } else {
                        prefix = " ";
                    }
                    commands.push(makeInsertAction("Add suppression", document, range.start, diag, "@SuppressWarning('checkstyle:Trace')" + prefix));
                default:
            }
        }
        return commands;
    }

    function makeInsertAction(title:String, document:TextDocument, pos:Position, diagnostic:Diagnostic, insertText:String):CodeAction {
        var action = new CodeAction(title, CodeActionKind.QuickFix);
        action.diagnostics = [diagnostic];
        var edit = new WorkspaceEdit();
        edit.insert(document.uri, pos, insertText);
        action.edit = edit;
        return action;
    }

    function makeReplaceAction(title:String, document:TextDocument, range:Range, diagnostic:Diagnostic, replaceText:String):CodeAction {
        var action = new CodeAction(title, CodeActionKind.QuickFix);
        action.diagnostics = [diagnostic];
        var edit = new WorkspaceEdit();
        edit.replace(document.uri, range, replaceText);
        action.edit = edit;
        return action;
    }

    function makeDeleteAction(title:String, document:TextDocument, range:Range, diagnostic:Diagnostic):CodeAction {
        var action = new CodeAction(title, CodeActionKind.QuickFix);
        action.diagnostics = [diagnostic];
        var edit = new WorkspaceEdit();
        edit.delete(document.uri, range);
        action.edit = edit;
        return action;
    }
}
