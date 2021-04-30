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
	 * @columns A comma seperated list of column names
	 * @columnsOnly Only print out the names of the columns for debugging
 	 **/
	function run(
		required string input,
		string columns='',
		boolean columnsOnly=false
	)  {

		// Treat input as a file path
		arguments.input = print.unAnsi( arguments.input );
		if(isJSON(arguments.input)) arguments.input = deserializeJSON( arguments.input );

		var data = arguments.input;
		//explicit check for a query serialized as JSON { 'COLUMNS':[], 'DATA': [] }
		if(isStruct(data) && data.keyExists( 'COLUMNS' ) && data.keyExists( 'DATA' )){
			if(arguments.columns == "") arguments.columns = arrayToList(arguments.input.columns);
			data = arguments.input.data;
		} else {
			data = normalizeData(data);
			if(!data.len()) throw ( message = "No data provided" );
		}

		arguments.columns = listToArray( arguments.columns );
		if(!arguments.columns.len()) arguments.columns = generateColumnNames(data[1]);

		var tableSafeData = toSafeData(data,arguments.columns);

		if(!!arguments.columnsOnly){
			var dataset = [];
			for(var i = 1; i <= arguments.columns.len(); i++){
				var firstRow = tableSafeData[1];
				var colName = arguments.columns[i];
				dataset.append([colName,isStruct(firstRow) ? firstRow[colName] : firstRow[i]])
			}
			print.table(['Column','First Row Data'],dataset);
		} else {
			print.table(arguments.columns,tableSafeData);
		}
	}

	// fill arrays and structs with columns positions/keys to make it safe for the table printer
	private function toSafeData(data, columns){
		return data.map((row) => {
			if(isStruct(row)){
				for(var i in columns){
					if(row.keyExists(i)){
						if(!isSimpleValue(row[i])) row[i] = serializeJSON(row[i]);
					} else {
						row[i] = "";
					}
				}
			} else if(isArray(row)){
				for(var i = 1; i <= columns.len(); i++){
					if(arrayIndexExists(row,i)) {
						if(!isSimpleValue(row[i])) row[i] = serializeJSON(row[i]);
					} else {
						row.append("");
					}
				}
			}
			return row;

		})
	}

	// take a simple value/array of values/or struct and normalize it to fit the table printer format
	private function normalizeData(data){
		var data = isArray(data) ? data : [data];
		return data.map((x) => {
			return (isArray(x) || isStruct(x)) ? x : [x];
		})
	}

	// create column names from data, default to col_1 ... for simple values and arrays, use key names for structs
	private function generateColumnNames (data){
		if(isSimpleValue(data)){
			return  ['col_1'];
		} else if ( isArray(data) ){
			return data.map((x,i) => 'col_' & i);
		} else if ( isStruct(data) ){
			return  structKeyArray(data);
		}
		return [];
	}


}
