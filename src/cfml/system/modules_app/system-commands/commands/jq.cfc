/**
 * JSON Query command for filtering data out of a JSON Object, file, or URL. jq is a query language
 * built specifically for interacting with JSON type data. More information can be found
 * at https://jmespath.org/ as well as an online version to test your query
 * Pass or pipe the text to process or a filename
 * .
 * Run query against file
 * {code:bash}
 * jq myjsonfile.json a.b.c.d
 * {code}
 * Run query against URL
 * {code:bash}
 * jq "https://official-joke-api.appspot.com/jokes/ten" [].join('.....',[setup,punchline])
 * {code}
 * Or against JSON literal
 * {code:bash}
 * jq '{"a": {"b": {"c": {"d": "value"}}}}' a.b.c.d
 * {code}
 * Or piped-in data
 * {code:bash}
 * package list --json | jq name
 * {code}
 * You can do a basic search for keys in JSON wiht a dot-delimited list of key names.
 * Consider this sample JSON:
 * {code:bash}
 * {"foo":{"bar":{"baz":"correct"}}}
 * {code}
 * The following search filters return the noted results.  Note that ".bar" searches in nested structs for a match.
 * {code:bash}
 * foo -> {"bar":{"baz":"correct"}}
 * foo.bar -> {"baz":"correct"}
 * *.bar -> {"baz":"correct"}
 * {code}
 * You can even create a new object out of your filter results using the values from the matched keys.
 * {code:bash}
 * jq {inner:{foo:'apples',bar:true}} inner.{newKey:foo,bar:bar}
 * { "newKey":"apples", "bar":true }
 * {code}
 * You can filter values. Here we take the arary inside "foo" and filter only the objects where the "age" is greater thgan 25
 * Note backticks are used for a litearl value, but we need to escape them in our string so the shell doesn't try to evaluate them.
 * {code:bash}
 * jq '{"foo":[{"age":20},{"age":25},{"age":30}]}' 'foo[?age > \`25\`]'
 * [ { "age":30 } ]
 * {code}
 * .
 * Check the docs for tons more functionality including
 * - Filter boolean functions
 * - Math functions
 * - Sort function:
 * - Conversion functions
 **/
component {

	// DI Properties
	property name="jmespath" 		inject="jmespath";
	property name="consoleLogger"			inject="logbox:logger:console";

	/**
	 * @inputOrFile.hint The text to process, or a file name
	 * @query.hint The command to perform on the input text.  Ex: a.b
 	 **/
	function run(
		required string inputOrFile,
		string query=''
	)  {

		// Treat input as a file path
		var filePath = resolvePath( arguments.inputOrFile );
		if( fileExists( filePath )) {
			arguments.inputOrFile = fileRead( filePath );
		} else {
			arguments.inputOrFile = print.unAnsi( arguments.inputOrFile );
		}

		if( !isJSON( arguments.inputOrFile ) ) {
			error( message="Input is not valid JSON", detail="#left( arguments.inputOrFile, 200 )#" );
		}


		try {

			if(isNull(arguments.query) || arguments.query == ''){
				var propertyValue = ( deserializeJSON(arguments.inputOrFile) );
			} else {
				var propertyValue = jmespath.search( deserializeJSON(arguments.inputOrFile), arguments.query );
			}
			print.text( propertyValue ?: '' );

		} catch( JSONExpression var e ) {
			error('Query:[ ' & arguments.query & ' ] is malformed. Error: ' & e.message)
		} catch( any var e ) {
			rethrow;
		}

	}


}
