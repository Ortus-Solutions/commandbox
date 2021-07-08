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
        numeric days    = 30,
        Boolean force   = false,
        Boolean JSON    = false,
    )
    {
        prunableServers = serverService
            .getServers()
            .valueArray()
            .map( (s) => { s.daysLastStarted=isDate( s.dateLastStarted ?: '' ) ? dateDiff( 'd', s.dateLastStarted, now() ) : 999; return s } )
            .filter( (s) => s.daysLastStarted >= days )
            .sort( (a,b) => a.daysLastStarted - b.daysLastStarted );

        if( JSON ){
            print.line(prunableServers)
                .toConsole()
        }

        if( !prunableServers.len() ){
            print.line( 'There are no servers that have not been started in #days# days.' );
			return;
        }

        print.table(
            prunableServers,
            "name, webroot, daysLastStarted",
            "Name, Web Root, Days Since Last Start"
        ).toConsole();

        if ( force || confirm( "Are you sure you want to forget these #prunableServers.len()# servers?" ) ){
            prunableServers.each( (s) => command("server forget").params( name=s.name, force=true ).run() );
        }

    }

}