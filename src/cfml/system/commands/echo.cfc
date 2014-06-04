/**
 * Outputs the text you enter
 *
 * echo "Hello World!"
 * 
 **/
component extends="commandbox.system.BaseCommand" aliases="" excludeFromHelp=false {

	/**
	 * @text.hint The text to output
	 **/
	function run( String text="" )  {
		return arguments.text;
	}

}