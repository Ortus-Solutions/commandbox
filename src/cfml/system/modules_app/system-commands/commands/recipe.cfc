/**
 * The recipe commands allows you to execute a collection of CommandBox commands
 * usually in a file.boxr recipe file.  CommandBox will iterate and execute each
 * of the commands for you in succession. Lines that start with a # followed by whitespace will be ignored as comments.
 * .
 * {code:bash}
 * recipe myRecipe.boxr
 * {code}
 * .
 * You can also bind the recipe with arguments that will be replaced inside of your recipe.
 * Pass any arguments as additional parameters to the recipe command.
 * Named arguments will be accessable inside the recipe as  $arg1Name, $arg2Name, etc.
 * Positional args will be avaialble as $1, $2, etc.
 * .
 * Recipe will receive $name and $action
 * {code:bash}
 * recipe recipeFile=buildSite.boxr name=luis action=create
 * {code}
 * .
 * Recipe will receive $1 and $2
 * {code:bash}
 * recipe buildSite.boxr luis create
 * {code}
 * .
 * When using args inside a recipe, you will need to wrap the arg in quotes if it may contain a space
 * .
 * $arg1 may contain spaces
 * {code:bash}
 * rm "$arg1"
 * {code}
 * .
 * If an argument is not bound, no error will be thrown, and the name of the argument will be left in the command.
 * .
 * You can use "echo on" and "echo off" in recipes to control whether the commands output to the console as they are executed.
 * This can be useful for debugging or confirming the success of commands with no output.  Echo is on by default.
 * Note, "echo off" doesn't suppress the output of the commands, just the printing of the command and its arguments prior to execution.
 * This does not use the actual "echo" command and is a feature that only applies during the execution of recipes.
 *
 * {code:bash}
 * echo on
 * # Now you see me
 * echo off
 * # Now you don't
 * {code}
 *
 **/
component {

	// DI Properties
	property name='parser' 	inject='Parser';

	/**
	 * @recipeFile.hint The name of the recipe file to execute including extension.  Any text file may be used.
	 **/
	function run( required recipeFile ){
		// store original path
		var originalPath = getCWD();
		// Make file canonical and absolute
		arguments.recipeFile = resolvePath( arguments.recipeFile );

		// Start clean so we can tell if any of our commands error without being affected by whatever may have run prior to this recipe
		shell.setExitCode( 0 );

		// Validate the file
		if( !fileExists( arguments.recipeFile ) ){
			return error( "File: #arguments.recipeFile# does not exist!" );
		}

		var isEcho = true;

		// read it
		var recipe = fileRead( arguments.recipeFile );

		// Parse arguments
		var sArgs = parseArguments( arguments );

		// bind commands with arguments
		recipe = bindArgs( recipe, sArgs );

		// split commands using carriage returns and/or line feeds
		var commands = listToArray( recipe, chr( 10 ) & chr( 13 ) );

		// iterate and execute.
		for( var thisCommand in commands ){
			thisCommand = trim( thisCommand );

			// Ignore blank lines and comments.
			// Comments are any line that starts with a hash followed by some form of whitespace.
			if( !thisCommand.len() || reFindNoCase( '##\s', thisCommand ) ) {
				continue;
			}
			// Turn echo on
			if( reFindNoCase( '^echo\s+on', thisCommand ) ) {
				isEcho = true;
				continue;
			}
			// Turn echo off
			if( reFindNoCase( '^echo\s+off', thisCommand ) ) {
				isEcho = false;
				print.line( thisCommand );
				continue;
			}

			try{
				// If echo is on, display the command
				if( isEcho ) {
					print.line( thisCommand );
				}
				
				// run Command
				runCommand( thisCommand );
																
				// If the recipe ran "exit"
				if( !shell.getKeepRunning() ) {
					
					if( shell.getExitCode() != 0 ) {
						setExitCode( shell.getExitCode() );
						print
							.boldRed( "command [#thiscommand#] returned exit code [#shell.getExitCode()#], exiting recipe." )
							.line();
					}
					
					// Just kidding, the shell can stay....
					shell.setKeepRunning( true );
					// But this recipe is baked.
					break;
				}
				
				// If a command sets a failing exit code but doesn't throw an exception, stop where we are
				if( shell.getExitCode() != 0 ) {
					setExitCode( shell.getExitCode() );
					print
						.boldRed( "command [#thiscommand#] returned exit code [#shell.getExitCode()#], exiting recipe." )
						.line();
					break;
				}
				

			} catch( any e ){
				// If we ran an exit command in the recipe, don't actually exit the shell.  
				shell.setKeepRunning( true );	
				
				print
					.boldRed( "Error executing command [#thiscommand#], exiting recipe." )
					.line();
				rethrow;
			}
		}

		// cd to original path just incase
		shell.cd( originalPath );
	}

	/**
	* Bind arguments to commands
	*/
	private string function bindArgs( required commands, required struct args ){
		// iterate and bind.
		for( var thisArg in arguments.args ){
			argValue = parser.escapeArg( arguments.args[ thisArg ] );
			arguments.commands = replaceNoCase( arguments.commands, thisArg, argValue, "all" );
		}
		return arguments.commands;
	}

	/**
	* Parse arguments and return a collection
	*/
	private struct function parseArguments( required args ){
		var parsedArgs = {};

		for( var arg in args ) {
			argName = arg;
			if( !isNull( args[arg] ) && arg != 'recipeFile' ) {
				// If positional args, decrement so they start at 1
				if( isNumeric( argName ) ) {
					argName--;
				}
				parsedArgs[ '$' & argName ] = args[arg];
			}
		}
		return parsedArgs;
	}


}
