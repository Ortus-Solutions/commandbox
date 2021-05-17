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
	 * @name the short name of the server to stop
	 * @name.optionsUDF serverNameComplete
	 * @directory web root for the server
	 * @serverConfigFile The path to the server's JSON file.
	 * @forget Remove the directory information from disk
	 * @all Stop ALL running servers
	 * @verbose Show raw output of stop command
	 **/
	function run(
		string name,
		string directory,
		String serverConfigFile,
		boolean forget=false,
		boolean all=false,
		boolean verbose=false ){


		if( arguments.all ) {
			var servers = serverService.getServers();
		} else {

			if( !isNull( arguments.directory ) ) {
				arguments.directory = resolvePath( arguments.directory );
			}
			if( !isNull( arguments.serverConfigFile ) ) {
				arguments.serverConfigFile = resolvePath( arguments.serverConfigFile );
			}

			// Look up the server that we're stopping
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
				if( verbose && len( results.messages ) ) {
					print.line( results.messages )
				}
				print.greenLine( 'Stopped' );
			}

			if( arguments.forget ) {
				print.yellowLine( 'forgetting ' & serverInfo.name & '...' ).toConsole();
				sleep( 1000 )
				print.line( serverService.forget( serverInfo ) );
			}
		}


	}

	function serverNameComplete() {
		return serverService
			.getServerNames()
			.map( ( i ) => {
				return { name : i, group : 'Server Names' };
			} );
	}

}
