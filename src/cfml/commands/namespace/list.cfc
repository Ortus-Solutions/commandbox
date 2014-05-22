/**
 * List all top-level command namespaces
 **/
component  extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	property name="commandService" inject="CommandService";
	
	function run(  )  {
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