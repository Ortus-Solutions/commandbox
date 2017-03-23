/**
*********************************************************************************
* Copyright Since 2014 by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood
*
* I represent a single globbing pattern and provide a fluent API to access the matching files
* Unlike the PathPatternMatcher, which only handles comparisons of patterns, this model
* actually interacts with the file system to resolve a pattern to a list of real file system
* resources.
*
*/
component accessors="true" {
	// DI
	property name='pathPatternMatcher' inject='pathPatternMatcher@globber';

	/** The file globbing pattern to match. */
	property name='pattern' default='';
	/** Array of real file system resources that match the pattern */
	property name='matchArray';
	/** "file", "dir", or "all" (default) */
	// property name='type';
	

	function init() {
		return this;
	}
	
	/**
	* Override setter to ensure consistent slashe in pattern
	*/
	function setPattern( required string pattern ) {
		variables.pattern = arguments.pattern.replace( '\', '/', 'all' );
		return this;
	}
	
	/**
	* Pass a closure to this function to have it
	* applied to each paths matched by the pattern.
	*/
	function apply( udf ) {
		ensureMatches();
		getMatchArray().each( udf );
		return this;
	}
	
	/**
	* Get array of matched file system paths
	*/
	function matches() {
		ensureMatches();
		return getMatchArray();
	}
	
	/**
	* Make sure the matchArray has been loaded.
	*/
	private function ensureMatches() {
		if( isNull( getMatchArray() ) ) {
			process();
		}
	}

	/**
	* Load matching file from the file system
	*/
	private function process() {
		local.thisPattern = getPattern();
		if( !thisPattern.len() ) {
			throw( 'Cannot glob empty pattern.' );
		}
		
		// If there's no wildcard, this is not a glob, so just pass it in as the only matched path
		if( !thisPattern contains '*' && !thisPattern contains '?' ) {
			setMatchArray( [ pattern ] );
			return;
		}
		
		// To optimize this as much as possible, we want to get a directory listing as deep as possible so we process a few files as we can.
		// Find the deepest folder that doesn't have a wildcard in it.
		var baseDir = '';
		var i = 0;
		while( ++i <= thisPattern.listLen( '/' ) ) {
			var token = thisPattern.listGetAt( i, '/' );
			if( token contains '*' || token contains '?' ) {
				break;
			}
			baseDir = baseDir.listAppend( token, '/' );
		}
		
		if( !baseDir.len() ) {
			baseDir = '/';
		}
		
		var recurse = false;
		if( thisPattern contains '**' ) {
			recurse = true;
		}

		setMatchArray(
			directoryList (
				filter=function( path ){
					if( pathPatternMatcher.matchPattern( thisPattern, path, true ) ) {
						return true;
					}
					return false;
				},
				recurse=local.recurse, 
				path=baseDir
			)
		);
		
	}

}