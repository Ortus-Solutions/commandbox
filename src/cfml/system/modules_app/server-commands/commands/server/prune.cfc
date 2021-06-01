/**
 * Prune.
 * .
 * {code:bash}
 * server prune months=6
 * {code}
 **/
component {

	// di
	property name="serverService" inject="ServerService";

	/**
	 * Prune.
	 *
	 * @months.hint forget servers which last started date is greater or equal to months you set
	 **/    
    function run(
        string months      
    ){
        var serverInfo = serverService.resolveServerDetails( arguments ).serverinfo;
        var servers = serverService.getServers();
        var filterServers = [];

        print.line( "prune started...", 'yellow' ).toConsole();
        servers.each( function( ID ){ runningServerCheck( servers[ arguments.ID ] ); } );

        for(currentServer in servers){
            result = dateDiff("m", servers[ currentServer ].dateLastStarted, now());
            if (result>=arguments.months){
                arrayAppend(filterServers, servers[ currentServer ]);
            }
        }

        for(currentServer in filterServers){
            print.line( "#currentServer.id# #currentServer.name#" ).toConsole();

            var askMessage = "Really forget & delete server '#currentServer.name#' forever [y/n]?";

            if( confirm( askMessage ) ){
                print.line( "server Service forget( #currentServer.name# )", 'red' )
                    .toConsole();
            } else {
                print.line( "Cancelling forget '#currentServer.name#' command", 'blue' )
                    .toConsole();
            }        
    
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

}