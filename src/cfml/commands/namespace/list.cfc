/**
 * List all top-level command namespaces
 **/
component  persistent="false" extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	function run(  )  {
		var commandHandler = shell.getCommandHandler();
		var commands = commandHandler.getCommandHierarchy();
		
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