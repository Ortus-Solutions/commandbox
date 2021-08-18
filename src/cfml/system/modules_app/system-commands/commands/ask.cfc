/**
 * Prompt the user for an answer and return it.  Requires an interactive terminal.
 * .
 * Output a single file
 * {code:bash}
 * set color=`ask "favorite Color? "`
 * echo "you said ${color}"
 * {code}
 * 
 **/
component {

	/**
	 * @question Question to ask the user
	 * @defaultResponse Default what shows in the buffer
	 * @mask Set to a char like * to hide passwords, etc
 	 **/
	function run(
		required string question,
		string defaultResponse='',
		string mask='' 
	)  {
		return ask( message=question, defaultResponse=defaultResponse, mask=mask );
	}

}
