<cfparam name="url.version" default="0">
<cfparam name="url.path" 	default="#expandPath( "./CommandBox-APIDocs" )#">
<cfscript>
	docName = "CommandBox-Docs";
	base = expandPath( "/commandbox" );

	colddoc 	= new ColdDoc();
	strategy 	= new colddoc.strategy.api.HTMLAPIStrategy( url.path, "CommandBox v#url.version#" );
	colddoc.setStrategy( strategy );

	colddoc.generate( inputSource=base, outputDir=url.path, inputMapping="commandbox" );
</cfscript>

<cfoutput>
<h1>Done!</h1>
<a href="#docName#/index.html">Go to Docs!</a>
</cfoutput>

