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
	property name='pattern';
	/** The file globbing pattern NOT to match. */
	property name='excludePattern';
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
		variables.pattern = [];
		variables.excludePattern = [];
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
	* Override setter to ensure consistent slashes in pattern
	* Can be list of patterns or array of patterns.
	* Empty patterns will be ignored
	*/
	function setPattern( required any pattern ) {
		if( isSimpleValue( arguments.pattern ) ) {
			arguments.pattern = listToArray( arguments.pattern );
		}
		arguments.pattern = arguments.pattern.map( function( p ) {
			return pathPatternMatcher.normalizeSlashes( arguments.p );
		}).filter( function( p ){
			return len( arguments.p );
		} );
		variables.pattern = arguments.pattern;
		return this;
	}

	/**
	* Add additional pattern to process
	*/
	function addPattern( required string pattern ) {
		if( len( arguments.pattern ) ) {
			variables.pattern.append( arguments.pattern  );
		}
		return this;
	}

	/**
	* Always returns a string which is a list of patterns
	*/
	function getPattern() {
		return variables.pattern.toList();
	}

	/**
	*
	*/
	function getPatternArray() {
		return variables.pattern;
	}


	/**
	* Can be list of excludePatterns or array of excludePatterns.
	* Empty excludePatterns will be ignored
	*/
	function setExcludePattern( required any excludePattern ) {
		if( isSimpleValue( arguments.excludePattern ) ) {
			arguments.excludePattern = listToArray( arguments.excludePattern );
		}
		arguments.excludePattern = arguments.excludePattern.map( function( p ) {
			return pathPatternMatcher.normalizeSlashes( arguments.p );
		}).filter( function( p ){
			return len( arguments.p );
		} );
		variables.excludePattern = arguments.excludePattern;
		return this;
	}

	/**
	* Add additional excludePattern to process
	*/
	function addExcludePattern( required string excludePattern ) {
		if( len( arguments.excludePattern ) ) {
			variables.excludePattern.append( arguments.excludePattern  );
		}
		return this;
	}

	/**
	* Always returns a string which is a list of excludePatterns
	*/
	function getExcludePattern() {
		return variables.excludePattern.toList();
	}

	/**
	*
	*/
	function getExcludePatternArray() {
		return variables.excludePattern;
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
		return getFormat() == 'query' ? matches().recordCount : matches().len();
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
		var patterns = getPatternArray();

		if( !patterns.len() ) {
			throw( 'Cannot glob empty pattern.' );
		}

		for( var thisPattern in patterns ) {
			processPattern( thisPattern );
		}

		var matchQuery = getMatchQuery();

		if( isNull( matchQuery ) ) {
			setMatchQuery( queryNew( 'name,size,type,dateLastModified,attributes,mode,directory' ) );
		} else {
			// UNION isn't removing dupes on Lucee so doing second select here for that purpose.
			cfquery( dbtype="query" ,name="local.newMatchQuery" ) {
				writeOutput( 'SELECT DISTINCT * FROM matchQuery ' );
				if( len( getSort() ) ) {
					writeOutput( 'ORDER BY #getCleanSort()#' );
				}
			}

			setMatchQuery( local.newMatchQuery );
		}


		if( patterns.len() > 1 ) {
			var dirs = queryColumnData( getMatchQuery(), 'directory' );
			var lookups = {};
			dirs.each( function( dir ) {
				// Account for *nix paths & Windows UNC network shares
				var prefix = '';
				if( dir.startsWith( '/' ) ) {
					prefix = '/';
				} else if( dir.startsWith( '\\' ) ) {
					prefix = '//';
				}
				evaluate( 'lookups["#prefix##dir.listChangeDelims( '"]["', '/\' )#"]={}' );
			} );
			var findRoot = function( lookups ){
				if( lookups.count() == 1 ) {
					return lookups.keyList() & '/' & findRoot( lookups[ lookups.keyList() ] );
				} else {
					return '';
				}
			}
			setBaseDir( findRoot( lookups ) );
		}

	}

	function appendMatchQuery( matchQuery ) {
		// First one in just gets set
		if( isNull( getMatchQuery() ) ) {
			setMatchQuery( matchQuery );
		// merge remaining patterns
		} else {
			var previousMatch = getMatchQuery();

			cfquery( dbtype="query" ,name="local.newMatchQuery" ) {
				writeOutput( 'SELECT * FROM matchQuery UNION SELECT * FROM previousMatch ' );
			}

			setMatchQuery( local.newMatchQuery );
		}
	}

	private function processPattern( string pattern ) {

		local.thisPattern = pathPatternMatcher.normalizeSlashes( arguments.pattern );

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

		var everythingAfterBaseDir = thisPattern.replace( baseDir, '' );

		// If we have a partial directory next such as modules* optimize here
		if( everythingAfterBaseDir.listLen( '/' ) > 1 && everythingAfterBaseDir.listFirst( '/' ).reFind( '[^\*^\?]' ) && !everythingAfterBaseDir.listFirst( '/' ).startsWith( '**' ) ) {

			thisPattern = baseDir & '/' & everythingAfterBaseDir.listFirst( '/' ) & '/';
			// Manually loop over the dirs at this level that match to narrow what we're looking at
			directoryList (
				listInfo='query',
				recurse=false,
				path=baseDir,
				type='dir',
				sort=getSort(),
				filter=( path )=>{
					var thisPath = path & '/';
					if( pathPatternMatcher.matchPattern( thisPattern, thisPath, true ) ) {
						return true;
					}
					return false;
				}
			).each( ( folder )=>processPattern( baseDir & '/' & folder.name & '/' & everythingAfterBaseDir.listRest( '/' ) ) )

			return;
		}

		var recurse = false;
		if( thisPattern contains '**' ) {
			recurse = true;
		}

		var optimizeFilter = '';
		if( reFind( '\.[a-zA-Z0-9\?\*]{2,4}$', thisPattern ) ) {
			optimizeFilter = '*.' & thisPattern.listLast( '.' ).replace( '?', '*', 'all' );
		}

		var dl = directoryList (
				listInfo='query',
				recurse=local.recurse,
				path=baseDir,
				sort=getSort(),
				filter=optimizeFilter
			).filter( ( path )=>{
				var thisPath = path.directory & '/' & path.name & ( path.type == 'dir' ? '/' : '' );
				if( pathPatternMatcher.matchPattern( thisPattern, thisPath, true ) ) {
					if( getExcludePatternArray().len() && pathPatternMatcher.matchPatterns( getExcludePatternArray(), thisPath, true ) ) {
						return false;
					}
					return true;
				}
				return false;
			} );

		appendMatchQuery( dl );
		setBaseDir( baseDir & ( baseDir.endsWith( '/' ) ? '' : '/' ) );

	}

	/**
	* The sort function in CFDirectory will simply ignore invalid sort columns so I'm mimicking that here, as much as I dislike it.
	* The sort should be in the format of "col asc, col2 desc, col3, col4" like a SQL order by
	* If any of the columns or sort directions don't look right, just bail and return the default sort.
	*/
	function getCleanSort() {
		// Loop over each sort item
		for( var item in listToArray( getSort() ) ) {
			// Validate column name
			if( !listFindNoCase( 'name,directory,size,type,dateLastModified,attributes,mode', trim( item.listFirst( ' 	' ) ) ) ) {
				return 'type, name';
			}
			// Validate sort direction
			if( item.listLen( ' 	' ) == 2 && !listFindNoCase( 'asc,desc', trim( item.listLast( ' 	' ) ) ) ) {
				return 'type, name';
			}
			// Ensure no more than 2 tokens
			if( item.listLen( ' 	' ) > 2 ) {
				return 'type, name';
			}
		}
		// Ok, everything passes.
		return getSort();
	}

}
