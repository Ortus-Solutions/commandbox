/**
 * Toggle an embedded CFML server.  Run command from the web root of the server, or use the short name.
 * .
 * {code:bash}
 * server toggle
 * server toggle serverName
 * {code}
 **/
component extends="commandbox.system.BaseCommand" aliases="toggle" excludeFromHelp=false {

	// DI
	property name="serverService" inject="ServerService";

	/**
	 * @name.hint the short name of the server to stop
	 * @name.optionsUDF serverNameComplete
	 * @directory.hint web root for the server
	 **/
	function run(string name="", string directory="") {

		// Discover by shortname or webroot and get server info
		var servers = { id: serverService.getServerInfoByDiscovery(
			directory 	= arguments.directory,
			name		= arguments.name
		) };

		// Verify server info
		if( structIsEmpty( servers.id ) ){
			error( "The server you requested to toggle was not found (webroot=#arguments.directory#, name=#arguments.name#)." );
			print.line( "You can use the 'server list' command to get all the available servers." );
			return;
		}

		// Toggle the server(s)
		for( var id in servers ) {
			var serverInfo = servers[ id ];

			if( serverInfo.status == 'stopped' ) {
                print.yellowLine( 'Starting ' & serverInfo.name & '...' ).toConsole();
                return serverService.start(
        			serverInfo 	= serverInfo,
        			openBrowser = false,
        			force		= false,
        			debug 		= false
        		);
			} else {
                print.yellowLine( 'Stopping ' & serverInfo.name & '...' ).toConsole();
                var results = serverService.stop( serverInfo );
                if( results.error ){
                    error( results.messages );
                } else {
                    print.line( results.messages );
                }
            }
		}

	}

	function serverNameComplete() {
		return serverService.getServerNames();
	}

}
