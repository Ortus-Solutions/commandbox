/**
 * Forget old servers which haven't been started in a given period of time. time will be calculated in days.
 * .
 * {code:bash}
 * server prune days=30
 * server prune days=30 --list
 * server prune days=30 --force
 * server prune days=30 --list --json
 * {code}
 **/
component {

	// di
	property name="serverService" inject="ServerService";

	/**
	 * Forget old servers which haven't been started in a given period of time.
	 *
	 * @days.hint forget servers which last started date is greater or equal to days you set
     * @list.hint give a list of servers which last started date is greater or equal to the days you set
     * @json.hint give a list of servers as --list but in the JSON format
     * @force.hint skip the "are you sure" confirmation
	 **/    
    function run(
        string days,
        Boolean list        = false,
        Boolean JSON        = false,
        Boolean force       = false,
    ){
        var servers         = serverService.getServers();
        var filterServers   = [];

        print.line( "prune started...", 'yellow' ).toConsole();
        if ( !arguments.force ){
            servers.each( function( ID ){ runningServerCheck( servers[ arguments.ID ] ); } );
        }

        /* only place where we filter out the  */
        ArrayAppend( filterServers, structFilter(servers, function(id){
                lastStarted = servers[ id ].dateLastStarted;
                result = dateDiff( "d", servers[ id ].dateLastStarted, now() );
                if ( result >= days ){
                    StructInsert( servers[ id ], "days", result, false );
                    return true;
                }
                return false;
            }) 
        );

        if( arguments.list )
        {

            generatePruneListServers( arguments.days, filterServers, JSON);
        }
        else
        {

            generatePruneListServers( arguments.days, filterServers );

            var askContinuePrune = "Prune will forget and delete this servers! Do you still want to continue [y/n]?";

            if( arguments.force || confirm( askContinuePrune ) ){

                /* for( currentServer in servers ){
                    result = dateDiff( "d", servers[ currentServer ].dateLastStarted, now() );
                    if ( result >= arguments.days ){
                        arrayAppend( filterServers, servers[ currentServer ] );
                    }
                }  */           

                if ( arguments.force ){

                    print.line( "using prune with force...", 'yellow' ).toConsole();

                    var runningServers = getRunningServers( servers );

                    if ( !runningServers.isEmpty() ) {

                        var stopMessage = "Stopping servers....";
        
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

    private function generatePruneListServers( required string days, required array servers, required Boolean JSON  ){

        /* user wants to see the list of servers with given days */
        print.line( "generating list servers to be pruned...", 'yellow' ).toConsole();

        /* test={
            "s1":{
                "key":"alpha",
                "value": 1
            },
            "s2":{
                "key":"betha",
                "value": 2
            }
        } */

        if( JSON ){
            print.line( servers );            
        } else {
            print.table(  
                servers,
                "",
                ["name", "dateLastStarted", "days"]
            ).line()
            .blackOnGreenText( " total servers = #arrayLen( servers )# " )
            .line()
            .line()
            .toConsole();
    
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

}