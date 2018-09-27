/**
 * Append to existing text in a file. Will add a newline automatically
 * .
 * {code:bash}
 * fileAppend "My new line" file.txt
 * {code}
 * .
 * You can pipe text into it.
 * .
 * {code:bash}
 * echo "My new line" | fileAppend file.txt
 * {code}
 * .
 * This command is also used internally for redirection when you use the >> symbol.
 * .
 * {code:bash}
 * echo "Step 3 complete" >> log.txt
 * {code}
 *
 **/
component excludeFromHelp=true {

	/**
	 * @contents.hint Contents to append to the file
	 * @file.hint File to append to
 	 **/
	function run( required contents='', required string file )  {

		// This will make the file path canonical and absolute
		arguments.file = resolvePath( arguments.file );

		// Clean out any ANI escape codes from the text
		arguments.contents = print.unansi( arguments.contents );

		// Append to the file
		file
		    action = "append"
		    file = "#arguments.file#"
		    output = "#arguments.contents#"
		    addNewLine = "yes";

	}

}
