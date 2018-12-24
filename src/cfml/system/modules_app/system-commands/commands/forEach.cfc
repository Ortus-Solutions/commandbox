/**
 * Excecute a command against every item in an incoming list.  The list can be passed directly
 * or piped into this command.  The default delimiter is a new line so this works great piping 
 * the output of file listings direclty in, which have a file name per line.  
 * .
 * This powerful construct allows you to perform basic loops from the CLI over arbitrary input.
 * Most of the examples show file listings, but any input can be used that you want to iterate over.
 * .
 * This example will use the echo command to output each filename returned by ls.  The echo is called
 * once for every line of output being piped in.
 * {code}
 * ls --simple | forEach
 * {code}
 * .
 * The default command is "echo" but you can perform an action against the incoming list of items.
 * This example will use "cat" to output the contents of each file in the incoming list.
 * {code}
 * ls *.json --simple | forEach cat
 * {code}
 * .
 * You can customize the delimiter.  This example passes a hard-coded input and spits it on commas.
 * So here, the install command is run three times, once for each package. A contrived, but effective example.
 * {code}
 * forEach input="coldbox,testbox,cborm" delimiter="," command=install
 * {code}
 * .
 * If you want a more complex command, you can choose exactly where you wish to use the incoming item
 * by referencing the default system setting expansion of ${item}.  Remember to escape the expansion in 
 * your command so it's resolution is deferred until the forEach runs it internally.
 * Here we echo each file name followed by the contents of the file.
 * {code}
 * ls *.json --simple | foreach "echo \${item} && cat \${item}"
 * {code}
 * .
 * You may also choose a custom placeholder name for readability.
 * {code}
 * ll *.json --simple | foreach "echo \${filename} && cat \${filename}" filename
 * {code}
 **/
component {
	property name='SystemSettings' inject='SystemSettings';

	/**
	 * @input The piped input to iterate over
	 * @command Command to be run once per input item
	 * @itemName Name of system setting to access each item per iteration
	 * @delimiter Delimiter Char(s) to split input,
	 * @valueName Name of system setting to access value when iterating over struct
	 * @continueOnError Whether to stop processing when one iteration errors
	 * @debug Output command to be executed for each iteration
	 **/
	function run(
		string input='',
		string command='echo',
		string itemName='item',
		string delimiter=CR,
		string valueName='value',
		boolean continueOnError=false,
		boolean debug=false
		) {
		var wasJSON = false;
		var inputJSON = '';
		
		arguments.input = print.unANSI( arguments.input );
		
		if( isJSON( arguments.input ) ) {
			var inputJSON = deserializeJSON( arguments.input );
			
			if( isArray( inputJSON ) || isStruct( inputJSON ) ) {
				var content = inputJSON;
				wasJSON = true;
			}
		}
		if( !wasJSON ) {
			// Turn output into an array, breaking on delimiter
			var content = listToArray( arguments.input, delimiter );
		}
		
		// Loop over content
		for( var line in content ) {
			var theCommand = this.command( arguments.command );
			
			if( !isSimpleValue( line ) ) {
				line = serializeJSON( line );
			}
			
			// If it doesn't look like they are using the placeholder, then set the item as the next param
			if( !arguments.command.findNoCase( '${#itemName#' ) && !arguments.command.findNoCase( '${#valueName#' ) ) {
				theCommand.params( line );
			}
			
			// Set this as a localized environment variable so the command can access it.
			systemSettings.setSystemSetting( itemName, line );
			
			// If foreach was passed a struct, set the value as well
			if( isStruct( inputJSON ) ) {
				var thisValue = content[line ];
				if( !isSimpleValue( thisValue ) ) {
					thisValue = serializeJSON( thisValue );
				}
				systemSettings.setSystemSetting( valueName, thisValue );
			}
			
			try {
				theCommand.run( echo=debug );
			} catch( any var e ) {
				if( continueOnError ) {
					
					print
						.redLine( e.message )
						.redLine( e.detail ?: '' )
						.toConsole();
						
				} else {
					rethrow;
				}
			}
			
		}
	}

}
