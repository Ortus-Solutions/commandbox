/**
*********************************************************************************
* Copyright Since 2014 by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood
*
* I am a utility to match file system path patterns
*
* End a pattern with a slash to only match a directory. Start a pattern with a slash to start in the root. Ex:
* - foo will match any file or folder in the directory tree
* - /foo will only match a file or folder in the root
* - foo/ will only match a directory anywhere in the directory tree
* - /foo/ will only match a folder in the root
*
* Use a single * to match zero or more characters INSIDE a file or folder name (won't match a slash) Ex:
* - foo* will match any file or folder starting with "foo"
* - foo*.txt will match any file or folder starting with "foo" and ending with .txt
* - *foo will match any file or folder ending with "foo"
* - a/* /z will match a/b/z but not a/b/c/z
*
* Use a double ** to match zero or more characters including slashes. This allows a pattern to span directories Ex:
* - a/** /z will match a/z and a/b/z and a/b/c/z
*
* A question mark matches a single non-slash character
* - /h?t matches hat but not ham or h/t
*
*/
component accessors="true" singleton {

	function init() {
		return this;
	}

	/**
	* Match a single path to a single pattern.  Returns true if the path matches the pattern, otherwise false.
	* @pattern The pattern to match against the path
	* @path The file system path to test.  Can be a file or directory.  Direcories MUST end with a trailing slash
	* @exact True if the full path needs to match.  False to match inside a path
	*/
	boolean function matchPattern( required string pattern, required string path, boolean exact=false ) {
		// Normalize slashes
		// This will turn a Windows UNC path into //server, but it will at least be consitent across pattern and path
		arguments.pattern = replace( arguments.pattern, '\', '/', 'all' );
		arguments.path = replace( arguments.path, '\', '/', 'all' );

		if( !exact ) {
			// Start all paths with /
			arguments.path = ( arguments.path.startsWith( '/' ) ? arguments.path : '/' & arguments.path );
		}

		// build a regex based on the pattern
		var regex = arguments.pattern;

		// Escape any regex metacharacters in the pattern
		regex = replace( regex, '.', '\.', 'all' );
		regex = replace( regex, '(', '\(', 'all' );
		regex = replace( regex, ')', '\)', 'all' );
		regex = replace( regex, '^', '\^', 'all' );
		regex = replace( regex, '$', '\$', 'all' );
		regex = replace( regex, '|', '\|', 'all' );
		regex = replace( regex, '+', '\+', 'all' );
		regex = replace( regex, '{', '\{', 'all' );
		regex = replace( regex, '}', '\}', 'all' );

		// /**/ matches zero or more directories (at least one /)
		regex = replace( regex, '/**/', '__zeroOrMoreDirs_', 'all' );
		// Double ** matches anything
		regex = replace( regex, '**', '__anything_', 'all' );
		// Single * matches anything BUT slash
		regex = replace( regex, '*', '__anythingButSlash__', 'all' );
		// ? matches any single non-slash character
		regex = replace( regex, '?', '__singleNonSlash__', 'all' );

		// Switch placeholders for actual regex
		regex = replace( regex, '__zeroOrMoreDirs_', '(/.*/|/)', 'all' );
		regex = replace( regex, '__anything_', '.*', 'all' );
		regex = replace( regex, '__anythingButSlash__', '[^/]*', 'all' );
		regex = replace( regex, '__singleNonSlash__', '[^/]', 'all' );

		// If the pattern doesn't come with an explicit ending slash, add an optional one
		// so we can match ending files OR folders
		if( !regex.endsWith( '/' ) ) {
			regex &= '/?';
		}

		// If pattern starts with slash
		if( regex.startsWith( '/' ) || exact ) {
			// add a ^ to match start of string
			regex = '^' & regex;
		} else {
			// Otherwise, anything can precede this pattern
			regex = '.*' & regex;
		}
		if( exact ) {
			regex &= '$';
		// Anything can follow this pattern
		} else {
			regex &= '.*';
		}
		
		return ( reFindNoCase( regex, arguments.path ) > 0 );
	}

	/**
	* Match an array of patterns against a single path.  Returns true if at least one pattern matches, otherwise false.
	* @patterns.hint An array of patterns to match against the path
	* @path.hint The file system path to test.  Can be a file or directory.  Direcories MUST end with a trailing slash
	*/
	boolean function matchPatterns( required array patterns, required string path, boolean exact=false ){
		var matched = false;
		for( var pattern in arguments.patterns ) {
			if ( isExclusion( pattern ) ) {
				var patternWithoutBang = mid( pattern, 2, len( pattern ) - 1 );
				if ( matchPattern( patternWithoutBang, arguments.path, arguments.exact ) ) {
					matched = false;
				}
			}
			else {
				if ( matchPattern( pattern, arguments.path, arguments.exact ) ) {
					matched = true;
				}
			}
		}
		return matched;
	}

	boolean function isExclusion( required string pattern ) {
		return left( pattern, 1 ) == "!";
	}
	
	/*
	* Turns all slashes in a path to forward slashes except for \\ in a Windows UNC network share
	*/
	function normalizeSlashes( string path ) {
		if( path.left( 2 ) == '\\' ) {
			return '\\' & path.replace( '\', '/', 'all' ).right( -2 );
		} else {
			return path.replace( '\', '/', 'all' );			
		}
	}

}
