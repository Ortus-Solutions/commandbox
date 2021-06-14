/**
 * Prune.
 * .
 * {code:bash}
 * server prune months=6
 * server prune months=6 --list
 * server prune months=6 --force
 * {code}
 **/
component {

	// di
	property name="serverService" inject="ServerService";

	/**
	 * Prune.
	 *
	 * @months.hint forget servers which last started date is greater or equal to months you set
     * @list.hint give a list of servers which last started date is greater or equal to the months you set
	 **/    
    function run(
        string months,
        Boolean list        = false,   
        Boolean force       = false,
    ){
        var serverInfo      = serverService.resolveServerDetails( arguments ).serverinfo;
        var servers         = serverService.getServers();
        var filterServers   = [];

        print.line( "prune started...", 'yellow' ).toConsole();
        if ( !arguments.force ){
            servers.each( function( ID ){ runningServerCheck( servers[ arguments.ID ] ); } );
        }

        if( arguments.list )
        {

            generatePruneListServers( arguments.months, servers );
        }
        else
        {

            generatePruneListServers( arguments.months, servers );

            var askContinuePrune = "Prune will forget and delete this servers! Do still want to continue [y/n]?";

            if( confirm( askContinuePrune ) ){

                for( currentServer in servers ){
                    result = dateDiff( "m", servers[ currentServer ].dateLastStarted, now() );
                    if ( result >= arguments.months ){
                        arrayAppend( filterServers, servers[ currentServer ] );
                    }
                }            

                if ( arguments.force ){

                    print.line( "using prune with force...", 'yellow' ).toConsole();

                    var runningServers = getRunningServers( servers );
                    /* areThereRunningServers = ( ! runningServers.isEmpty() ) */
                    /* print.line( "are there running servers: #areThereRunningServers#" ).toConsole(); */

                    if ( !runningServers.isEmpty() ) {

                        var stopMessage = "Stopping server #serverInfo.name# first....";
        
                        print.line( stopMessage )
                            .toConsole();
        
                        runningServers.each( function( ID ){
                            var stopResults = serverService.stop( runningServers[ arguments.ID ] );
                            print.line( stopResults.messages, ( stopResults.error ? 'red' : 'green' ) )
                                .toConsole();
                        } );
        
                        // Give them a second or three to die or file locks will still be in place (on Windows, at least)
                        // This is hacky, but there's no clean way to poll for when the process is 100% dead
                        sleep( 3000 );
                    }

                    for( currentServer in filterServers ){

                        print.line( serverService.forget( #currentServer.name# ), 'red' )
                            .toConsole();
                    }

                } else {
            
                    for( currentServer in filterServers ){

                        var askMessage = "Really forget & delete server '#currentServer.name#' forever [y/n]?";
            
                        if( confirm( askMessage ) ){
                            print.line( serverService.forget( #currentServer.name# ), 'red' )
                                .toConsole();
                        } else {
                            print.line( "Cancelling forget '#currentServer.name#' command", 'blue' )
                                .toConsole();
                        }        
                
                    }     

                
                }

            }

        }


    }

    private function generatePruneListServers( required string months, required struct servers ){

        /* user wants to see the list of servers with given months */
        print.line( "generating list servers to be pruned...", 'yellow' ).toConsole();
        serverCount=0;
        data = [];
        for( currentServer in servers )
        {
            lastStarted = servers[ currentServer ].dateLastStarted;
            result = dateDiff( "m", servers[ currentServer ].dateLastStarted, now() );

            serverData = [];
            if ( result >= months ){
                ArrayAppend( serverData, "#servers[ currentServer ].name#" );
                ArrayAppend( serverData, "#servers[ currentServer ].dateLastStarted#" );
                ArrayAppend( serverData, "#result#" );  
                ArrayAppend( data, serverData );
                serverCount += 1;
            }

        }

        print.table( data=data, headerNames=[ "name", "last started", "months" ] )
        print.line( "" ).toConsole();
        print.blackOnGreenText( " total servers = #serverCount# " ).toConsole();
        print.line( "" ).toConsole();
        print.line( "" ).toConsole();

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

}