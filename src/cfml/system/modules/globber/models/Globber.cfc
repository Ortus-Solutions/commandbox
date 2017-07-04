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
	/** query of real file system resources that match the pattern */
	property name='matchQuery';
	/** Return matches as a query instead of an array */
	property name='format' default='array';
	/** Sort to use */
	property name='sort' default='type, name';
	/** Directory the list was pulled from */
	property name='baseDir' default='';


	function init() {
		variables.format = 'array';
		return this;
	}

	/**
	* Return results as query
	*/
	function asQuery() {
		setFormat( 'query' );
		return this;
	}

	/**
	* Return results as array
	*/
	function asArray() {
		setFormat( 'array' );
		return this;
	}

	/**
	* Return results as array
	*/
	function withSort( thisSort ) {
		setSort( thisSort );
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
		matches().each( udf );
		return this;
	}

	/**
	* Get array of matched file system paths
	*/
	function matches() {
		ensureMatches();
		if( getFormat() == 'query' ) {
			return getMatchQuery();
		} else {
			return getMatchQuery().reduce( function( arr, row ) {
				// Turn all the slashes the right way for this OS
				return arr.append( row.directory & '/' & row.name & ( row.type == 'Dir' ? '/' : '' ) );
			}, [] );
		}
	}

	/**
	* Get count of matched files
	*/
	function count() {
		return matches().len();
	}

	/**
	* Make sure the MatchQuery has been loaded.
	*/
	private function ensureMatches() {
		if( isNull( getMatchQuery() ) ) {
			process();
		}
	}

	/**
	* Load matching file from the file system
	*/
	private function process() {
		local.thisPattern = getPattern().replace( '\', '/', 'all' );

		if( !thisPattern.len() ) {
			throw( 'Cannot glob empty pattern.' );
		}

		// To optimize this as much as possible, we want to get a directory listing as deep as possible so we process a few files as we can.
		// Find the deepest folder that doesn't have a wildcard in it.
		var baseDir = '';
		var i = 0;
		// Skip last token
		while( ++i < thisPattern.listLen( '/' ) ) {
			var token = thisPattern.listGetAt( i, '/' );
			if( token contains '*' || token contains '?' ) {
				break;
			}
			baseDir = baseDir.listAppend( token, '/' );
		}
		// Unix paths need the leading slash put back
		if( thisPattern.startsWith( '/' ) ) {
			baseDir = '/' & baseDir;
		}

		// Windows drive letters need trailing slash.
		if( baseDir.listLen( '/' ) == 1 && baseDir contains ':' ) {
			baseDir = baseDir & '/';
		}

		if( !baseDir.len() ) {
			baseDir = '/';
		}

		var recurse = false;
		if( thisPattern contains '**' ) {
			recurse = true;
		}

		setMatchQuery(
			directoryList (
				filter=function( path ){
					if( pathPatternMatcher.matchPattern( thisPattern, path & ( directoryExists( path ) ? '/' : '' ), true ) ) {
						return true;
					}
					return false;
				},
				listInfo='query',
				recurse=local.recurse,
				path=baseDir,
				sort=getSort()
			)
		);
		setBaseDir( baseDir );

	}

}
