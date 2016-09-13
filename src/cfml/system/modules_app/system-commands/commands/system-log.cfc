/**
 * Outputs the path to the system log file
 * .
 * {code:bash}
 * system-log
 * {code}
 * 
 * Combine with other commands to print the contents of the log to the console
 * or open the log file in the default editor.
 * .
 * {code:bash}
 * system-log | open
 * system-log | cat 
 * system-log | tail
 * {code}
 **/
component {

	/**
	* @open Open the file
  	 **/
	function run()  {
	
		var system 	= createObject( "java", "java.lang.System" );	
		var logFilePath = isNull( system.getProperty('cfml.cli.home') ) ? 
			system.getProperty( 'user.home' ) & "/.CommandBox/" : 
			system.getProperty( 'cfml.cli.home' ) 
				& "/logs/commandbox.log";

		print.line( logFilePath );
		
	}

}