/**
 * Write a file, overwriting it if it exists.
 * .
 * {code:bash}
 * fileWrite "My file contents" file.txt
 * {code}
 * .
 * You can pipe text into it.
 * .
 * {code:bash}
 * echo "My file contents" | fileWrite file.txt
 * {code}
 * .
 * This command is also used internally for redirection when you use the > symbol.
 * .
 * {code:bash}
 * dir > fileList.txt
 * {code}
 *
 **/
component excludeFromHelp=true {

	/**
	 * @contents.hint Contents to write to the file
	 * @file.hint File to write to
 	 **/
	function run( required contents='', required string file )  {

		// This will make the file path canonical and absolute
		arguments.file = resolvePath( arguments.file );

		directoryCreate( getDirectoryFromPath( file ), true, true );

		// Clean out any ANI escape codes from the text
		arguments.contents = print.unansi( arguments.contents );

		// Write the file
		fileWrite( arguments.file, arguments.contents );

	}

}
