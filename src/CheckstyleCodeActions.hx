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

        var actions:Map<String, CodeAction> = new Map<String, CodeAction>();
        for (diag in context.diagnostics) {
            if (diag.source != "checkstyle") {
                continue;
            }
            if (range.contains(diag.range)) {
                makeCheckAction(document, actions, diag);
                continue;
            }
            if (diag.range.contains(range)) {
                makeCheckAction(document, actions, diag);
            }
        }

        for (name in actions.keys()) {
            commands.push(actions.get(name));
        }
        return commands;
    }

    function makeCheckAction(document:TextDocument, actions:Map<String, CodeAction>, diag:Diagnostic) {

        var index = diag.message.indexOf(" - ");
        if (index <= 0) {
            return;
        }
        var checkName:CheckNames = diag.message.substr(0, index);
        switch (checkName) {
            case DynamicCheck:
                var replace = StringTools.replace(document.getText(diag.range), "Dynamic", "Any");
                makeReplaceAction(actions, "Replace with Any", document, diag.range, diag, replace);
            case EmptyPackageCheck:
                var message = diag.message.substr(index + 3);
                if (message == "Missing package declaration") {
                    makeInsertAction(actions, "Add package declaration", document, diag.range.start, diag, "package;\n");
                }
                if (message == "Found empty package") {
                    makeDeleteAction(actions, "Remove package declaration", document, diag.range, diag);
                }
            case IndentationCheck:
                var reg = ~/expected: "([^"]+)"/;
                if (!reg.match(diag.message)) {
                    return;
                }
                var replace = reg.matched(1);
                replace = StringTools.replace(replace, "\\t", "\t");
                makeReplaceAction(actions, "Fix indentation", document, diag.range, diag, replace);
            case TraceCheck:
                makeDeleteAction(actions, "Delete trace", document, diag.range, diag);

                var prefix = document.getText(new Range(diag.range.start.line, 0, diag.range.start.line, diag.range.start.character));
                if (~/\s+/.match(prefix)) {
                    prefix = "\n" + prefix;
                } else {
                    prefix = " ";
                }
                makeInsertAction(actions, "Add suppression", document, diag.range.start, diag, "@SuppressWarning('checkstyle:Trace')" + prefix);
            default:
        }
    }

    function createOrGetAction(actions:Map<String, CodeAction>, title:String, diagnostic:Diagnostic):CodeAction  {
        if (actions.exists(title)) {
            var action = actions.get(title);
            action.diagnostics.push(diagnostic);
            return action;
        }
        var action = new CodeAction(title, CodeActionKind.QuickFix);
        action.diagnostics = [diagnostic];
        action.edit = new WorkspaceEdit();
        actions.set(title, action);
        return action;
    }

    function makeInsertAction(actions:Map<String, CodeAction>, title:String, document:TextDocument, pos:Position, diagnostic:Diagnostic, insertText:String)  {
        var action:CodeAction = createOrGetAction(actions, title, diagnostic);
        action.edit.insert(document.uri, pos, insertText);
    }

    function makeReplaceAction(actions:Map<String, CodeAction>, title:String, document:TextDocument, range:Range, diagnostic:Diagnostic, replaceText:String) {
        var action:CodeAction = createOrGetAction(actions, title, diagnostic);
        action.edit.replace(document.uri, range, replaceText);
    }

    function makeDeleteAction(actions:Map<String, CodeAction>, title:String, document:TextDocument, range:Range, diagnostic:Diagnostic)  {
        var action:CodeAction = createOrGetAction(actions, title, diagnostic);
        action.edit.delete(document.uri, range);
    }
}

@:enum
abstract CheckNames(String) from String {
    var DynamicCheck = "Dynamic";
    var EmptyPackageCheck = "EmptyPackage";
    var IndentationCheck = "Indentation";
    var TraceCheck = "Trace";
}
