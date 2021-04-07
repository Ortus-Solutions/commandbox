/**
 * JSON Query command for filtering data out of a JSON Object or file. jq is a query language
 * built specifically for interacting with JSON type data. More information can be found
 * at https://jmespath.org/ as well as an online version to test your query
 * Pass or pipe the text to process or a filename
 * .
 * {code:bash}
 * jq myjsonfile.json "a.b.c.d"
 * Outputs: "foo"
 * .
 * jq "{"a": {"b": {"c": {"d": "value"}}}}" "a.b.c.d"
 * Outputs: "foo"
 * {code}
 * Basic
 * {code:bash}
 * {"foo":{"bar":{"baz":"correct"}}}
 * foo -> {"bar":{"baz":"correct"}}
 * foo.bar -> {"baz":"correct"}
 * *.bar -> {"baz":"correct"}
 * {code}
 * Multiselect
 * {code:bash}
 * {"foo":{"bar":1,"baz":[2,3,4], "buz":2}}
 * foo.{bar: bar, buz: buz}    -> {"bar":1,"buz":2}
 * {code}
 * Filters
 * {code:bash}
 * '{"foo":[{"age":20},{"age":25},{"age":30}]}' 'foo[?age > `25`]'  -> [{"age":30}]
 * {code}
 * Filter boolean functions:
 * {code:bash}
 * contains, ends_with, starts_with
 * {code}
 * Math functions:
 * {code:bash}
 * abs, avg, ceil, floor, max min, sum
 * {code}
 * Sort functions:
 * {code:bash}
 * sort, sort_by, max_by, min_by, reverse
 * {code}
 * Conversion functions:
 * {code:bash}
 * to_array,to_string, to_number
 * {code}
 **/
component {

	// DI Properties
	property name="JSONService" inject="JSONService";

	/**
	 * @inputOrFile.hint The text to process, or a file name
	 * @query.hint The command to perform on the input text.  Ex: a.b
 	 **/
	function run(
		required string inputOrFile,
		required string query
		)  {

		// Treat input as a file path
		if( fileExists( arguments.inputOrFile )) {
			arguments.inputOrFile = fileRead( arguments.inputOrFile );
		} else {
			arguments.inputOrFile = print.unAnsi( arguments.inputOrFile );
		}

		try {
			var propertyValue = JSONService.show( deserializeJSON(arguments.inputOrFile), arguments.query );

			print.line( propertyValue );

		} catch( JSONException var e ) {
			error( e.message );
		} catch( any var e ) {
			rethrow;
		}

	}


}
