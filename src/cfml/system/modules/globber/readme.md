# Globber

I am a utility to match file system path patterns (globbing) in the same manner as Unix file systems.

End a pattern with a slash to only match a directory. Start a pattern with a slash to start in the root. Ex:
* `foo` wil match any file or folder in the directory tree
* `/foo` will only match a file or folder in the root
* `foo/` will only match a directory anywhere in the directory tree
* `/foo/` will only match a folder in the root

Use a single * to match zero or more characters INSIDE a file or folder name (won't match a slash) Ex:
* `foo*` will match any file or folder starting with "foo"
* `foo*.txt` will match any file or folder starting with "foo" and ending with .txt
* `*foo` will match any file or folder ending with "foo"
* `a/*/z` will match `a/b/z` but not `a/b/c/z`

Use a double ** to match zero or more characters including slashes. This allows a pattern to span directories Ex:
* `a/**/z` will match `a/z` and `a/b/z` and `a/b/c/z`

## Usage

```
var globber = wirebox.getInstance( 'PathPatternMatcher@globber' );
globber.matchPattern( '/foo/*', '/foo/bar' );
globber.matchPatterns( [ '/foo/*', '**.txt' ], '/foo/bar' );
```