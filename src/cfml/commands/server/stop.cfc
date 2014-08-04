/**
 * Stop an embedded CFML server.  Run command from the web root of the server, or use the short name.
 * .
 * {code}
 * server stop
 * server stop name=serverName
 * server stop name=serverName --forget
 * {code}
 **/
component extends="commandbox.system.BaseCommand" aliases="stop" excludeFromHelp=false {

	// DI
	property name="serverService" inject="ServerService";
	
	/**
	 * Stop a server instance
	 *
	 * @directory.hint web root for the server
	 * @name.hint the short name of the server to stop
	 * @forget.hint if passed, this will also remove the directory information from disk
	 **/
	function run( String directory="", String name="", boolean forget=false ){
		// Discover by shortname or webroot
		var serverInfo = serverService.getServerInfoByDiscovery( arguments.directory, arguments.name );

		// Verify server info
		if( structIsEmpty( serverInfo ) ){
			error( "The server you requested to stop was not found (webroot=#arguments.directory#, name=#arguments.name#)." );
			print.line( "You can use the 'server status showAll=true' command to get all the available servers." );
			return;
		}

		var results = serverService.stop( serverInfo );
		if( results.error ){
			error( results.messages );
		} else {
			return results.messages;
		}
	}

}