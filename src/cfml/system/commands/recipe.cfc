/**
 * The recipe commands allows you to execute a collection of CommandBox commands
 * usually in a file.boxr recipe file.  CommandBox will iterate and execute each
 * of the commands for you in succession. You can also bind the recipe with arguments
 * that will be replaced inside of your recipe.  Pass any arguments as additional parameters 
 * to the recipe command.  Named arguments will be accessable via $arg1Name, $artg2Name, etc. 
 * Positional args will be avaialble as $1, $2, etc.
 * Lines that start with a # will be ignored as comments.
 * .
 * # Recipe will receive $name and $action
 * recipe buildSite.boxr name=luis action=create
 * .
 * # Recipe will receive $1 and $2
 * recipe buildSite.boxr luis create
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false{

	/**
	 * @recipeFile.hint The name of the recipe file to execute including extension
	 **/
	function run( required recipeFile ){
		// store original path
		var originalPath = shell.pwd();
		// Make file canonical and absolute
		arguments.recipeFile = fileSystemUtil.resolvePath( arguments.recipeFile );
		
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
			
			// Ignore blank lines and comments
			if( !thisCommand.len() || thisCommand.startsWith( '##' ) ) {
				continue;
			}
			// Turn echo on
			if( reFindNoCase( 'echo\s+on', thisCommand ) ) {
				isEcho = true;
				continue;
			}
			// Turn echo off
			if( reFindNoCase( 'echo\s+off', thisCommand ) ) {
				isEcho = false;
				print.line( thisCommand );
				continue;
			}
			
			// Ignore blank lines and comments
			if( !thisCommand.len() || thisCommand.startsWith( '##' ) ) {
				continue;
			}
			
			try{
				// If echo is on, display the command
				if( isEcho ) {
					print.line( thisCommand );	
				}
				// run Command
				runCommand( thisCommand );

			} catch( any e ){
				print.boldGreen( "Error executing command #thiscommand#, exiting recipe." );
				return error( '#e.message##CR##e.detail##CR##e.stackTrace#' );
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
			argValue = escapeArg( arguments.args[ thisArg ] );
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

	/**
	* Escapes a value and wraps it in quotes for inclusion in a command
	* Replaces " and ' with \" and \' 
	*/
	private string function escapeArg( argValue ) {
		arguments.argValue = replace( arguments.argValue, '\', "\\", "all" );
		arguments.argValue = replace( arguments.argValue, '"', '\"', 'all' );
		arguments.argValue = replace( arguments.argValue, "'", "\'", "all" );
		arguments.argValue = replace( arguments.argValue, "=", "\=", "all" );
		arguments.argValue = replace( arguments.argValue, CR, "\n", "all" );
		return '"#arguments.argValue#"';
	}
}