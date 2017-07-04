/**
 * View proprties set in server.json for this server.  Command must be executed from the web root
 * directory of the server where server.json lives.  Call with no parameters to view the entire server.json
 * .
 * Outputs port
 * {code:bash}
 * server show port
 * {code}
 * .
 * Nested attributes may be accessed by specifying dot-delimited names or using array notation.
 * If the accessed property is a complex value, the JSON representation will be displayed
 * .
 * {code:bash}
 * server show key1.key2
 * {code}
 * .
 * {code:bash}
 * server show aliases[2]
 * {code}
 *
 **/
component {

	property name="ServerService" inject="ServerService";
	property name="JSONService" inject="JSONService";

	/**
	 * @property.hint The name of the property to show.  Can nested to get "deep" properties
	 * @property.optionsUDF completeProperty
	 * @serverConfigFile The path to the server's JSON file.
	 **/
	function run(
		string property='',
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

		// Read without defaulted values
		var serverJSON = ServerService.readServerJSON( thisServerConfigFile );

		try {

			var propertyValue = JSONService.show( serverJSON, arguments.property );

			if( isSimpleValue( propertyValue ) ) {
				print.line( propertyValue );
			} else {
				print.line( formatterUtil.formatJson( propertyValue ) );
			}

		} catch( JSONException var e ) {
			error( e.message );
		} catch( any var e ) {
			rethrow;
		}

	}

	// Dynamic completion for property name based on contents of box.json
	function completeProperty() {
		return ServerService.completeProperty( getCWD() );
	}
}