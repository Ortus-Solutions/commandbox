component excludeFromHelp=true {

	function run(){
		print.line();
		print.yellow( "The " );
		print.boldYellow( "testbox create" );
		print.yellowLine( " namespace allows you to quickly create specs for your TestBox test suites.  " );
		print.yellowLine(
			"Use these commands to stub out placeholder unit and integration tests as well as BDD specs."
		);
		print.yellowLine(
			"Type help before any command name to get additional information on how to call that specific command."
		);

		print.line();
		print.line();
	}

}
