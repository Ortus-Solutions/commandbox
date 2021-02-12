<cfoutput>
<cfset instance.class.root = RepeatString( '../', ListLen( arguments.package, ".") ) />
<!DOCTYPE html>
<html lang="en">
<head>
	<title>#arguments.projectTitle# #arguments.command#</title>
	<meta name="keywords" content="#arguments.package# #arguments.command# CommandBox Command CLI">
	<!-- common assets -->
	<cfmodule template="inc/common.html" rootPath="#instance.class.root#">
	<!-- syntax highlighter -->
	<link type="text/css" rel="stylesheet" href="#instance.class.root#highlighter/styles/shCoreEmacs.css">
	<script src="#instance.class.root#highlighter/scripts/shCore.js"></script>
	<script src="#instance.class.root#highlighter/scripts/shBrushBash.js"></script>
	<script src="#instance.class.root#highlighter/scripts/shBrushColdFusion.js"></script>
	<script src="#instance.class.root#highlighter/scripts/shBrushCss.js"></script>
	<script src="#instance.class.root#highlighter/scripts/shBrushJava.js"></script>
	<script src="#instance.class.root#highlighter/scripts/shBrushJScript.js"></script>
	<script src="#instance.class.root#highlighter/scripts/shBrushPlain.js"></script>
	<script src="#instance.class.root#highlighter/scripts/shBrushSql.js"></script>
	<script src="#instance.class.root#highlighter/scripts/shBrushXml.js"></script>
	<script type="text/javascript">
		SyntaxHighlighter.config.stripBrs = true;
		SyntaxHighlighter.defaults.gutter = false;
		SyntaxHighlighter.defaults.toolbar = false;
		SyntaxHighlighter.all();
	</script>
	<style>
	.syntaxhighlighter table td.code { padding: 10px !important; }
	</style>
</head>

<body class="withNavbar">

<cfmodule template="inc/nav.html"
			page="Class"
			projectTitle= "#arguments.projectTitle#"
			package = "#arguments.package#"
			file="#replace(arguments.package, '.', '/', 'all')#/#arguments.name#"
			>

<h1>#arguments.command#</h1>

<cfif structKeyExists( arguments.metadata, 'aliases' ) and len( arguments.metadata.aliases ) >
	<cfset var aliases = listToArray( arguments.metadata.aliases )>
	<div class="panel panel-default">
		<div class="panel-body">
			<strong>Aliases:&nbsp;</strong>
			<cfloop array="#aliases#" index="local.alias">
				<li class="label label-danger label-annotations">
					#local.alias#
				</li>
				&nbsp;
			</cfloop>
		</div>
	</div>
</cfif>

<cfscript>
	// All we care about is the "run()" method
	local.qFunctions = buildFunctionMetaData(arguments.metadata);
	local.qFunctions = getMetaSubQuery(local.qFunctions, "UPPER(name)='RUN'");
</cfscript>

<cfif local.qFunctions.recordCount>
	<cfset local.func = local.qFunctions.metadata>
	<cfset local.params = local.func.parameters>

	<cfif arrayLen( local.params )>
		<div class="panel panel-default">
			<div class="panel-heading"><strong>Parameters:</strong></div>
				<table class="table table-bordered table-hover">
					<tr>
						<td width="1%"><strong>Name</strong></td>
						<td width="1%"><strong>Type</strong></td>
						<td width="1%"><strong>Required</strong></td>
						<td width="1%"><strong>Default</strong></td>
						<td><strong>Hint</strong></td>
					</tr>
					<cfloop array="#local.params#" index="local.param">
						<tr>
							<td>#local.param.name#</td>
							<td>
								<cfif local.param.type eq "any">
									string
								<cfelse>
									#local.param.type#
								</cfif>
							</td>
							<td>#local.param.required#</td>
							<td>
								<cfif !isNull(local.param.default) and local.param.default!= '[runtime expression]' >
									#local.param.default#
								</cfif>
							</td>
							<td>
								<cfif structKeyExists( local.param, 'hint' )>
									#local.param.hint#
								</cfif>
							</td>
						</tr>
					</cfloop>
				</table>
			</div>
		</div>
	</cfif>

</cfif>

<hr>

<cfif StructKeyExists(arguments.metadata, "hint")>
	<h3>Command Usage</h3>
	<div id="class-hint">
		<p>#writeHint( arguments.metadata.hint )#</p>
	</div>
</cfif>

</body>
</html>
</cfoutput>
<cfscript>
	function writeHint( hint ) {

		// Clean up lines with only a period which is my work around for the Railo bug ignoring
		// line breaks in componenet annotations: https://issues.jboss.org/browse/RAILO-3128
		hint = reReplace( hint, '\n\s*\.\s*\n', chr( 10 )&chr( 10 ), 'all' );

		// Find code blocks
		// A {code} block on it's own line with an optional ":brush" inside it
		// followed by any amount of text
		// followed by another {code} block on it's own line
		var codeRegex = '(\n?\s*{\s*code\s*(:.*?)?\s*}\s*\n)(.*?)(\n\s*{\s*code\s*}\s*\n?)';
		hint = reReplaceNoCase( hint, codeRegex, '<pre class="brush\2">\3</pre>', 'all' );

		// Fix line breaks
		hint = reReplace( hint, '\n', '#chr(10)#<br>', 'all' );

		return hint;
	}
</cfscript>