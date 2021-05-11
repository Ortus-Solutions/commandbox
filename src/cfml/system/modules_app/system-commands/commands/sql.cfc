/**
 * SQL query command for filtering table like data. This command will automatically
 * format any table like data into a query object that can be queried against
 *
 * JSON data can be passed in the first param or piped into the command:
 * {code:bash}
 * // (arrays or array of arrays, are given automatic column names)
 * sql data=[[1,2],[3,4]] select=col_1
 * #extensionlist  | sql select=id,name
 * cat myfile.json | sql select=id,name where="name like '%sql%'" orderby=name limit=3
 * {code}
 * .
 * Example Select Statements
 * {code:bash}
 * sql select="*"
 * sql select="id,name, version"
 * sql select="max(name) as maxName"
 * {code}
 * .
 * Example Where Statements
 * {code:bash}
 * sql where="a like "%top"
 * sql where="a > 5"
 * sql where="a <> 5"
 * sql where="a <> 5 and b <> ''"
 * {code}
 * .
 * Example Order By Statements
 * {code:bash}
 * sql orderby="a"
 * sql orderby="a, b"
 * sql orderby="a desc, b asc"
 * {code}
 * .
 * Example Limit/Offset Statements
 * {code:bash}
 * sql limit=1
 * // offset 1 limit 5
 * sql limit=1,5
 * {code}
 * .
 * Advanced piping
 * {code:bash}
 * sql data=[{a:1,b:2},{a:3,b:4},{a:5,b:6}] where="a > 1" | printTable
 * ╔═══╤═══╗
 * ║ a │ b ║
 * ╠═══╪═══╣
 * ║ 3 │ 4 ║
 * ╟───┼───╢
 * ║ 5 │ 6 ║
 * ╚═══╧═══╝
 * {code}
 */
component {

	processingdirective pageEncoding='UTF-8';
	property name="convert" inject="DataConverter";

	/**
	 * @data The text to process with table like data in it
	 * @select A SQL list of column names, eg. "name,version"
	 * @where A SQL where filter used in a query of queries, eg. "name like '%My%'"
	 * @orderby A SQL order by used in a query of queries, eg. "name asc,version desc"
	 * @limit A SQL limit/offset used in a query of queries, eg. "5 or 5,10 (eg. offset 5 limit 10)"
	 * @headerNames An list of column headers to use instead of the default
 	 **/
	function run(
		required string data,
		string select='',
		string where='',
		string orderby='',
		string limit='',
		string headerNames=''
	)  {

		// Treat input as a potential file path
		arguments.data = print.unAnsi( arguments.data );

		//deserialize data if in a JSON format
		if(isJSON(arguments.data)) arguments.data = deserializeJSON( arguments.data, false );

		//format inputs into valid sql parts
		var dataQuery = isQuery( arguments.data ) ? arguments.data : convert.toQuery(arguments.data, arguments.headerNames);

		//setup query pieces
		var columnFilter = arguments.select != "" ? arguments.select: "*";
		var whereFilter = arguments.where != "" ? "Where " & arguments.where: "";
		var orderByFilter = arguments.orderby != "" ? "Order By " & arguments.orderby : "";

		// Run query of queries
		var sqlstatement  = 'SELECT #columnFilter# FROM dataQuery #whereFilter# #orderByFilter#';
		dataQueryResults = queryExecute(sqlstatement,[],{ dbType : 'query', returnType : 'array' });

		//Limit Data
		if(arguments.limit != ""){
			var limitoffset = listToArray(arguments.limit);
			if(limitoffset.len() == 1){
				var limit = min( limitoffset[1], dataQueryResults.len() );
				var offset = 1;
			} else {
				var limit = min( limitoffset[2], dataQueryResults.len() );
				var offset = limitoffset[1];
			}
			if( offset > dataQueryResults.len() ) {
				error( message="Your limit is invalid.", detail="The offset of [#offset#] is greater than the number of results [#dataQueryResults.len()#]" );
			}
			if( limit==0 ) {
				dataQueryResults = [];
			} else {
				dataQueryResults = dataQueryResults.slice(offset, limit);	
			}
		};

		print.line(dataQueryResults);

	}

}
