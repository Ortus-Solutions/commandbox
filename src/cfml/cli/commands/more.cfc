/**
 * This is the more command.  Pipe the output of another command into me and I will break it up for you.
 **/
component persistent="false" extends="cli.BaseCommand" aliases="" excludeFromHelp=true {
	
	/**
	 * @input.hint The piped input to be displayed.
	 **/
	function run( input ) {
		//print.text( left( input, 500 ) );
		print.text( shell.getTermWidth() );
	}

}