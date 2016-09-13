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
	 * @serverConfigFile The path to the server's JSON file.
	 * @forget.hint if passed, this will also remove the directory information from disk
	 * @all.hint If true, stop ALL running servers
	 **/
	function run(
		string name,
		string directory,
		String serverConfigFile,
		boolean forget=false,
		boolean all=false ){
			
			
		if( arguments.all ) {
			var servers = serverService.getServers();
		} else {
				
			if( !isNull( arguments.directory ) ) {
				arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
			} 
			if( !isNull( arguments.serverConfigFile ) ) {
				arguments.serverConfigFile = fileSystemUtil.resolvePath( arguments.serverConfigFile );
			}
			
			// Look up the server that we're starting
			var servers = { id: serverService.resolveServerDetails( arguments ).serverinfo };
	
		} // End "all" check

		// Stop the server(s)
		for( var id in servers ) {
			var serverInfo = servers[ id ];
			
			if(  !serverService.isServerRunning( serverInfo ) ) {
				if( structCount( servers ) == 1 ) {
					print.yellowLine( serverInfo.name & ' already stopped.' ).toConsole();
				}
				continue;
			}
			
			print.yellowLine( 'Stopping ' & serverInfo.name & '...' ).toConsole();
			
			var results = serverService.stop( serverInfo );
			if( results.error ){
				print.boldWhiteOnRedLine( 'ERROR' );
				print.boldRedLine( results.messages );
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