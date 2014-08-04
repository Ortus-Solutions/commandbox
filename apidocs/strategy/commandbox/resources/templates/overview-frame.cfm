<cfscript>
	// Build out data
	var namespaces = {};
	var topLevel = {};
	// Loop over commands
	for( var row in qMetaData ) {
		var command = row.command;			
		var bracketPath = '';
		// Build bracket notation 
		for( var item in listToArray( row.namespace, ' ' ) ) {
			bracketPath &= '[ "#item#" ]';
		}
		// Set "deep" struct to create nested data
		var link = replace( row.package, ".", "/", "all") & '/' & row.name & '.html';
		var packagelink = replace( row.package, ".", "/", "all") & '/package-summary.html';
		var searchList = row.command;
		if( !isNull( row.metadata.aliases ) && len( row.metadata.aliases ) ) {
			searchList &= ',' & row.metadata.aliases;
		}
		
		var thisTree = ( listLen( command, ' ' ) == 1 ? "topLevel" : "namespaces" );
		evaluate( '#thisTree##bracketPath#[ "$link" ] = packageLink' );
		evaluate( '#thisTree##bracketPath#[ row.name ][ "$command"].link = link' );
		evaluate( '#thisTree##bracketPath#[ row.name ][ "$command"].searchList = searchList' );
	}
	
	// Recursive function to output data
	function writeItems( struct startingLevel ) {
		for( var item in startingLevel ) {
			if( item == '$link' ) { continue; }
			var itemValue = startingLevel[ item ];
			
			if( structKeyExists( itemValue, '$command' ) ) {
				writeOutput( '<li data-jstree=''{ "type" : "command" }'' linkhref="#itemValue.$command.link#" searchlist="#itemValue.$command.searchList#" thissort="2">' );
				writeOutput( item );
				writeOutput( '</li>' );
				
			} else {
				writeOutput( '<li data-jstree=''{ "type" : "namespace" }'' linkhref="#itemValue.$link#" searchlist="#item#" thissort="1">' );
				writeOutput( item );
				writeOutput( '<ul>' );
					writeItems( itemValue );
				writeOutput( '</ul>' );
				writeOutput( '</li>' );
			}
			
		}
	}
</cfscript>
<!---<cfdump var="#namespaces#"><cfabort>--->
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

	<input type="text" id="commandSearch" placeholder="Search..."><br><br>
	<div id="commandTree">
		<ul>
			#writeItems( namespaces )#
			<li data-jstree='{ "type" : "system" }' linkhref="#topLevel.$link#" searchlist="System" thissort="3">
				System Commands
				<ul>
					#writeItems( topLevel )#
				</ul>
			</li>
		</ul>
	</div>
	
	<script src="jstree/jstree.min.js"></script>
	<script language="javascript">
		$(function () { 
			
			$('##commandTree')
				.jstree({
				    "types" : {
				      "namespace" : {
				        "icon" : "glyphicon glyphicon-th-large"
				      },
				      "command" : {
				        "icon" : "glyphicon glyphicon-flash"
				      },
				      "system" : {
				        "icon" : "glyphicon glyphicon-cog"
				      }
				    },
				    "search" : {
				    	"show_only_matches" : true,
				    	"search_callback" : function( q, node ) {
				    		q = q.toUpperCase();
				    		var searchArray = node.li_attr.searchlist.split(',');
				    		var isCommand = node.li_attr.thissort != 1;
				    		for( var i in searchArray ) {
				    			var item = searchArray[ i ];
				    			if( ( isCommand && item.toUpperCase().indexOf( q ) > -1 )
				    				|| ( !isCommand && q.indexOf( item.toUpperCase() ) > -1 ) ) {
				    				return true;
				    			}
				    		}
				    		return false;
				    	}
				    },
				    "sort" : function( id1, id2 ) {
				    			var node1 = this.get_node( id1 );
				    			var node2 = this.get_node( id2 );
					    		var node1String = node1.li_attr.thissort + node1.text;
					    		var node2String = node2.li_attr.thissort + node2.text;
					    		
								return ( node1String > node2String ? 1 : -1);						
				    },
				    "plugins" : [ "types", "search", "sort" ]
				  })
				.on("changed.jstree", function (e, data) {
					var obj = data.instance.get_node(data.selected[0]).li_attr;
					if( obj.linkhref ) {
						window.parent.frames['classFrame'].location.assign( obj.linkhref );						
					}
			});
			
			 var to = false;
			  $('##commandSearch').keyup(function () {
			    if(to) { clearTimeout(to); }
			    to = setTimeout(function () {
			      var v = $('##commandSearch').val();
			      $('##commandTree').jstree(true).search(v);
			    }, 250);
			  });
			
		 });
	</script>
</body>
</html>
</cfoutput>