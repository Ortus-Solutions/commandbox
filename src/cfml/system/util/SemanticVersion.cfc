/** 
********************************************************************************
Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldbox.org | www.luismajano.com | www.ortussolutions.com
********************************************************************************
* @author Luis Majano & Brad Wood
* Utility to parse and validate semantic versions
* Semantic version: major.minor.revision-alpha.1+build
*/
component{
	
	/**
	* Constructor
	*/
	function init(){
		return this;
	}

	/**
	* Checks if target version is a newer semantic version than the passed current version
	* current.hint The current version of the system
	* target.hint The newer version received
	*/
	boolean function isNew( required string current, required string target ){
		/**
		Semantic version: major.minor.revision-alpha.1+build
		**/

		var current = parseVersion( clean( trim( arguments.current ) ) );
		var target 	= parseVersion( clea( trim( arguments.target ) ) );

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
			target.minor gt current.minor AND
			target.revision gt current.revision ){
			return true;
		}

		// BuildID Check
		if( target.major eq current.major AND
			target.minor gt current.minor AND
			target.revision gt current.revision AND
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
	* Parse the semantic version
	* @return struct:{major,minor,revision,beid,buildid}
	*/
	struct function parseVersion( required string version ){
		var results = { major = 1, minor = 0, revision = 0, beID = "", buildID = 0 };

		// Get build ID first
		results.buildID		= find( "+", arguments.version ) ? listLast( arguments.version, "+" ) : '0';
		// REmove build ID
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

}