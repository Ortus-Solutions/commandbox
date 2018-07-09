/**
 * Forget an embedded CFML server from persistent disk.  Run command from the web root of the server, or use the short name.
 * This command will remove all of the engine files for the server as well as all CF configuration as well. If you don't 
 * want to lose your settings, back them up first with the CFConfig tool.
 * .
 * {code:bash}
 * server forget
 * server forget name=serverName
 * server forget --all
 * server forget --all --force
 * {code}
 **/
component {

	// di
	property name="serverService" inject="ServerService";

	/**
	 * Forgets one or all servers from persistent disk, removing all logs, configs, etc.
	 *
	 * @name.hint the short name of the server
	 * @name.optionsUDF serverNameComplete
	 * @directory.hint web root for the server
	 * @serverConfigFile The path to the server's JSON file.
	 * @all.hint Forget all servers
	 * @force.hint Skip the "are you sure" confirmation
	 **/
	function run(
		string name,
		string directory,
		String serverConfigFile,
		Boolean all=false,
		Boolean force=false
	){
		if( !isNull( arguments.directory ) ) {
			arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
		}
		if( !isNull( arguments.serverConfigFile ) ) {
			arguments.serverConfigFile = fileSystemUtil.resolvePath( arguments.serverConfigFile );
		}
		var serverInfo = serverService.resolveServerDetails( arguments ).serverinfo;

		var servers = arguments.all ? serverService.getServers() : { "#serverInfo.id#": serverInfo };
		if( arguments.force ) {
			var runningServers = getRunningServers( servers );
			if ( ! runningServers.isEmpty() ) {
				
				var stopMessage = arguments.all ?
					"Stopping all running servers (#getServerNames( runningServers ).toList()#) first...." :
					"Stopping server #serverInfo.name# first....";
					
				print
					.line( stopMessage )
					.toConsole();
				
				runningServers.each( function( ID ){
					var stopResults = serverService.stop( runningServers[ arguments.ID ] );
					print
						.line( stopResults.messages, ( stopResults.error ? 'red' : 'green' ) )
						.toConsole();
				} );
				
				// Give them a second or three to die or file locks will still be in place (on Windows, at least)
				// This is hacky, but there's no clean way to poll for when the process is 100% dead
				sleep( 3000 );
			}
		} else {
			servers.each( function( ID ){ runningServerCheck( servers[ arguments.ID ] ); } );
		}

		// Confirm deletion
		var askMessage = arguments.all ?
			"Really forget & delete all servers (#arrayToList( serverService.getServerNames() )#) forever [y/n]?" :
			"Really forget & delete server '#serverinfo.name#' forever [y/n]?";

		if( arguments.force || confirm( askMessage ) ){
			servers.each( function( ID ){
				print
					.line( serverService.forget( servers[ arguments.ID ] ) )
					.toConsole();
			 } );
		} else {
			print.orangeLine( "Cancelling forget command" );
		}

	}

	private function runningServerCheck( required struct serverInfo ) {
		if( serverService.isServerRunning( serverInfo ) ) {
			print.redBoldLine( 'Server "#serverInfo.name#" (#serverInfo.webroot#) appears to still be running!' )
				.yellowLine( 'Forgetting it now may leave the server in a corrupt state. Please stop it first.' )
				.line()
				.toConsole();
		}
	}

	private function getRunningServers( required struct servers ) {
		return servers.filter( function( ID ){
			return serverService.isServerRunning( servers[ arguments.ID ] );
		} )
	}

	private function getServerNames( required struct servers ){
		return servers.keyArray().map( function( ID ){
			return servers[ arguments.ID ].name;
		} );
	}
	
	function serverNameComplete() {
		return serverService
			.getServerNames()
			.map( ( i ) => {
				return { name : i, group : 'Server Names' };
			} );
	}

}
