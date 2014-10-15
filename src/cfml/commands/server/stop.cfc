/**
 * Stop an embedded CFML server.  Run command from the web root of the server, or use the short name.
 * .
 * {code:bash}
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
		// resolve path
		arguments.directory = fileSystemUtil.resolvePath( arguments.directory );

		// Discover by shortname or webroot and get server info
		var serverInfo = serverService.getServerInfoByDiscovery(
			directory 	= arguments.directory,
			name		= arguments.name
		);

		// Verify server info
		if( structIsEmpty( serverInfo ) ){
			error( "The server you requested to stop was not found (webroot=#arguments.directory#, name=#arguments.name#)." );
			print.line( "You can use the 'server status showAll=true' command to get all the available servers." );
			return;
		}

		// Stop the server
		var results = serverService.stop( serverInfo );
		if( results.error ){
			error( results.messages );
		} else {
			return results.messages;
		}
	}

}