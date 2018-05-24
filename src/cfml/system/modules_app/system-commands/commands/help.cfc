/**
 * Display CommandBox help.  Call this command with no parameters to see general help for all commands.
 * Help includes command aliases, paramters, and example syntax.
 * .
 * {code:bash}
 * help
 * {code}
 * .
 * Pass in a command or namespace to get help on that item.
 * .
 * {code:bash}
 * help testbox
 * help testbox run
 * {code}
 * .
 * "help" can also be appended to the end of the command
 * .
 * {code:bash}
 * testbox help
 * testbox run help
 * {code}
**/
component aliases="h,/?,?,--help,-help" {

	property name="commandService" inject="CommandService";

	/**
	 * @command.hint The command to get help for.  If blank, displays help for all commands
	 **/
	function run( command='' )  {
		// Auto-help will display help for all commands at this
		// level in the command structure and below.  Default to all
		var autoHelpRoot = '';

		// CommandBox Help banner
		print.line();
		print.greenLine( repeatString( '*', 50 ) );
		print.greenText( '* CommandBox Help' );
		if( len( command ) ) {
			print.greenText( ' for ' );
			print.boldGreenText( '#command#' );
		}
		print.line();
		print.greenLine( repeatString( '*', 50 ) );
		print.line();

		var commandHierarchy = commandService.getCommandHierarchy();
		var foundCommand = false;
		var commandRoot = '';
		var commandRootSpaces = '';

		// If we're getting help for a specific command
		if( len( command ) ) {
			// Resolve the string to the first command (help | more will just be "help")
			var commandInfo = commandService.resolveCommand( line=command )[1];

			// Display auto help for however far we made it in the command hierarchy
			commandHierarchy = commandInfo.commandReference;
			foundCommand = commandInfo.found;
			commandRoot = commandInfo.commandString;
			commandRootSpaces = listChangeDelims( commandRoot, ' ', '.' );

			// If the user typed something that wasn't exactly matched, let them know
			if( !len( commandInfo.commandString ) || commandRootSpaces != command ) {
				print.redLine( 'Command [#command#] not found.' );
				print.line();
			}

			// If no command was found but there is an applicable help command for the namespace
			// other than the main help that we're in now...
			if( !foundCommand && commandInfo.closestHelpCommand != 'help' ) {
				// Run it to output some context-specific help for this namespace
				runCommand( commandInfo.closestHelpCommand );

			}

		}

		// Help for a single command
		if( foundCommand ) {
			printCommandHelp( command, commandInfo );
		// Help for a namespace
		} else {
			var commands = [];
			var namespaces = [];

			// Get all the commands and nested namespaces at this level.
			for( var node in commandHierarchy ) {
				var thisCommand = commandHierarchy[ node ];
				// Is this node a command
				if( structKeyExists( thisCommand, '$' ) ) {
					if( thisCommand.$.originalName == 'CommandTemplate' ) {
						continue;
					}
					var originalCommandName = thisCommand[ '$' ].originalName;
					var excludeFromHelp = thisCommand[ '$' ].excludeFromHelp;
					// Only grab original commands to filter out aliases
					// Also don't include if the command is flagged to hide from help
					if( originalCommandName == listAppend( commandRoot, node, '.' )  &&  !excludeFromHelp ) {
						commands.append( node );
					}
				// Is this node a namespace
				} else {
					namespaces.append( node );
				}
			} // End loop over this level in the hierachy


			// Sort each list
			commands.sort( 'text' );
			namespaces.sort( 'text' );

			// If there are commands
			if( commands.len() ) {
				print.blackOnYellowline( 'Here is a list of commands in this namespace:' );
				print.line();

				// Show them
				for( var command in commands ) {
					print.line( commandRootSpaces & ' ' & command );
				}

				print.line();

			}

			// If there are namepaces
			if( namespaces.len() ) {
				print.line();

				print.blackOnYellowline( 'Here is a list of nested namespaces:' );
				print.line();

				// Show them
				for( var namespace in namespaces ) {
					print.line( commandRootSpaces & ' ' & namespace );
				}

				print.line();

			}
			print.line();
			print.yellowText( 'To get further help on any of the items above, type ' );
			print.boldYellowText( '"help command name"' );
			print.YellowLine( '.' );

		}


		return;
	}

	/**
	* Outputs help information for a single command.
	*
	* @command.hint String command
	* @commandInfo.hint Reference to Command CFC
	**/

	private function printCommandHelp( required string command, required any commandInfo ) {
		var commandRefernce = commandInfo.commandReference;
		// Original command name, to tell if "command" is an alias
		var originalCommandName = listChangeDelims( commandRefernce.originalName, ' ', '.');
		// CFC hint
		var commandHint = commandRefernce.hint;
		// run() method's parameters
		var commandParameters = commandRefernce.parameters;
		// A command by any other name...
		var aliases = duplicate( commandRefernce.aliases );
		// We are viewing help for an alias
		if( originalCommandName != command ) {
			// Swap out the original name into the alias list
			aliases.delete( command );
			aliases.prepend( originalCommandName );
		}


		// Output command name
		print.line();
		print.blackOnWhiteLine( ' #command# ' );
		print.line();

		// Aliases
		if( aliases.len() ) {
			print.line();
			print.line( 'Aliases: #arrayToList( aliases, ', ' )#' );
			print.line();
		}

		// Output the hint if it exists
		if( len( commandHint ) ) {

			// Clean up lines with only a period which is my work around for the Railo bug ignoring
			// line breaks in componenet annotations: https://issues.jboss.org/browse/RAILO-3128
			commandHint = reReplace( commandHint, '\n\s*\.\s*\n', cr&cr, 'all' );

			// Find code blocks
			// A {code} block on it's own line with an optional ":brush" inside it
			// followed by any amount of text
			// followed by another {code} block on it's own line
			var codeRegex = '(\n?\s*{\s*code\s*(:.*?)?\s*}\s*\n)(.*?)(\n\s*{\s*code\s*}\s*\n?)';
			// Clear formatting ahead of the code so it's white, and turn the yellow back on.  ANSI escape sequences hard-coded here
			commandHint = reReplaceNoCase( commandHint, codeRegex, '#cr##cr##chr( 27 )#[0m\3#cr##cr##chr( 27 )#[33m', 'all' );

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
				if( param.type != 'any' ) {
					print.text( '#param.type# ' );
				}
				print.cyanText( '#param.name# ' );
				// Default value
				if( !isNull(param.default) && param.default!= '[runtime expression]' )  {
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
	}

}
