/**
 * Set values set in server.json for this server.  Command must be executed from the web root
 * directory of the server where server.json lives.
 * .
 * set server port
 * {code:bash}
 * server set web.http.port=8080
 * {code}
 * .
 * Nested attributes may be set by specifying dot-delimited names or using array notation.
 * If the set value is JSON, it will be stored as a complex value in the server.json.
 * .
 * Set a nested key
 * {code:bash}
 * server set extra.info=value
 * {code}
 * .
 * set an item in an array
 * {code:bash}
 * server set aliases[1]="/js"
 * {code}
 * .
 * Set multiple params at once
 * {code:bash}
 * server set name=myServer web.http.port=8080
 * {code}
 * .
 * Set complex value as JSON
 * {code:bash}
 * server set aliases="[ '/js', '/css' ]"
 * {code}
 * .
 * Structs and arrays can be appended to using the "append" parameter.
 * .
  * This only works if the property and incoming value are both of the same complex type.
 * {code:bash}
 * server set aliases="[ '/includes' ]" --append
 * {code}
 *
 **/
component {

	property name="ServerService" inject="ServerService";
	property name="JSONService" inject="JSONService";

	/**
	 * This param is a dummy param just to get the custom completor to work.
	 * The actual parameter names will be whatever property name the user wants to set
	 * @_.hint Pass any number of property names in followed by the value to set
	 * @_.optionsUDF completeProperty
	 * @serverConfigFile The path to the server's JSON file.
	 * @append.hint If setting an array or struct, set to true to append instead of overwriting.
	 **/
	function run(
		_,
		String serverConfigFile='',
		boolean append=false ) {

		var thisAppend = arguments.append;

		if( len( arguments.serverConfigFile ) ) {
			arguments.serverConfigFile = fileSystemUtil.resolvePath( arguments.serverConfigFile );
		}
		var thisServerConfigFile = ( len( arguments.serverConfigFile ) ? arguments.serverConfigFile : getCWD() & '/server.json' );

		// Remove dummy args
		structDelete( arguments, '_' );
		structDelete( arguments, 'append' );
		structDelete( arguments, 'serverConfigFile' );

		var serverJSON = ServerService.readServerJSON( thisServerConfigFile );

		var results = JSONService.set( serverJSON, arguments, thisAppend );

		// Write the file back out.
		ServerService.saveServerJSON( thisServerConfigFile, serverJSON );

		for( var message in results ) {
			print.greeLine( message );
		}

	}

	// Dynamic completion for property name based on contents of server.json
	function completeProperty() {
		// all=true will cause "server set" to prompt all possible server.json properties
		return ServerService.completeProperty( getCWD(), true, true );
	}
}