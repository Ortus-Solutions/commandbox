/**
 * Remove a property out of the server.json for this server.  Command must be executed from the web root
 * directory of the server where server.json lives.
 * Nested attributes may be set by specifying dot-delimited names or using array notation.
 * .
 * {code:bash}
 * server clear port
 * {code}
 * .
 **/
component {

	property name="serverService" inject="ServerService";
	property name="JSONService" inject="JSONService";

	/**
	 * @property.hint Name of the property to clear
	 * @property.optionsUDF completeProperty
	 * @serverConfigFile The path to the server's JSON file.
	 **/
	function run(
		required string property,
		String serverConfigFile='' ) {

		// As a convenient shorcut, allow the serverConfigFile and propery parameter to be reversed because
		// "server show foo.json name" reads better than "server show name foo.json" but maintains backwards compat
		// for the simple use case of no JSON file as in "server show name"
		var tmpPropertyResolved = fileSystemUtil.resolvePath( arguments.property );
		// Check if the property name end with ".json" and happens to exist as a file on disk, if so it's probably the property file
		if( listLen( arguments.property, '.' ) > 1 && listLast( arguments.property, '.' ) == 'json' && fileExists( tmpPropertyResolved ) ) {
			// If so, swap the property into the server config param.
			arguments.property = arguments.serverConfigFile;
			arguments.serverConfigFile = tmpPropertyResolved;
		} else if( len( arguments.serverConfigFile ) ) {
			arguments.serverConfigFile = fileSystemUtil.resolvePath( arguments.serverConfigFile );
			if( !fileExists( arguments.serverConfigFile ) ) {
				error( 'The serverConfigFile does not exist. [#arguments.serverConfigFile#]' );
			}
		}
		// Default the server.json in the CWD
		var thisServerConfigFile = ( len( arguments.serverConfigFile ) ? arguments.serverConfigFile : getCWD() & '/server.json' );

		var serverJSON = ServerService.readServerJSON( thisServerConfigFile );

		try {
			JSONService.clear( serverJSON, arguments.property );
		} catch( JSONException var e ) {
			error( e.message );
		} catch( any var e ) {
			rethrow;
		}

		print.greenLine( 'Removed #arguments.property#' );

		// Write the file back out.
		ServerService.saveServerJSON( thisServerConfigFile, serverJSON );

	}

	// Dynamic completion for property name based on contents of server.json
	function completeProperty() {
		return serverService.completeProperty( getCWD() );
	}

}
