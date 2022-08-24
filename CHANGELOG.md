
### 1.8.0 (August 24, 2022)

- added code action for CommentedOutCode
- fixed compatibility issue with latest vshaxe [#18](https://github.com/vshaxe/vscode-checkstyle/issues/18)
- updated haxe-checkstyle to 2.8.0

### 1.7.0 (December 30, 2020)

- updated haxe-checkstyle to 2.7.0

### 1.6.1 (December 27, 2019)

- removed unnecessary debug output to the dev console

### 1.6.0 (December 19, 2019)

- updated haxe-checkstyle to 2.6.1
- added code actions for `Final` and `ModifierOrder` checks

### 1.5.0 (December 1, 2019)

- updated haxe-checkstyle to 2.6.0
- added `"haxecheckstyle.codeSimilarityBufferSize"` setting to limit CodeSimilarity buffer size (defaults to: 100)

### 1.4.0 (October 11, 2019)

- updated haxe-checkstyle to 2.5.0

### 1.3.0 (February 4, 2019)

- updated haxe-checkstyle to [d020561](https://github.com/HaxeCheckstyle/haxe-checkstyle/commit/d0205619089c981895c9fb1621e5164ffe979def)
- added a `"haxecheckstyle.externalSourceRoots"` setting ([#14](https://github.com/vshaxe/vscode-checkstyle/pull/14))

### 1.2.0 (July 9, 2018)

- changed to an empty default config (so a `checkstyle.json` is now always needed)
- use tokentree in relaxed mode, tolerating some parser errors

### 1.1.0 (July 1, 2018)

- updated haxe-checkstyle to 2.4.2
- allow `checkstyle.json` in subfolders to take precedence for files within that folder structure
- use configuration parser in relaxed mode, tolerating unknown properties

### 1.0.1 (June 14, 2018)

- fixed an error on extension startup

### 1.0.0 (June 14, 2018)

- initial release with haxe-checkstyle 2.4.1
