/**
 * Prints an ASCII table to the console based on incoming JSON.  Input will be marshalled to be tabular if needed.
 *
 * JSON data can be passed in the first param or piped into the command:
 * {code:bash}
 * printTable [1,2,3]
 * package show | printTable
 * cat myfile.json | printTable
 * {code}
 *
 * The following types of data are supported, passed as JSON.
 * If the object is a struct, a table with a single row will be printed, using the struct keys as the column names.
 * {code:bash}
 * printTable {'a':2,'b':4}
 * ╔═══╤═══╗
 * ║ a │ b ║
 * ╠═══╪═══╣
 * ║ 2 │ 4 ║
 * ╚═══╧═══╝
 * {code}
 *
 * If an array is passed, each item in the array will become a row in the table.
 * {code:bash}
 * printTable [1,2,3] num
 * ╔═════╗
 * ║ num ║
 * ╠═════╣
 * ║ 1   ║
 * ╟─────╢
 * ║ 2   ║
 * ╟─────╢
 * ║ 3   ║
 * ╚═════╝
 * {code}
 * Represent tabular data as an array of arrays or an arary of structs.  The number of columns will be based on the first row's data.
 * For array and simple values, the column names will default to: col_1, col_2, etc.
 * For arrays of structs, the struct keys in the first row will be used
 * {code:bash}
 * .
 * printTable [{a:1,b:2},{a:3,b:4},{a:5,b:6}]
 * ╔═══╤═══╗
 * ║ a │ b ║
 * ╠═══╪═══╣
 * ║ 1 │ 2 ║
 * ╟───┼───╢
 * ║ 3 │ 4 ║
 * ╟───┼───╢
 * ║ 5 │ 6 ║
 * ╚═══╧═══╝
 * .
 * printTable [[1,2],[3,4],[5,6]]
 * ╔═══════╤═══════╗
   ║ col_1 │ col_2 ║
 * ╠═══════╪═══════╣
 * ║ 1     │ 2     ║
 * ╟───────┼───────╢
 * ║ 3     │ 4     ║
 * ╟───────┼───────╢
 * ║ 5     │ 6     ║
 * ╚═══════╧═══════╝
 * {code}
 *
 * For array of structs or serialized queries, if a list of columns is given that will be all that is displayed
 * {code:bash}
 * #extensionlist | printTable name,version
 * ╔══════════════════════╤═══════════════════╗
 * ║ name                 │ version           ║
 * ╠══════════════════════╪═══════════════════╣
 * ║ MySQL                │ 8.0.19            ║
 * ╟──────────────────────┼───────────────────╢
 * ║ Microsoft SQL Server │ 4.0.2206.100      ║
 * ╟──────────────────────┼───────────────────╢
 * ║ Ajax Extension       │ 1.0.0.3           ║
 * ╚══════════════════════╧═══════════════════╝
 * {code}
 * .
 * The "headerNames" argument allows you to overwrite existing or auto created column names
 * {code:bash}
 * printTable [[1,2],[3,4],[5,6]] name,version "name,version"
 * ╔════════╤═══════════╗
 * ║ name   │ version   ║
 * ╠════════╪═══════════╣
 * ║   1    │     2     ║
 * ╟────────┼───────────╢
 * ║   3    │     4     ║
 * ╟────────┼───────────╢
 * ║   5    │     6     ║
 * ╚════════╧═══════════╝
 * {code}
 * .
 * The "columnsOnly" parameter will give you a list of available columns and the first row of data to help you choose the columns you want
 * {code:bash}
 * printTable "[{'a':2},{'a':4},{'a':5},{'a':8}]" --debug
 * ╔════════╤════════════════╗
 * ║ Column │ First Row Data ║
 * ╠════════╪════════════════╣
 * ║ a      │ 2              ║
 * ╚════════╧════════════════╝
 * {code}
 */
component {

	processingdirective pageEncoding='UTF-8';
	property name='tablePrinter'    inject='provider:TablePrinter';

	/**
     * Outputs a table to the screen
	 * @data Any type of data for the table.  Each item in the array may either be
	 *            an array in the correct order matching the number of headers or a struct
	 *            with keys matching the headers.
	 * @includedHeaders A list of headers to include.  Used for query inputs
     * @headerNames An list/array of column headers to use instead of the default
	 * @debug Only print out the names of the columns and the first row values
     */

    public string function run(
		required any data=[],
        any includedHeaders="",
        any headerNames="",
		boolean debug=false
    ) {

		// Treat input as a potential file path
		arguments.data = print.unAnsi( arguments.data );

		//deserialize data if in a JSON format
		if(isJSON(arguments.data)) arguments.data = deserializeJSON( arguments.data, false );

		//pass all arguments to print table
		return tablePrinter.print( argumentCollection=arguments );
	}

}
