<cfscript>
	// Build out data
	var namespaces = {};
	var topLevel = {};
	// Loop over commands
	for( var row in qMetaData ) {
		var command = row.command;			
		var bracketPath = '';
		// Build bracket notation 
		for( var item in listToArray( command, ' ' ) ) {
			bracketPath &= '[ "#item#" ]';
		}
		// Set "deep" struct to create nested data
		evaluate( '#( listLen( command, ' ' ) == 1 ? "topLevel" : "namespaces" )##bracketPath# = ""' );
	}
	
	// Recursive function to output data
	function writeItems( struct startingLevel ) {
		for( var item in startingLevel ) {
			var itemValue = startingLevel[ item ];
			writeOutput( '<li>' );
				writeOutput( '#item#' );
				if( isStruct( itemValue ) ) {
					writeOutput( '<ul>' );
						writeItems( itemValue );
					writeOutput( '</ul>' );
				}				
			writeOutput( '</li>' );
		}
	}
</cfscript>

<cfoutput>
<!DOCTYPE html>
<html lang="en">
<head>
	<title>	overview </title>
	<meta name="keywords" content="overview">
	<cfmodule template="inc/common.html" rootPath="">
	<link rel="stylesheet" href="jstree/themes/default/style.min.css" />
</head>

<body>
	<h3><strong>#arguments.projecttitle#</strong></h3>

	
	<div id="commandTree">
		<ul>
			#writeItems( namespaces )#
			<li>
				System Comamnds
				<ul>
					#writeItems( topLevel )#
				</ul>
			</li>
		</ul>
	</div>
	
	<script src="jstree/jstree.min.js"></script>
	<script language="javascript">
		$(function () { 
			$('##commandTree').jstree();
		 });
	</script>
</body>
</html>
</cfoutput>