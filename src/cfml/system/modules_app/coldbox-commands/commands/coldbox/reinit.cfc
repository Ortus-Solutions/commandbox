/**
 * Reinitialize a running ColdBox app if a server was started with CommandBox.
 * This command must be ran from the root of the ColdBox Application
 * .
 * {code:bash}
 * coldbox reinit
 * {code}
 * .
 * {code:bash}
 * coldbox reinit password="mypass"
 * {code}
 **/
component aliases="fwreinit" {

	// DI
	property name="serverService" inject="ServerService";
	property name="formatter"     inject="formatter";

	/**
	 * @password The FWReinit password
	 * @name Name of the CommandBox server to reinit
	 * @showUrl Show the Url to reinit
	 **/
	function run(
		password = "1",
		name     = "",
		showUrl  = true
	){
		var serverInfo = serverService.getServerInfoByDiscovery( getCWD(), arguments.name );

		if ( !structCount( serverInfo ) ) {
			print.boldRedLine(
				"No server configurations found for '#getCWD()#', so have no clue what to reinit buddy!"
			);
		} else {
			var thisURL = "#serverInfo.host#:#serverInfo.port#/?fwreinit=#arguments.password#";
			if ( arguments.showUrl ) {
				print.greenLine( "Hitting... #thisURL#" );
			}
			http result="local.results" url="#thisURL#";

			if ( findNoCase( "200", local.results.statusCode ) ) {
				print.boldGreenLine( "App Reinited!" );
			} else {
				print
					.redLine( "status code: #local.results.statusCode#" )
					.redline( "error detail: " & local.results.errorDetail )
					.line( trim( formatter.HTML2ANSI( local.results.filecontent ) ) );
			}
		}
	}

}
