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
