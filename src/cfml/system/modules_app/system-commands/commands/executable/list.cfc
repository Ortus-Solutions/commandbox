/**
 * List all OS executable aliases.
 * .
 * {code:bash}
 * executable list
 * {code}
 *
 **/
component {
	property name="executableService" inject="ExecutableService@system-commands";

	/**
	 * Run the command
	 **/
	function run() {
		var aliases = executableService.listAliases();

		if ( aliases.isEmpty() ) {
			print.yellowLine( "No executable aliases found." );
			return;
		}

		print.table(
			aliases,
			"alias,command,location",
			"Alias,Command,Location"
		);
	}

}
