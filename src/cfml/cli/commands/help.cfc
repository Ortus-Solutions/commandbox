/**
 * get help information
 **/
component extends="cli.BaseCommand" {


	function run( command='' )  {
		var commandHandler = shell.getCommandHandler();
		// Auto-help will display help for all commands at this
		// level in the command structure and below.  Default to all
		var autoHelpRoot = '';
		
		// CommandBox Help banner
		print.line();
		print.greenLine( repeatString( '*', 50 ) );
		print.greenText( '* CommandBox Help' );
		if( len( command ) ) {
			print.greenText( ' for "#command#"' );	
		}
		print.line();
		print.greenLine( repeatString( '*', 50 ) );
		print.line();
		
		// If we're getting help for a specific command
		if( len( command ) ) {
			// Resolve the string to the command
			var commandInfo = commandHandler.resolveCommand( line=command, substituteHelp=false );
			
			// Display auto help for however far we made it in the command hierarchy
			autoHelpRoot = commandInfo.commandString;
			
			// If we didn't resolve a command, let them know.
			if( !commandInfo.found ) {
				print.line();
				print.redLine( "Sorry we couldn't find that exact command." );
				if( len(autoHelpRoot) ) {
					print.redLine( "Here's some similar commands." );
				} else {
					print.redLine( "Here's some general help instead." );					
				}
				print.line();
			}		
		}
		
		// Auto help		 
		var allCommands = commandHandler.getCommands();
		autoHelpRoot = listChangeDelims( autoHelpRoot, ' ', '.' );
		commandsForAutoHelp = [];
		
		// allCommands includes aliases.  Loop over and pull out only original
		// commands that are similar to what the user typed. If nothing the user 
		// typed looked familar or they typed nothing, we'll just include them all
		for( var command in allCommands ) {
			// Name of command starts with what the user typed
			if( !len(autoHelpRoot) || left( command, len(autoHelpRoot) ) == autoHelpRoot ) {
				var originalCommandName = listChangeDelims( allCommands[ command ].$CommandBox.originalName, ' ', '.');
				// Only grab original commands to filter out aliases
				if( originalCommandName == command ) {
					commandsForAutoHelp.append( command );
				}
			}
		}
		
		// Single commands sort to top alphbetical
		// All other commands follow alphbetically, grouped together
		commandsForAutoHelp.sort(
			function( val1, val2 ) {
				 if( listLen( val1, ' ' ) == 1 ) {
				 	val1 = '1' & val1;
				 } else {
				 	val1 = '2' & val1;
				 }
				 if( listLen( val2, ' ' ) == 1 ) {
				 	val2 = '1' & val2;
				 } else {
				 	val2 = '2' & val2;
				 }
				 return compare(val1, val2);
		});
		
		// Now that we have a sorted list of commands to display help for,
		// Loop over them
		for( var command in commandsForAutoHelp ) {
			// Command CFC object
			var commandReference = allCommands[ command ];
			// CFC hint
			var commandHint = commandReference.$CommandBox.hint;
			// run() method's parameters
			var commandParameters = commandReference.$CommandBox.parameters;
			
			// Only do divider if there is more than one command
			if( commandsForAutoHelp.len() > 1 ) {
				print.line( "__________________________________________________________________________________________________________" );
			}
			// Output command name
			print.line();
			print.blackOnWhiteLine( ' #command# ' );
			print.line();
			// Output the hint if it exists
			if( len( commandHint ) ) {
				print.yellowText( "#commandHint#");
				print.line();
			}
			print.line();
			// If the command has parameters...
			if( commandParameters.len() ) {
				print.cyanLine( "#chr(9)# Arguments:");
				// Loop over and display them
				for( var param in commandParameters ) {
					print.text( chr(9) & chr(9) );
					// Required?
					if( param.required ) {
						print.redText( 'required ' );						
					}
					// Param type
					print.text( '#param.type# ' );
					print.magentaText( '#param.name# ' );
					// Default value
					if( !isNull(param.default))  {
						print.text( '= "#param.default#" ' );		
					}
					// param Hint
					if( !isNull(param.hint))  {
						print.yellowText( '(#param.hint#)' );						
					}					
					print.line();			
				} // End parameter loop
			} // End are there params?
			print.line();	
		} // end loop over commands
		
		return;

	}

	
}