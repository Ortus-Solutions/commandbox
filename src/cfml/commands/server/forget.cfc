/**
 * Forget an embedded CFML server from persistent disk
 **/
component extends="commandbox.system.BaseCommand" excludeFromHelp=false {

	// di
	property name="serverService" inject="ServerService";

	/**
	 * Forgets one or all servers from persistent disk, removing all logs, configs, etc.
	 *
	 * @directory.hint web root for the server
	 * @name.hint short name for the server
	 * @all.hint forget all servers
	 * @force.hint force
	 **/
	function run(
		String directory="",
		String name="",
		Boolean all=false,
		Boolean force=false
	){
		// Discover by shortname or webroot
		var serverInfo = serverService.getServerInfoByDiscovery( arguments.directory, arguments.name );

		// Verify server info
		if( structIsEmpty( serverInfo ) AND arguments.all eq false ){
			error( "The server you requested to forget was not found (webroot=#arguments.directory#, name=#arguments.name#)." );
			print.line( "You can use the 'server status showAll=true' command to get all the available servers." );
			return;
		}
		// Confirm deletion
		var askMessage = arguments.all ? "Really forget & delete all servers (servers=#arrayToList( serverService.getServerNames() )#) forever [y/n]?" :
									     "Really forget & delete server '#serverinfo.name#' forever [y/n]?";
									     
		if( confirm( askMessage ) ){
			print.line( serverService.forget( serverInfo, arguments.all, arguments.force ) );
		} else {
			print.orangeLine( "Cancelling forget command" );
		}

	}

}