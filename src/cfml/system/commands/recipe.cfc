/**
 * The recipe commands allows you to execute a collection of CommandBox commands
 * usually in a file.boxr recipe file.  CommandBox will iterate and execute each
 * of the commands for you in succession. You can also bind the recipe with arguments
 * that will be replaced inside of your recipe.  The arguments is a form of query string.
 * Ex: name:luis&action:create that will be used in side of your recipe using @name@ notation.
 * 
 * recipe buildSite.boxr name:luis&action:create
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false{

	/**
	 * @file.hint The recipe file to execute
	 * @arguments.hint The arguments to bind to this recipe, in query string format. Ex: name:luis&action:create
	 **/
	function run( required file, arguments="" ){
		// store original path
		var originalPath = shell.pwd();
		// Make file canonical and absolute
		arguments.file = fileSystemUtil.resolvePath( arguments.file );
		// read it
		var recipe = fileRead( arguments.file );		
		// split commands using carriage return
		var commands = listToArray( recipe, chr( 10 ) );
		// Parse Commands
		var sArgs = parseArguments( arguments.arguments );
		
		// iterate and execute.
		for( var thisCommand in commands ){
			thisCommand = trim( thisCommand );
			
			// Ignore blank lines and comments
			if( !thisCommand.len() || thisCommand.startsWith( '##' ) ) {
				continue;
			}
			
			try{
				// bind command with arguments
				thisCommand = bindCommand( thisCommand, sArgs );
				// run Command
				runCommand( trim( thisCommand ) );

			} catch( any e ){
				print.boldGreen( "Error executing command #trim( thiscommand )#, exiting recipe." );
				return error( '#e.message##CR##e.detail##CR##e.stackTrace#' );
			}
		}

		// cd to original path just incase 
		shell.cd( originalPath );
	}

	/**
	* Bind arguments to commands
	*/
	private string function bindCommand( required command, required struct args ){
		// iterate and bind.
		for( var thisArg in arguments.args ){
			arguments.command = replaceNoCase( arguments.command, "@#thisArg#@", arguments.args[ thisArg ], "all" );
		}
		return arguments.command;
	}

	/**
	* Parse arguments and return a collection
	*/
	private struct function parseArguments( required string args ){
		var results = {};
		// cleanup
		arguments.args = trim( arguments.args );
		// verify length
		if( !len( arguments.args ) ){ return {}; }
		// get a list
		var aArgs = listToArray( arguments.args, "&" );
		// iterate and create
		for( var thisArg in aArgs ){
			// if we have a name value pair, then use it
			if( listLen( thisArg, ":" ) ){
				results[ listFirst( thisArg, ":" ) ] = getToken( thisArg, 2, ":" );
			} else {
				results[ listFirst( thisArg, ":" ) ] = "";
			}
		}

		return results;
	}

}