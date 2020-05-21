component excludeFromHelp=true {

	function run(){
		print
			.line()
			.yellow( "The " )
			.boldYellow( "coldbox create" )
			.yellowLine( " namespace allows you to quickly scaffold applications " )
			.yellowLine( "and individual app pieces.  Use these commands to stub out placeholder files" )
			.yellow( "as you plan your application.  Most commands create a single file, but """ )
			.boldYellow( "coldbox create app" )
			.yellowLine( """" )
			.yellowLine(
				"will generate an entire, working application into an empty folder for you. Type help before"
			)
			.yellowLine( "any command name to get additional information on how to call that specific command." )
			.line()
			.line();
	}

}
