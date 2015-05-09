/** 
********************************************************************************
Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldbox.org | www.luismajano.com | www.ortussolutions.com
********************************************************************************
* @author Luis Majano & Brad Wood
* Utility to parse and validate semantic versions
* Semantic version: major.minor.revision-alpha.1+build
*/
component singleton{
	
	/**
	* Constructor
	*/
	function init(){
		return this;
	}

	function getDefaultsVersion() {
		return { major = 1, minor = 0, revision = 0, beID = "", buildID = 0 };
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

		var current = parseVersion( clean( trim( arguments.current ) ) );
		var target 	= parseVersion( clean( trim( arguments.target ) ) );

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

		// BuildID verification is turned on?
		if( !arguments.checkBuildID ){ return false; }

		// Build Check
		if( target.major eq current.major AND
			target.minor eq current.minor AND
			target.revision eq current.revision AND
			target.buildID gt current.buildID ){
			return true;
		}

		return false;
	}

	/**
	* Clean a version string from leading = or v
	*/
	string function clean( required version ){
		return reReplaceNoCase( arguments.version, "^(v|=)", "" );
	}

	/**
	* Decides whether a version satisfies a range
	* 
	*/
	boolean function satisfies( required string version, required string range ){
		// TODO: This is just a quick fix.  The satisfies() method needs actually implemented to handle ranges 
		return isEQ( arguments.version, arguments.range );
	}

	/**
	* Parse the semantic version. If no minor found, then 0. If not revision found, then 0. 
	* If not Bleeding Edge bit, then empty. If not buildID, then 0
	* @return struct:{major,minor,revision,beid,buildid}
	*/
	struct function parseVersion( required string version ){
		var results = getDefaultsVersion();

		// Get build ID first
		results.buildID		= find( "+", arguments.version ) ? listLast( arguments.version, "+" ) : '0';
		// Remove build ID
		arguments.version 	= reReplace( arguments.version, "\+([^\+]*).$", "" );
		// Get BE ID Formalized Now we have major.minor.revision-alpha.1
		results.beID		= find( "-", arguments.version ) ? listLast( arguments.version, "-" ) : '';
		// Remove beID
		arguments.version 	= reReplace( arguments.version, "\-([^\-]*).$", "" );
		// Get Revision
		results.revision	= getToken( arguments.version, 3, "." );
		if( results.revision == "" ){ results.revision = 0; }

		// Get Minor + Major
		results.minor		= getToken( arguments.version, 2, "." );
		if( results.minor == "" ){ results.minor = 0; }
		results.major 		= getToken( arguments.version, 1, "." );

		return results;
	}

	/**
	* Parse the incoming version string and conform it to semantic version.
	* If bleeding edge is not found it is omitted.
	* @return string:{major.minor.revision.[beid]+buildid}
	*/
	string function parseVersionAsString( required string version ){
		var sVersion = parseVersion( clean( trim( arguments.version ) ) );
		return getVersionAsString( sVersion );
	}


	/**
	* Parse the incoming version struct and output it as a string
	* @return string:{major.minor.revision.[beid]+buildid}
	*/
	string function getVersionAsString( required struct sVersion ){
		var defaultsVersion = getDefaultsVersion();
		arguments.sVersion = defaultsVersion.append( arguments.sVersion );
		return ( "#sVersion.major#.#sVersion.minor#.#sVersion.revision#"  & ( len( sVersion.beID ) ? "." & sVersion.beID : '' ) & "+#sVersion.buildID#" );
	}

	/**
	* Verifies if the passed version string is in a pre-release state
	*/
	boolean function isPreRelease( required string version ){
		var pVersion = parseVersion( clean( trim( arguments.version ) ) );

		return len( pVersion.beID ) ? true : false;
	}

	/**
	* Checks if the versions are equal
	* current.hint The current version of the system
	* target.hint The target version to check
	*/
	boolean function isEQ( required string current, required string target ){
		/**
		Semantic version: major.minor.revision-alpha.1+build
		**/

		var current = parseVersionAsString( arguments.current );
		var target 	= parseVersionAsString( arguments.target );

		return ( current == target ); 
	}
	
	/**
	* UNIMPLEMENTED
	* True if a specific version, false if a range that could match multiple versions
	* version.hint A string that contains a version or a range
	*/
	boolean function isExactVersion( required string version ) {
		return len( trim( version ) ) > 0;
	}

}