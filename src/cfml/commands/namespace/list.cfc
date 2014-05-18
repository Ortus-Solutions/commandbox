/**
 * List all top-level command namespaces
 **/
component  persistent="false" extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	function run(  )  {
		var commandService = shell.getCommandService();
		var commands = commandService.getCommandHierarchy();
		
		print.line();
		for( var command in commands ) {
			if( !isObject( commands[ command ] ) ) {
				print.magentaText( command );
					print.line( ' (#structCount( commands[ command ] )# commands)' );
			}			
		}
		print.line();
		
	}

	
}