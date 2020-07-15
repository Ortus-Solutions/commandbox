/**
 * Watch the files in a directory and run a custom command of your choice
 *
 * {code}
 * watch *.json "echo 'config file updated!'"
 * {code}
 * 
 * The following environment variables will be available to your command
 * - watcher_added - A JSON array of relative paths added in the watch directory
 * - watcher_removed - A JSON array of relative paths removed in the watch directory
 * - watcher_changed - A JSON array of relative paths changed in the watch directory
 *
 * {code}
 * set command = "echo 'You added \${item}!'"
 * watch command="foreach '\${watcher_added}' \${command}" --verbose
 * {code}
 *
 * Note in the above example, the ${watcher_added} and ${command} env vars in the "inner" command are escaped.
 * We also set an intermediate env var to hold the command to keep from needing to "double escape" it.
 *
 * This command will run in the foreground until you stop it.  When you are ready to shut down the watcher, press Ctrl+C.
 *
 **/
component {

	/**
	 * @paths Command delimited list of file globbing paths to watch relative to the working directory, defaults to **
	 * @command The command to run when the watcher fires
	 * @delay How may milliseconds to wait before polling for changes, defaults to 500 ms
	 * @directory Working directory to start watcher in
	 * @verbose Output details about the files that changed
	 **/
	function run(
		string paths='**',
		string command,
		number delay=500,
		string directory=getCWD(),
		boolean verbose=false
	){
		
		// handle non numeric config and put a floor of 150ms
		var delayMs       = max( val( arguments.delay ), 50 );
		var statusColors  = {
			"added"   : "green",
			"removed" : "red",
			"changed" : "yellow"
		}
		
		// General Message about the globbing paths and its purpose
		print
			.greenLine( "---------------------------------------------------" )
			.greenLine( "Watching the following files ..." )
			.greenLine( "---------------------------------------------------" )
			.greenLine( " " & arguments.paths )
			.greenLine( " Press Ctrl-C to exit " )
			.greenLine( "---------------------------------------------------" )
			.toConsole();
	
		// Start watcher
		watch()
			.paths( arguments.paths.listToArray() )
			.inDirectory( directory )
			.withDelay( delayMs )
			.onChange( function( changeData ){
				if( verbose ) {
					// output file changes
					var changetime = "[" & timeFormat( now(), "HH:mm:ss" ) & "] ";
					for ( status in changeData ) {
						changeData[ status ].map( function( filePath ){
							print
								.text( changetime, statusColors[ status ] )
								.text( filePath, statusColors[ status ] & "Bold" )
								.line( " " & status & " ", statusColors[ status ] )
								.toConsole();
						} );
					}
				}

				// This will give the command programmatic access to the changed files via env vars
				setSystemSetting( "watcher_added", serializeJSON( changeData.added ) );
				setSystemSetting( "watcher_removed",  serializeJSON( changeData.removed ) );
				setSystemSetting( "watcher_changed",  serializeJSON( changeData.changed ) );

				// Runn the command
				runCommand( command );
			} )
			.start();
	}

}
