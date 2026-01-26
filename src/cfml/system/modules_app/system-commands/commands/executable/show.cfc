/**
 * Show details of a specific OS executable alias.
 * .
 * {code:bash}
 * executable show myAlias
 * {code}
 *
 **/
component {
	property name="executableService" inject="ExecutableService@system-commands";

	/**
	 * @alias The name of the alias to show
	 **/
	function run( required string alias ) {
		var aliasInfo = executableService.getAlias( alias );

		if ( aliasInfo.isEmpty() ) {
			print.redLine( "Executable alias [#alias#] not found." );
			return;
		}

		print.line( "Alias:    #aliasInfo.alias#" )
			.line( "Command:  #aliasInfo.command#" )
			.line( "Location: #aliasInfo.location#" );
	}

}
