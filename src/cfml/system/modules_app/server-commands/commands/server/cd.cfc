/**
 * CD into the web root of a saved server by using its short name.
 * .
 * {code:bash}
 * server cd myServer
 * {code}
 **/
component {

	// DI
	property name="serverService" inject="ServerService";
	property name='parser' 	inject='Parser';

	/**
	 * @name.hint the short name of the server to cd into
	 * @name.optionsUDF serverNameComplete
	 **/
	function run( string name="" ){

		// Discover by shortname
		var serverInfo = serverService.getServerInfoByName( arguments.name );

		// Verify server info
		if( structIsEmpty( serverInfo ) ){
			error( "The server you requested was not found.", "You can use the 'server list' command to get all the available servers." );
		}

		var cdCommand = 'cd ' & '"#parser.escapeArg( serverInfo.webroot )#"';
		print.yellowLine( '> ' & cdCommand );
		runCommand( cdCommand );

	}

	function serverNameComplete() {
		return serverService.serverNameComplete();
	}

}
