[![Build Status](https://travis-ci.org/Ortus-Solutions/globber.svg?branch=master)](https://travis-ci.org/Ortus-Solutions/globber)

I am a utility to match file system path patterns (globbing) in the same manner as Unix file systems.

## Installation

Run  the following in CommandBox:

```
install globber
```

## Usage

Inject the path pattern matcher service/Globber or get it from WireBox.

### Path Pattern Matcher

This service is a singleton that handles path matching but doesn't actually touch the file system.  

```
var pathPatternMatcher = wirebox.getInstance( 'PathPatternMatcher@globber' );
pathPatternMatcher.matchPattern( '/foo/*', '/foo/bar' );
pathPatternMatcher.matchPatterns( [ '/foo/*', '**.txt' ], '/foo/bar' );
```

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

A question mark matches a single non-slash character

* `/h?t` matches `hat` but not `ham` or `h/t`

### Globber	

This transient represents a single globbing pattern and provide a fluent API to access the matching files.  Unlike the PathPatternMatcher, which only handles comparisons of patterns, this model actually interacts with the file system to resolve a pattern to a list of real file system resources.

Finds any text files recursivley below the `myFolder` directory whos name end with `bar`.
```
var results = wirebox.getInstance( 'globber' )
	.setPattern( 'C:/myFolder/**/*bar.txt' )
	matches();
```

Apply a closure to a markdown files in a directory.
```
wirebox.getInstance( 'globber' )
	.setPattern( 'C:/myFolder/*.md' )
	apply( function( path ) {
		fileDelete( path );
	} );
```

