/**
 * Remove an OS executable alias.
 * .
 * {code:bash}
 * executable delete myAlias
 * {code}
 *
 **/
component {
	property name="executableService" inject="ExecutableService@system-commands";

	/**
	 * @alias The name of the alias to remove
	 **/
	function run( required string alias ) {
		var removed = executableService.removeAlias( alias );

		if ( removed ) {
			print.greenLine( "Executable alias [#alias#] removed." );
		} else {
			print.redLine( "Executable alias [#alias#] not found." );
		}
	}

}
