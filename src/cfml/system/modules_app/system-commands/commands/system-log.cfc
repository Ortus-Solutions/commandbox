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

		var logFilePath = expandpath( '/commandbox-home' ) & "/logs/commandbox.log";

		print.text( logFilePath );

	}

}
