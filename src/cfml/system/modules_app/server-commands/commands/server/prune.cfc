/**
 * Prune.
 * .
 * {code:bash}
 * server prune months=6
 * server prune months=6 --list
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
        Boolean list=false,   
    ){
        var serverInfo = serverService.resolveServerDetails( arguments ).serverinfo;
        var servers = serverService.getServers();
        var filterServers = [];

        print.line( "prune started...", 'yellow' ).toConsole();
        servers.each( function( ID ){ runningServerCheck( servers[ arguments.ID ] ); } );

        if( arguments.list )
        {
            /* user wants to see the list of servers with given months */
            print.line( "generating list of prune servers...", 'yellow' ).toConsole();
            serverCount=0;
            data = [];
            for(currentServer in servers)
            {
                lastStarted = servers[ currentServer ].dateLastStarted;
                result = dateDiff("m", servers[ currentServer ].dateLastStarted, now());

                serverData = [];
                if (result>=arguments.months){
                    ArrayAppend(serverData, "#servers[ currentServer ].name#");
                    ArrayAppend(serverData, "#servers[ currentServer ].dateLastStarted#");
                    ArrayAppend(serverData, "#result#");  
                    ArrayAppend(data, serverData);
                    serverCount+=1;
                }

            }

            print.table(data=data, headerNames=["name","last started", "months"])
            print.line("").toConsole();
            print.blackOnGreenText(" total servers = #serverCount# ").toConsole();
            print.line("").toConsole();

        }
        else
        {

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