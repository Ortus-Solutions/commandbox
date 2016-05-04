/**
 * Forget an embedded CFML server from persistent disk.  Run command from the web root of the server, or use the short name.
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
	 * @name.hint Short name for the server
	 * @name.optionsUDF serverNameComplete
	 * @directory.hint Web root for the server
	 * @all.hint Forget all servers
	 * @force.hint Skip the "are you sure" confirmation
	 **/
	function run(
		String name="",
		String directory="",
		Boolean all=false,
		Boolean force=false
	){
		// Discover by shortname or webroot
		arguments.directory = fileSystemUtil.resolvePath( arguments.directory );
		var serverInfo = serverService.getServerInfoByDiscovery( arguments.directory, arguments.name );

		// Verify server info
		if( structIsEmpty( serverInfo ) AND arguments.all eq false ){
			error( "The server you requested to forget was not found (webroot=#arguments.directory#, name=#arguments.name#)." );
			print.line( "You can use the 'server list' command to get all the available servers." );
			return;
		}
		// Confirm deletion
		var askMessage = arguments.all ? "Really forget & delete all servers (servers=#arrayToList( serverService.getServerNames() )#) forever [y/n]?" :
									     "Really forget & delete server '#serverinfo.name#' forever [y/n]?";
									     
		if( arguments.force || confirm( askMessage ) ){
			print.line( serverService.forget( serverInfo, arguments.all ) );
		} else {
			print.orangeLine( "Cancelling forget command" );
		}

	}
	
	function serverNameComplete() {
		return serverService.getServerNames();
	}

}