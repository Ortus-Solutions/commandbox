/**
 * Forget old servers which haven't been started in a given period of time. time will be calculated in months.
 * .
 * {code:bash}
 * server prune months=6
 * server prune months=6 --list
 * server prune months=6 --force
 * server prune months=6 --list --json
 * {code}
 **/
component {

	// di
	property name="serverService" inject="ServerService";

	/**
	 * Forget old servers which haven't been started in a given period of time.
	 *
	 * @months.hint forget servers which last started date is greater or equal to months you set
     * @list.hint give a list of servers which last started date is greater or equal to the months you set
     * @json.hint give a list of servers as --list but in the JSON format
     * @force.hint skip the "are you sure" confirmation
	 **/    
    function run(
        string months,
        Boolean list        = false,
        Boolean JSON        = false,
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

            generatePruneListServers( arguments.months, servers, JSON);
        }
        else
        {

            generatePruneListServers( arguments.months, servers );

            var askContinuePrune = "Prune will forget and delete this servers! Do you still want to continue [y/n]?";

            if( arguments.force || confirm( askContinuePrune ) ){

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

    private function generatePruneListServers( required string months, required struct servers, required Boolean JSON  ){

        /* user wants to see the list of servers with given months */
        print.line( "generating list servers to be pruned...", 'yellow' ).toConsole();
        serverCount=0;
        data = [];
        for( currentServer in servers )
        {
            lastStarted = servers[ currentServer ].dateLastStarted;
            result = dateDiff( "m", servers[ currentServer ].dateLastStarted, now() );

            if ( result >= months ){
                StructInsert( servers[ currentServer ], "months", result, false );
                serverStruct = servers[ currentServer ];
                ArrayAppend( data, serverStruct );
                serverCount += 1;
            }

        }

        if( JSON ){
            print.line( data );            
        } else {
            print.table(    
                arrayOfStructsSort( data, "months", "desc" ),
                [ 'name', 'dateLastStarted', 'months' ]
            ).line()
            .blackOnGreenText( " total servers = #serverCount# " )
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
    
    /**
     * Sorts an array of structures based on a key in the structures.
     * 
     * @param aofS      Array of structures. (Required)
     * @param key      Key to sort by. (Required)
     * @param sortOrder      Order to sort by, asc or desc. (Optional)
     * @param sortType      Text, textnocase, or numeric. (Optional)
     * @param delim      Delimiter used for temporary data storage. Must not exist in data. Defaults to a period. (Optional)
     * @return Returns a sorted array. 
     * @author Nathan Dintenfass (nathan@changemedia.com) 
     * @version 1, April 4, 2013 
     */    
    function arrayOfStructsSort( aOfS, key ){
        //by default we'll use an ascending sort
        var sortOrder = "asc";        
        //by default, we'll use a textnocase sort
        var sortType = "textnocase";
        //by default, use ascii character 30 as the delim
        var delim = ".";
        //make an array to hold the sort stuff
        var sortArray = arraynew( 1 );
        //make an array to return
        var returnArray = arraynew( 1 );
        //grab the number of elements in the array (used in the loops)
        var count = arrayLen( aOfS );
        //make a variable to use in the loop
        var ii = 1;
        //if there is a 3rd argument, set the sortOrder
        if( arraylen( arguments ) GT 2 )
            sortOrder = arguments[ 3 ];
        //if there is a 4th argument, set the sortType
        if( arraylen( arguments ) GT 3 )
            sortType = arguments[ 4 ];
        //if there is a 5th argument, set the delim
        if( arraylen( arguments ) GT 4 )
            delim = arguments[ 5 ];
        //loop over the array of structs, building the sortArray
        for( ii = 1; ii lte count; ii = ii + 1 )
            sortArray[ii] = aOfS[ii][key] & delim & ii;
        //now sort the array
        arraySort( sortArray,sortType,sortOrder );
        //now build the return array
        for( ii = 1; ii lte count; ii = ii + 1 )
            returnArray[ii] = aOfS[ listLast( sortArray[ii],delim ) ];
        //return the array
        return returnArray;
    }    

}