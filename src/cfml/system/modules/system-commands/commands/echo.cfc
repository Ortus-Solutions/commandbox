/**
 * Outputs the text entered.
 * .
 * {code:bash}
 * echo "Hello World!"
 * {code}
 * .
 * This can be useful in CommandBox Recipies, or to pipe arbitrary text into another command.
 * .
 * {code:bash}
 * echo "Step 3 complete" >> log.txt
 * {code}
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