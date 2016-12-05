/** 
********************************************************************************
Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldbox.org | www.luismajano.com | www.ortussolutions.com
********************************************************************************
* @author Luis Majano & Brad Wood
* Utility to parse and validate semantic versions
* Semantic version: major.minor.revision-preReleaseID+build
* http://semver.org/
* https://github.com/npm/node-semver
*/
component singleton{
	
	/**
	* Constructor
	*/
	function init(){
		return this;
	}

	function getDefaultsVersion() {
		return { major = 1, minor = 0, revision = 0, preReleaseID = "", buildID = 0 };
	}

	function compare(
		required string current, 
		required string target,
		boolean checkBuildID=true ) {
			
		// versions are identical
		if( isEQ( arguments.current, arguments.target, checkBuildID ) ) {
			return 0;
		}
			
		// first is 'smaller' than the second
		if( isNew( arguments.current, arguments.target, checkBuildID ) ) {
			return -1;
		// first is 'larger' than the second
		} else {
			return 1;
		}
		
	}

	/**
	* Checks if target version is a newer semantic version than the passed current version
	* Note: To confirm to semvar, I think this needs to defer to gt(). 
	* @current The current version of the system
	* @target The newer version received
	* @checkBuildID If true it will check build equality, else it will ignore it
	* 
	*/
	boolean function isNew( 
		required string current, 
		required string target,
		boolean checkBuildID=true
	){
		/**
		Semantic version: major.minor.revision-alpha.1+build
		**/

		var current = parseVersion( arguments.current );
		var target 	= parseVersion( arguments.target );

		// Major check
		if( target.major gt current.major ){
			return true;
		}

		// Minor Check
		if( target.major eq current.major AND target.minor gt current.minor ){
			return true;
		}

		// Revision Check
		if( target.major eq current.major AND
			target.minor eq current.minor AND
			target.revision gt current.revision ){
			return true;
		}

		// A little hacky, but less code than what I had.  
		// Basically, an empty pre release ID needs to sort AFTER a non-empty one.
		if( !len( target.preReleaseID ) ) { target.preReleaseID = 'zzzzzzzzzzzzzzzzzz'; }
		if( !len( current.preReleaseID ) ) { current.preReleaseID = 'zzzzzzzzzzzzzzzzzz'; }

		// pre-release Check
		if( target.major eq current.major AND
			target.minor eq current.minor AND
			target.revision eq current.revision AND
			// preReleaseID is either alphabetically higher, or target has no prereleaes id and current does.
			target.preReleaseID gt current.preReleaseID ) {
			return true;
		}
		
		// BuildID verification is turned on?
		if( !arguments.checkBuildID ){ return false; }

		// Build Check
		if( target.major eq current.major AND
			target.minor eq current.minor AND
			target.revision eq current.revision AND			
			target.preReleaseID eq current.preReleaseID AND
			target.buildID gt current.buildID ){
			return true;
		}

		return false;
	}

	/**
	* Clean a version string from leading = or v
	*/
	string function clean( required version ){
		version = trim( version );
		return reReplaceNoCase( arguments.version, "^[=v]*", "" );
	}

	/**
	* Decides whether a version satisfies a range
	* 
	*/
	boolean function satisfies( required string version, required string range ){
		
		arguments.version = clean( arguments.version );
		
		if( range == 'be' ) {
			return true;
		}
				
		if( range == 'stable' && !isPreRelease( version ) ) {
			return true;
		} else if( range == 'stable' ) {
			return false;
		}

		// An array of comparator sets.  At least one of the comparator sets needs to 
		// satisfy.  Each comparator of a given comparator set must match for the set to pass.
		var semverRange = buildRange( range );
		
		// Only one of our comparatorSets in the range need to match
		for( var comparatorSet in semverRange ) {
			// If the version we're inspecting is a pre-release, don't consider it unless at least one comparator in this
			// set specifically mentions a pre release matching this major.minor.revision.
			if( isPreRelease( arguments.version ) && !interestedInPreReleasesOfThisVersion( comparatorSet, arguments.version ) ) {
				continue;
			}
			var setResult = false;
			// Each comparator in the set much match
			for( var comparator in comparatorSet ) {
				setResult = evaluateComparator( comparator, arguments.version );
				// Short circuit if at least one comparator in this set has failed
				if( !setResult ) { break; }
			}
			// If this comparatorSet passed, we've seen all we need to see
			if( setResult ) { return true; }
		}
		
		// If we made it here, none of the comparatorSets in our range matched
		return false;
		
		
		return isEQ( arguments.version, arguments.range, false );
	}
		
	private function evaluateComparator( required struct comparator, version ) {
		switch( comparator.operator ) {
		    case "<":
		    	return isNew( arguments.version, comparator.version, false ); 
		         break;
		    case "<=":
		    	return isNew( arguments.version, comparator.version, false ) || isEq( comparator.version, arguments.version, false ); 
		         break;
		    case ">":
		    	return isNew( comparator.version, arguments.version, false );
		         break;
		    case ">=":
		    	return isNew( comparator.version, arguments.version, false ) || isEq( comparator.version, arguments.version, false );
		         break;
		    case "=":
		    	return isEq( comparator.version, arguments.version, false );
		         break;
		    default: 
		         return false;
		}
	}
	
	private function interestedInPreReleasesOfThisVersion( required array comparatorSet, required string version ) {
		var sVersion = parseVersion( arguments.version );
		// Look at each comparator
		for( var comparator in arguments.comparatorSet ) {
			// And see if there is a pre release version that matches major.minor.revision
			if( isPreRelease( comparator.version )
				&& comparator.sVersion.major == sVersion.major
			 	&& comparator.sVersion.minor == sVersion.minor
			 	&& comparator.sVersion.revision == sVersion.revision) {
			 	return true;
			 }
		}
		return false;		 
	}
	
	private function buildRange( required string range ) {
		// A character that I hope will never be part of an actual range so split easier.
		// Comprator sets inside a range are delimited by " || "
		arguments.range = replaceNoCase( arguments.range, ' || ', '•', 'all' );
		var semverRange = listToArray( arguments.range, '•' );
		
		// An empty range becomes *
		if( !arrayLen( semverRange ) ) {
			semverRange = [ '*' ];
		}
		
		// Loop over each comparator set and parse
		semverRange = semverRange.map( function( i ) {
			return buildComparatorSet( i );
		} );
		
		return semverRange;
	}

	private function buildComparatorSet( required string set ) {
		var comparatorSet = [];
		
		// Check for a hyphen range
		if( set contains ' - ' ) {
			set = replaceNoCase( set, ' - ', '•', 'all' );
			var lowerBound = listFirst( set, '•' );
			var upperBound = listLast( set, '•' );
			
			lowerBound = replaceNoCase( lowerBound, '*', 'x', 'all' );
			upperBound = replaceNoCase( upperBound, '*', 'x', 'all' );
			
			sVersion = parseVersion( lowerBound, 'x' );
			
			comparatorSet.append( 
				expandXRanges( {
					operator : '>=',
					sVersion : sVersion,
					version : getVersionAsString( sVersion )
				} ),
				true
			 );
			
			sVersion = parseVersion( upperBound, 'x' );
			
			comparatorSet.append( 
				expandXRanges( {
					operator : '<=',
					sVersion : sVersion,
					version : getVersionAsString( sVersion )
				} ),
				true
			 );
			
			return comparatorSet;
		}
		
		// Comparators are delimited by whitespace
		for( var comparator in listToArray( set, ' ' ) ) {
			
			// standardize * to x
			comparator = replaceNoCase( comparator, '*', 'x', 'all' );
			// >=1.2.3 
			if( comparator.startsWith( '>=' ) ) {
				var version  = right( comparator, len( comparator )-2 );
				var operator = '>=';
			// <=1.2.3
			} else if( comparator.startsWith( '<=' ) ) {
				var version  = right( comparator, len( comparator )-2 );
				var operator = '<=';
			// >1.2.3
			} else if( comparator.startsWith( '>' ) ) {
				var version  = right( comparator, len( comparator )-1 );
				var operator = '>';
			// <1.2.3
			} else if( comparator.startsWith( '<' ) ) {
				var version  = right( comparator, len( comparator )-1 );
				var operator = '<';
			// =1.2.3
			} else if( comparator.startsWith( '=' ) ) {
				var operator = '=';
				var version  = right( comparator, len( comparator )-1 );
			// ~1.2.3
			} else if( comparator.startsWith( '~' ) ) {
				var operator = '~';
				var version  = right( comparator, len( comparator )-1 );
			// ^1.2.3
			} else if( comparator.startsWith( '^' ) ) {
				var operator = '^';
				var version  = right( comparator, len( comparator )-1 );
			// 1.2.3
			} else {
				var version  = comparator;
				var operator = '=';
			}
			
			// Missing bits become x.  So 1.3 becomes 1.3.x
			sVersion = parseVersion( version, 'x' );
			comparatorSet.append(
				// Convert 1.x into multiple comparators 
				expandXRanges( {
					operator : operator,
					sVersion : sVersion,
					version : getVersionAsString( sVersion )
				} ),
				true
			 );
			
		}
		
		return comparatorSet;
	}

	private function expandXRanges( required struct sComparator ) {
		var comparatorSet = [];
		
		switch( sComparator.operator ) {
		    case "<":
		    	// <1.1.x becomes <1.1.0
		    	// <1.x becomes <1.0.0
		
		    	if( sComparator.sVersion.major == 'x' ) { sComparator.sVersion.major = '0'; }
		    	if( sComparator.sVersion.minor == 'x' ) { sComparator.sVersion.minor = '0'; }
		    	if( sComparator.sVersion.revision == 'x' ) { sComparator.sVersion.revision = '0'; }		
		    	sComparator.version = getVersionAsString( sComparator.sVersion );
		    	comparatorSet.append( sComparator ); 
		        break;
		    case "<=":
		    	// <=1.x becomes <2.0.0
		    	if( sComparator.sVersion.minor == 'x' ) {
		    		
		    		sComparator.sVersion.minor = '0';
		    		sComparator.sVersion.revision = '0';
		    		sComparator.sVersion.major=val( sComparator.sVersion.major )+1;
		    		sComparator.operator = '<';
			    	sComparator.version = getVersionAsString( sComparator.sVersion );
			    	comparatorSet.append( sComparator );
			    	
		    	// <=1.0.x becomes <1.1.0
		    	} else if( sComparator.sVersion.revision == 'x' ) {
		    		
		    		sComparator.sVersion.revision = '0';
		    		sComparator.sVersion.minor=val( sComparator.sVersion.minor )+1;
		    		sComparator.operator = '<';
			    	sComparator.version = getVersionAsString( sComparator.sVersion );
			    	comparatorSet.append( sComparator );
			    	
		    	}
		    	else {
			    	comparatorSet.append( sComparator );		    		
		    	} 
		        break;
		    case ">":
		    	// >1.x becomes >=2.0.0
		    	if( sComparator.sVersion.minor == 'x' ) {
		    		
		    		sComparator.sVersion.minor = '0';
		    		sComparator.sVersion.revision = '0';
		    		sComparator.sVersion.major=val( sComparator.sVersion.major )+1;
		    		sComparator.operator = '>=';
			    	sComparator.version = getVersionAsString( sComparator.sVersion );
			    	comparatorSet.append( sComparator );
			    	
		    	// >1.0.x becomes >=1.1.0
		    	} else if( sComparator.sVersion.revision == 'x' ) {
		    		
		    		sComparator.sVersion.revision = '0';
		    		sComparator.sVersion.minor=val(sComparator.sVersion.minor)+1;
		    		sComparator.operator = '>=';
			    	sComparator.version = getVersionAsString( sComparator.sVersion );
			    	comparatorSet.append( sComparator );
			    	
		    	}
		    	else {
			    	comparatorSet.append( sComparator );		    		
		    	}
		        break;
		    case ">=":
		    	// >=1.1.x becomes >=1.1.0
		    	// >=1.x becomes >=1.0.0
		
		    	if( sComparator.sVersion.major == 'x' ) { sComparator.sVersion.major = '0'; }
		    	if( sComparator.sVersion.minor == 'x' ) { sComparator.sVersion.minor = '0'; }
		    	if( sComparator.sVersion.revision == 'x' ) { sComparator.sVersion.revision = '0'; }		
		    	sComparator.version = getVersionAsString( sComparator.sVersion );
		    	comparatorSet.append( sComparator ); 
		        break;
		    case "=":
		    	// * becomes >=0.0.0
		    	if( sComparator.sVersion.major == 'x' ) {
		    		
		    		sComparator.sVersion.major = 0;
		    		sComparator.sVersion.minor = 0;
		    		sComparator.sVersion.revision = 0;
		    		sComparator.operator = '>=';
		    		sComparator.version = getVersionAsString( sComparator.sVersion );
					comparatorSet.append( sComparator );
				
				// 1.x becomes >=1.0.0 < 2.0.0
		    	} else if ( sComparator.sVersion.minor == 'x' ) {
		    		
		    		sComparator.sVersion.minor = 0;
		    		sComparator.sVersion.revision = 0;
		    		sComparator.operator = '>=';
		    		sComparator.version = getVersionAsString( sComparator.sVersion );
					comparatorSet.append( duplicate( sComparator ) );
									
		    		sComparator.sVersion.major=val( sComparator.sVersion.major )+1;
		    		sComparator.operator = '<';
		    		sComparator.version = getVersionAsString( sComparator.sVersion );
					comparatorSet.append( sComparator );					
					
					
				// 1.0.x becomes >=1.0.0 < 1.1.0
		    	} else if( sComparator.sVersion.revision == 'x' ) {
		    				    		
		    		sComparator.sVersion.revision = 0;
		    		sComparator.operator = '>=';
		    		sComparator.version = getVersionAsString( sComparator.sVersion );
					comparatorSet.append( duplicate( sComparator ) );
										
		    		sComparator.sVersion.minor=val( sComparator.sVersion.minor )+1;
		    		sComparator.operator = '<';
		    		sComparator.version = getVersionAsString( sComparator.sVersion );
					comparatorSet.append( sComparator );
		    				    		
		    	} else {
					comparatorSet.append( sComparator );		    		
		    	}
		        break;
		    case "~":
		    	// ~1.2 Same as 1.2.x
				// ~1 Same as 1.x
				// ~0.2 Same as 0.2.x
				// ~0 Same as 0.x
		    	if( sComparator.sVersion.minor== 'x' || sComparator.sVersion.revision== 'x' ) {
		    		sComparator.operator = '=';
		    		// Recursivley handle as an X range
		    		comparatorSet.append( expandXRanges( sComparator ), true );
		    	} else {
		    			    
					// ~0.2.3 becomes >=0.2.3 <0.3.0
			    	// ~1.2.3 becomes >=1.2.3 <1.3.0
		    		sComparator.operator = '>=';
		    		sComparator.version = getVersionAsString( sComparator.sVersion );
			    	comparatorSet.append( duplicate( sComparator ) );
			    	
		    		sComparator.operator = '<';
		    		sComparator.sVersion.minor=val( sComparator.sVersion.minor )+1;
		    		sComparator.sVersion.revision = 0;
		    		sComparator.sVersion.preReleaseID = '';
			    	sComparator.version = getVersionAsString( sComparator.sVersion );
			    	comparatorSet.append( sComparator );
			    }    	 
		        break;
		    case "^":
				// ^1.2.3 becomes >=1.2.3 <2.0.0
				// ^0.2.3 becomes >=0.2.3 <0.3.0
				// ^0.0.3 becomes >=0.0.3 <0.0.4
				// ^1.2.3-beta.2 becomes >=1.2.3-beta.2 <2.0.0 
				// ^1.2.x becomes >=1.2.0 <2.0.0
				// ^0.0.x becomes >=0.0.0 <0.1.0
				// ^0.0 becomes >=0.0.0 <0.1.0
				// ^1.x becomes >=1.0.0 <2.0.0
				// ^0.x becomes >=0.0.0 <1.0.0
	    		var sComparator2 = duplicate( sComparator );
	    		sComparator2.operator = '>=';
		    	if( sComparator2.sVersion.major == 'x' ) { sComparator2.sVersion.major = '0'; }
		    	if( sComparator2.sVersion.minor == 'x' ) { sComparator2.sVersion.minor = '0'; }
		    	if( sComparator2.sVersion.revision == 'x' ) { sComparator2.sVersion.revision = '0'; }	
	    		sComparator2.version = getVersionAsString( sComparator2.sVersion );
		    	comparatorSet.append( sComparator2 );
		    	
	    		sComparator.operator = '<';
	    		sComparator.sVersion.preReleaseID = '';
		    	if( sComparator.sVersion.major != 0 || sComparator.sVersion.minor == 'x' ) {
		    		sComparator.sVersion.major=val( sComparator.sVersion.major )+1;
		    		sComparator.sVersion.minor = 0;
		    		sComparator.sVersion.revision = 0;	
		    	} else if( sComparator.sVersion.minor != 0 || sComparator.sVersion.revision == 'x' ) {
		    		sComparator.sVersion.minor=val( sComparator.sVersion.minor )+1;
		    		sComparator.sVersion.revision = 0;
		    	} else {
		    		sComparator.sVersion.revision=val( sComparator.sVersion.revision )+1;
		    	}
		    	
		    	sComparator.version = getVersionAsString( sComparator.sVersion );
		    	comparatorSet.append( sComparator );
		    	
		        break;
		}
		
		return comparatorSet;
	}

	/**
	* Parse the semantic version. If no minor found, then 0. If not revision found, then 0. 
	* If not Bleeding Edge bit, then empty. If not buildID, then 0
	* @return struct:{major,minor,revision,preReleaseID,buildid}
	*/
	struct function parseVersion( required string version, missingValuePlaceholder ){
		arguments.version = clean( arguments.version );
		var results = getDefaultsVersion();

		// Get build ID first
		results.buildID		= find( "+", arguments.version ) ? listLast( arguments.version, "+" ) : '0';
		// Remove build ID
		arguments.version 	= reReplace( arguments.version, "\+([^\+]*).$", "" );
		// Get preReleaseID Formalized Now we have major.minor.revision-alpha.1
		results.preReleaseID = find( "-", arguments.version ) ? listLast( arguments.version, "-" ) : '';
		// Remove preReleaseID
		arguments.version 	= reReplace( arguments.version, "\-([^\-]*).$", "" );
		// Get Revision
		results.revision	= getToken( arguments.version, 3, "." );
		if( results.revision == "" ){ results.revision = missingValuePlaceholder ?: 0; }

		// Get Minor + Major
		results.minor		= getToken( arguments.version, 2, "." );
		if( results.minor == "" ){ results.minor = missingValuePlaceholder ?: 0; }
		results.major 		= getToken( arguments.version, 1, "." );

		return results;
	}

	/**
	* Parse the incoming version string and conform it to semantic version.
	* If preReleaseID is not found it is omitted.
	* @return string:{major.minor.revision[-preReleaseID]+buildid}
	*/
	string function parseVersionAsString( required string version, boolean includeBuildID=true ){
		var sVersion = parseVersion( arguments.version );
		return getVersionAsString( sVersion, includeBuildID );
	}


	/**
	* Parse the incoming version struct and output it as a string
	* @return string:{major.minor.revision[-preReleaseID]+buildid}
	*/
	string function getVersionAsString( required struct sVersion, boolean includeBuildID=true ){
		var defaultsVersion = getDefaultsVersion();
		arguments.sVersion = defaultsVersion.append( arguments.sVersion );
		if( includeBuildID && sVersion.buildID != 0 ) {
			return ( "#sVersion.major#.#sVersion.minor#.#sVersion.revision#"  & ( len( sVersion.preReleaseID ) ? "-" & sVersion.preReleaseID : '' ) & "+#sVersion.buildID#" );
		} else {
			return ( "#sVersion.major#.#sVersion.minor#.#sVersion.revision#"  & ( len( sVersion.preReleaseID ) ? "-" & sVersion.preReleaseID : '' ) );
		}
	}

	/**
	* Verifies if the passed version string is in a pre-release state
	* Pre-release is defined by the existance of a preRelease ID
	*/
	boolean function isPreRelease( required string version ){
		var pVersion = parseVersion( arguments.version );

		return ( len( pVersion.preReleaseID ) ) ? true : false;
	}

	/**
	* Checks if the versions are equal
	* current.hint The current version of the system
	* target.hint The target version to check
	*/
	boolean function isEQ( required string current, required string target, boolean checkBuildID=true ){
		/**
		Semantic version: major.minor.revision-alpha.1+build
		**/

		var current = parseVersionAsString( arguments.current, checkBuildID );
		var target 	= parseVersionAsString( arguments.target, checkBuildID );

		return ( current == target ); 
	}
	
	/**
	* True if a specific version, false if a range that could match multiple versions
	* version.hint A string that contains a version or a range
	*/
	boolean function isExactVersion( required string version ) {
		// Default any missing pieces to "x" so "3" becomes "3.x.x".
		arguments.version = getVersionAsString (parseVersion( clean( arguments.version ), 'x' ) );
		
		if( version contains '*' ) return false;
		if( version contains 'x.' ) return false;
		if( version contains '.x' ) return false;
		if( version contains '>=' ) return false;
		if( version contains '<=' ) return false;
		if( version contains '<' ) return false;
		if( version contains '>' ) return false;
		if( version contains ' - ' ) return false;
		if( version contains '~' ) return false;
		if( version contains '^' ) return false;
		if( version contains ' || ' ) return false;
		return len( trim( version ) ) > 0;
	}

}