/**
 * Outputs the text entered.
 * .
 * {code:bash}
 * echo "Hello World!"
 * {code}
 * .
 * This can be useful in CommandBox Recipes, or to pipe arbitrary text into another command.
 * .
 * {code:bash}
 * echo "Step 3 complete" >> log.txt
 * {code}
 *
 **/
component {

	/**
	 * @text.hint The text to output
	 **/
	function run( String text="" )  {
		print.text( arguments.text );
	}

}
