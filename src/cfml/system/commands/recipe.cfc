/**
 * The recipe commands allows you to execute a collection of CommandBox commands
 * usually in a file.boxr recipe file.  CommandBox will iterate and execute each
 * of the commands for you in succession.
 * 
 * recipe buildSite.boxr
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false{

	/**
	 * @file.hint The recipe file to execute
	 **/
	function run( required file ){
		// store original path
		var originalPath = shell.pwd();
		// Make file canonical and absolute
		arguments.file = fileSystemUtil.resolvePath( arguments.file );
		// read it
		var recipe = fileRead( arguments.file );		
		// split commands using carriage return
		var commands = listToArray( recipe, chr( 10 ) );
		// iterate and execute.
		for( var thisCommand in commands ){
			thisCommand = trim( thisCommand );
			
			// Ignore blank lines and comments
			if( !thisCommand.len() || thisCommand.startsWith( '##' ) ) {
				continue;
			}
			
			try{
				runCommand( trim( thisCommand ) );
			} catch( any e ){
				print.boldGreen( "Error executing command #trim( thiscommand )#, exiting recipe." );
				return error( '#e.message##CR##e.detail##CR##e.stackTrace#' );
			}
		}

		// cd to original path just incase 
		shell.cd( originalPath );
	}

}