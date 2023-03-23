/**
 * Outputs the text entered but with ANSI formatting stripped.  Useful when you want to pipe output into a command which doesn't understand or need ANSI formatting.
 * .
 * {code:bash}
 * package show | unansi
 * {code}
 *
 **/
component {

	/**
	 * @text.hint The text to output without ANSI formatting
	 **/
	function run( String text="" )  {
		print.text( print.unansi( arguments.text ) );
	}

}
