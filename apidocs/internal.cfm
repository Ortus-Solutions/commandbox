<!---
This will produce the internal API Docs for CommandBox.
--->
<cfparam name="url.version" default="1.0.0">
<cfparam name="url.path" 	default="#expandPath( "./CommandBox-APIDocs" )#">
<cfscript>
try{
	docName = "CommandBox-APIDocs";
	docbox 	= new docBox.DocBox( 
		properties = {
			projectTitle 	= "CommandBox Internal v#url.version#",
			outputDir 		= url.path 
		} 
	);
	docbox.generate( 
		source 		= expandPath( "/commandbox/system" ), 
		mapping 	= "commandbox.system",
		excludes 	= "system\/(modules)"
	);
} catch ( Any e ){
	writeOutput( e.message & e.detail );
	writeDump( "<hr>" & e.stacktrace );
	abort;
}
</cfscript>
<cfoutput>
<h1>Command Internal API Docs Done!</h1>
<a href="#docName#/index.html">Go to Docs!</a>
</cfoutput>