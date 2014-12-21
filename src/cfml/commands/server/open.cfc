/**
 * This command will open the browser window to the current server root if started, else it is ignored.
 * This command must be ran from the directory were the server was started.
 * .
 * {code:bash}
 * server open
 * {code}
 **/
component extends="commandbox.system.BaseCommand" aliases="fwreinit" excludeFromHelp=false {
	
	// DI
	property name="serverService" inject="ServerService";
	property name='parser' 	inject='Parser';
	
	/**
	* @URI An additional URI to go to when opening the server browser, else it just opens localhost:port 
	* @directory Web root for the server, auto-calculated if not passed
	* @name Short name for the server
	**/
	function run( URI="/", directory="", name="" ){
		var serverInfo = serverService.getServerInfoByDiscovery( arguments.directory, arguments.name );

		if( structCount( serverInfo ) eq 0 ){
			print.boldRedLine( "No server configurations found for directory:'#arguments.directory#' name:'#arguments.name#', so have no clue what to open buddy!" );
		} else {
			var thisURL = "localhost:#serverInfo.port##arguments.URI#";
			print.greenLine( "Opening...#thisURL#" );
			runCommand( "browse '#parser.escapeArg( thisURL )#'" );
			
			
		}
	}

}