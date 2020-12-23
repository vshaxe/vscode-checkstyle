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

using StringTools;

class CheckstyleCodeActions {
	public function new() {}

	public function provideCodeActions(document:TextDocument, range:Range, context:CodeActionContext,
			token:CancellationToken):ProviderResult<Array<EitherType<Command, CodeAction>>> {
		var commands:Array<EitherType<Command, CodeAction>> = [];

		var actions:Map<String, CodeAction> = new Map<String, CodeAction>();
		for (diag in context.diagnostics) {
			if (diag.source != "checkstyle") {
				continue;
			}
			if (range.intersection(diag.range) == null) {
				continue;
			}
			makeCheckAction(document, actions, diag);
		}

		for (name in actions.keys()) {
			commands.push(actions.get(name));
		}
		return commands;
	}

	public function resolveCodeAction(codeAction:CodeAction, token:CancellationToken):ProviderResult<CodeAction> {
		return codeAction;
	}

	function makeCheckAction(document:TextDocument, actions:Map<String, CodeAction>, diag:Diagnostic) {
		var index = diag.message.indexOf(" - ");
		if (index <= 0) {
			return;
		}
		var checkName:CheckNames = diag.message.substr(0, index);
		var message = diag.message.substr(index + 3);
		switch (checkName) {
			case DynamicCheck:
				makeDynamicAction(document, actions, diag, message);
			case EmptyPackageCheck:
				makeEmptyPackageAction(document, actions, diag, message);
			case FinalCheck:
				makeFinalAction(document, actions, diag, message);
			case IndentationCheck:
				makeIndentationAction(document, actions, diag, message);
			case ModifierOrderCheck:
				makeModifierOrderAction(document, actions, diag, message);
			case RedundantModifierCheck:
				makeRedundantModifierAction(document, actions, diag, message);
			case StringLiteralCheck:
				makeStringLiteralAction(document, actions, diag, message);
			case TraceCheckCheck:
				makeTraceCheckAction(document, actions, diag, message);
			case UnusedImportCheck:
				makeUnusedImportAction(document, actions, diag, message);
		}
	}

	function makeDynamicAction(document:TextDocument, actions:Map<String, CodeAction>, diag:Diagnostic, message:String) {
		var replace = document.getText(diag.range).replace("Dynamic", "Any");
		replaceAction(actions, "Replace with Any", document, diag.range, diag, replace);
	}

	function makeEmptyPackageAction(document:TextDocument, actions:Map<String, CodeAction>, diag:Diagnostic, message:String) {
		var code:checkstyle.checks.design.EmptyPackageCheck.EmptyPackageCode = cast diag.code;
		switch (code) {
			case MISSING_PACKAGE:
				insertAction(actions, "Add package declaration", document, diag.range.start, diag, "package;\n");
			case REDUNDANT_PACKAGE:
				deleteAction(actions, "Remove package declaration", document, diag.range, diag);
		}
	}

	function makeFinalAction(document:TextDocument, actions:Map<String, CodeAction>, diag:Diagnostic, message:String) {
		var code:checkstyle.checks.modifier.FinalCheck.FinalCode = cast diag.code;
		switch (code) {
			case USE_INLINE_FINAL:
				var modifierRange = new Range(diag.range.start, diag.range.start.translate(0, 3));
				replaceAction(actions, "Change to final", document, modifierRange, diag, "final");
			case SHOULD_BE_PUBLIC_FINAL:
				var modifierRange = new Range(diag.range.start, diag.range.start.translate(0, 3));
				replaceAction(actions, "Change to final", document, modifierRange, diag, "final");

				var line = document.lineAt(diag.range.start);
				var index = line.text.indexOf("public ");
				if (index < 0) {
					return;
				}
				var modifierPos = document.positionAt(document.offsetAt(line.range.start) + index);
				modifierRange = new Range(modifierPos, modifierPos.translate(0, 6));
				replaceAction(actions, "Change to private", document, modifierRange, diag, "private");
		}
	}

