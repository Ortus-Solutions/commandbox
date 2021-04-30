/**
 * The Table Printer
 * .
 * The print helper contains a feature that will generate ASCII tables to print tabular data from the CLI.
 * .
 * This command is built to handle multiple type of data inluding:
 *  - simple values:  string, number, boolean, json, string
 *  - complex data: arrays and structs
 *  - table like data: array of arrays, arrays of structs, serialized json, serialized queries
 * *
 * {code:bash}
 * printTable [1,2,3,4,5,6,5,7,9] "numbers"
 * printTable [{'a':2},{'a':4},{'a':5},{'a':8}]
 * cat myfile.json | printTable ""
 * {code}
 * *
 * For array and simple values with no column names it will default to: col_1, col_2, ...
 * For arrays of structs or serialized json the struct keys will be used
 * {code:bash}
 * printTable [1,2,3,4,5,6,5,7,9] // column name "col_1"
 * printTable [{'a':2},{'a':4},{'a':5},{'a':8}] // column name "a"
 * {code}
 * for array of structs or serialized queries, if a list of columns
 * is given that will be all that is displayed
 * {code:bash}
 * #extensionlist | printTable name,version
 * {code}
 * .
 * The third argument "columnsOnly" will give you a list of
 * available columns and the first row of data to help you choose
 * the columns you want
 * {code:bash}
 * printTable "[{'a':2},{'a':4},{'a':5},{'a':8}]" "" true
 * ╔════════╤════════════════╗
 * ║ Column │ First Row Data ║
 * ╠════════╪════════════════╣
 * ║ a      │ 2              ║
 * ╚════════╧════════════════╝
 * {code}
 */
component {

	// DI Properties
	property name="consoleLogger"			inject="logbox:logger:console";

	/**
	 * @input.hint The text to process with table like data in it
	 * @columns.hint A comma seperated list of column names
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
