component excludeFromHelp=true {

	function run(){
		print.line();
		print.yellow( "The " );
		print.boldYellow( "coldbox" );
		print.yellowLine(
			" namespace is designed to help developers easily build applications using the ColdBox MVC platform."
		);
		print.yellowLine(
			"Use these commands to stub out placeholder handlers, models, views, modules and much more."
		);
		print.yellowLine(
			"There are commands to install ColdBox integrations into your IDE, run your application from the command line, "
		);
		print.yellowLine( "and even generate reports on various aspects of your application structure." );
		print.yellowLine(
			"Type help before any command name to get additional information on how to call that specific command."
		);

		print.line();
		print.line();
	}

}
