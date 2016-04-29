/**
 * Stop an embedded CFML server.  Run command from the web root of the server, or use the short name.
 * .
 * {code:bash}
 * server stop
 * server stop serverName
 * server stop serverName --forget
 * server stop --all
 * {code}
 **/
component aliases="stop" {

	// DI
	property name="serverService" inject="ServerService";

	/**
	 * @name.hint the short name of the server to stop
	 * @name.optionsUDF serverNameComplete
	 * @directory.hint web root for the server
	 * @forget.hint if passed, this will also remove the directory information from disk
	 * @all.hint If true, stop ALL running servers
	 **/
	function run(
		string name="",
		string directory="",
		boolean forget=false,
		boolean all=false ){
			
			
		if( arguments.all ) {
			var servers = serverService.getServers();
		} else {
			arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
			// Discover by shortname or webroot and get server info
			var servers = { id: serverService.getServerInfoByDiscovery(
				directory 	= arguments.directory,
				name		= arguments.name
			) };
	
			// Verify server info
			if( structIsEmpty( servers.id ) ){
				error( "The server you requested to stop was not found (webroot=#arguments.directory#, name=#arguments.name#)." );
				print.line( "You can use the 'server list' command to get all the available servers." );
				return;
			}			
		} // End "all" check

		// Stop the server(s)
		for( var id in servers ) {
			var serverInfo = servers[ id ];
			
			if( serverInfo.status == 'stopped' ) {
				continue;
			}
			
			print.yellowLine( 'Stopping ' & serverInfo.name & '...' ).toConsole();
			
			var results = serverService.stop( serverInfo );
			if( results.error ){
				error( results.messages );
			} else {
				print.line( results.messages );
			}
			
			if( arguments.forget ) {
				print.yellowLine( 'forgetting ' & serverInfo.name & '...' ).toConsole();
				print.line( serverService.forget( serverInfo ) );				
			}
		}
		
		
	}
	
	function serverNameComplete() {
		return serverService.getServerNames();
	}

}