	function makeIndentationAction(document:TextDocument, actions:Map<String, CodeAction>, diag:Diagnostic, message:String) {
		var reg = ~/expected: "([^"]+)"/;
		if (!reg.match(message)) {
			return;
		}
		var replacement = reg.matched(1).replace("\\t", "\t");
		replaceAction(actions, "Fix indentation", document, diag.range, diag, replacement);
	}

	function makeModifierOrderAction(document:TextDocument, actions:Map<String, CodeAction>, diag:Diagnostic, message:String) {
		var reg = ~/ is "([^"]+)" but should be "([^"]+)"/;
		if (!reg.match(message)) {
			return;
		}
		var actual = reg.matched(1);
		var expected = reg.matched(2);
		var line = document.lineAt(diag.range.start);
		var index = line.text.indexOf(actual + " ");
		if (index < 0) {
			return;
		}
		var startPos = document.positionAt(document.offsetAt(line.range.start) + index);
		var modifierRange = new Range(startPos, startPos.translate(0, actual.length));
		replaceAction(actions, "Adjust modifier order", document, modifierRange, diag, expected);
	}

	function makeRedundantModifierAction(document:TextDocument, actions:Map<String, CodeAction>, diag:Diagnostic, message:String) {
		var code:checkstyle.checks.modifier.RedundantModifierCheck.RedundantModifierCode = cast diag.code;
		switch (code) {
			case MISSING_PUBLIC, MISSING_PRIVATE:
				var modifier = (code == MISSING_PUBLIC) ? "public" : "private";
				insertAction(actions, "Add public/private modifier", document, diag.range.start, diag, '$modifier ');
			case REDUNDANT_PUBLIC, REDUNDANT_PRIVATE:
				var modifier = (code == REDUNDANT_PUBLIC) ? "public" : "private";
				var line = document.lineAt(diag.range.start);
				var index = line.text.indexOf('$modifier ');
				if (index == -1) {
					return;
				}
				var modifierPos = document.positionAt(document.offsetAt(line.range.start) + index);
				var modifierRange = new Range(modifierPos, modifierPos.translate(0, modifier.length + 1));
				replaceAction(actions, "Remove public/private modifier", document, modifierRange, diag, "");
		}
	}

	function makeStringLiteralAction(document:TextDocument, actions:Map<String, CodeAction>, diag:Diagnostic, message:String) {
		var code:checkstyle.checks.literal.StringLiteralCheck.StringLiteralCode = cast diag.code;
		var text:String = null;
		var quote:String = null;
		switch (code) {
			case USE_DOUBLE_QUOTES:
				text = "Change single quotes to double quotes";
				quote = '"';
			case USE_SINGLE_QUOTES:
				text = "Change double quotes to single quotes";
				quote = "'";
		}
		if (text == null) {
			return;
		}
		var quoteRange = new Range(diag.range.start, diag.range.start.translate(0, 1));
		replaceAction(actions, text, document, quoteRange, diag, quote);
		quoteRange = new Range(diag.range.end, diag.range.end.translate(0, -1));
		replaceAction(actions, text, document, quoteRange, diag, quote);
	}

	function makeTraceCheckAction(document:TextDocument, actions:Map<String, CodeAction>, diag:Diagnostic, message:String) {
		deleteAction(actions, "Delete trace", document, diag.range, diag);

		var prefix = document.getText(new Range(diag.range.start.line, 0, diag.range.start.line, diag.range.start.character));
		if (~/\s+/.match(prefix)) {
			prefix = "\n" + prefix;
		} else {
			prefix = " ";
		}
		insertAction(actions, "Add suppression", document, diag.range.start, diag, '@SuppressWarning("checkstyle:Trace")' + prefix);
	}

	function makeUnusedImportAction(document:TextDocument, actions:Map<String, CodeAction>, diag:Diagnostic, message:String) {
		var line = document.lineAt(diag.range.start);
		var importRange = diag.range;
		if (line.range.isEqual(diag.range)) {
			importRange = new Range(diag.range.start, new Position(importRange.end.line + 1, 0));
		}

		var code:checkstyle.checks.imports.UnusedImportCheck.UnusedImportCode = cast diag.code;
		switch (code) {
			case UNUSED_IMPORT, TOPLEVEL_IMPORT, SAME_PACKAGE, DUPLICATE_IMPORT:
				deleteAction(actions, "Cleanup imports", document, importRange, diag);
			case MULTIPLE_PACKAGE:
		}
	}

	function createOrGetAction(actions:Map<String, CodeAction>, title:String, diagnostic:Diagnostic):CodeAction {
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

	function insertAction(actions:Map<String, CodeAction>, title:String, document:TextDocument, pos:Position, diagnostic:Diagnostic, insertText:String) {
		var action:CodeAction = createOrGetAction(actions, title, diagnostic);
		action.edit.insert(document.uri, pos, insertText);
	}

	function replaceAction(actions:Map<String, CodeAction>, title:String, document:TextDocument, range:Range, diagnostic:Diagnostic, replaceText:String) {
		var action:CodeAction = createOrGetAction(actions, title, diagnostic);
		action.edit.replace(document.uri, range, replaceText);
	}

	function deleteAction(actions:Map<String, CodeAction>, title:String, document:TextDocument, range:Range, diagnostic:Diagnostic) {
		var action:CodeAction = createOrGetAction(actions, title, diagnostic);
		action.edit.delete(document.uri, range);
	}
}

enum abstract CheckNames(String) from String {
	var DynamicCheck = "Dynamic";
	var EmptyPackageCheck = "EmptyPackage";
	var FinalCheck = "Final";
	var IndentationCheck = "Indentation";
	var ModifierOrderCheck = "ModifierOrder";
	var RedundantModifierCheck = "RedundantModifier";
	var StringLiteralCheck = "StringLiteral";
	var TraceCheckCheck = "Trace";
	var UnusedImportCheck = "UnusedImport";
}
