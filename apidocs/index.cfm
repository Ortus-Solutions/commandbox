<cfsetting requesttimeout="600">
<cfparam name="url.version" default="1.0.0">
<cfparam name="url.path" 	default="#expandPath( "./CommandBox-CommandDocs" )#">
<cfscript>
try{
	docName = "CommandBox-CommandDocs";
	docbox 	= new docBox.DocBox( 
		strategy = "strategy.commandbox.CommandBoxStrategy",
		properties = {
			projectTitle 	= "CommandBox v#url.version#",
			outputDir 		= url.path 
		} 
	);
	baseDir = expandPath( '/commandbox' );
	commandDirs = directoryList(path='/commandbox/system/modules_app', recurse=true, filter=function(path){ return reFindNoCase( '.*[/\\]commands$', arguments.path ); } );
	source = [
	];
	for( dir in commandDirs ) {
		source.append(
			{
				dir : dir,
				mapping : listChangeDelims( replaceNoCase( dir, baseDir, 'commandbox' ), '.', '/\' )
			}
		);
	}
	docbox.generate( source );
} catch ( Any e ){
	rethrow;
	writeOutput( e.message & e.detail );
	writeDump( "<hr>" & e.stacktrace );
	abort;
}
</cfscript>
<cfoutput>
<h1>Command Help Done!</h1>
<a href="#docName#/index.html">Go to Docs!</a>
</cfoutput>