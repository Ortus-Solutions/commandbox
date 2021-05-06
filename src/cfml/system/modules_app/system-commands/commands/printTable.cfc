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
 * printTable {'a':2,b:4}
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
 * #extensionlist | printTable "name,version"
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
 *  The "filter" argument allows you to pass a SQL "where" statement to filter your data
 * {code:bash}
 * #extensionlist | printTable "name,version" "name like '%My%'"
 * ╔══════════════════════╤═══════════════════╗
 * ║ name                 │ version           ║
 * ╠══════════════════════╪═══════════════════╣
 * ║ MySQL                │ 8.0.19            ║
 * ╚══════════════════════╧═══════════════════╝
 * {code}
 * .
 * The "columnsOnly" parameter will give you a list of available columns and the first row of data to help you choose the columns you want
 * {code:bash}
 * printTable "[{'a':2},{'a':4},{'a':5},{'a':8}]" --columnsOnly
 * ╔════════╤════════════════╗
 * ║ Column │ First Row Data ║
 * ╠════════╪════════════════╣
 * ║ a      │ 2              ║
 * ╚════════╧════════════════╝
 * {code}
 */
component {

	processingdirective pageEncoding='UTF-8';

	/**
	 * @input The text to process with table like data in it
	 * @columns A comma seperated list of column names, eg. "name,version"
	 * @filter A SQL where filter used in a query of queries, eg. "name like '%My%'"
	 * @columnsOnly Only print out the names of the columns and the first row values
 	 **/
	function run(
		required string input,
		string columns='',
		string filter='',
		boolean columnsOnly=false
	)  {

		// Treat input as a potential file path
		arguments.input = print.unAnsi( arguments.input );

		//deserialize data if in a JSON format
		if(isJSON(arguments.input)) arguments.input = deserializeJSON( arguments.input, false );

		//pass all arguments to print table
		print.table(arguments.columns,arguments.input, arguments.columns, arguments.filter, arguments.columnsOnly);
	}

}
