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
	
	/**
	* @URI.hint An additional URI to go to when opening the server browser, else it just opens localhost:port 
	**/
	function run( URI="/" ){
		var serverInfo = serverService.getServerInfoByWebroot( getCWD() );

		if( structCount( serverInfo ) eq 0 ){
			print.boldRedLine( "No server configurations found for '#getCWD()#', so have no clue what to open buddy!" );
		} else {
			var thisURL = "localhost:#serverInfo.port##arguments.URI#";
			print.greenLine( "Opening...#thisURL#" );
			runCommand( "browse #thisURL#" );
		}
	}

}