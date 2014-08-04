<cfoutput>
<cfset assetPath = repeatstring( '../', listlen( arguments.package, "." ) )>
<!DOCTYPE html>
<html lang="en">
<head>
	<title>	#arguments.namespace# </title>
	<meta name="keywords" content="#arguments.namespace# namespace">
	<cfmodule template="inc/common.html" rootPath="#assetPath#">
</head>
<body class="withNavbar">

	<cfmodule template="inc/nav.html"
				page="Package"
				projectTitle= "#arguments.projectTitle#"
				package = "#arguments.package#"
				file="#replace(arguments.package, '.', '/', 'all')#/package-summary"
				>
	<h2>
	<span class="label label-success">#arguments.namespace#</span>
	</h2>
	
	<div class="table-responsive">
	<cfif arguments.qClasses.recordCount>
		<table class="table table-striped table-hover table-bordered">
			<thead>
				<tr class="info">
					<th align="left" colspan="2"><font size="+2">
					<b>Commands</b></font></th>
				</tr>
			</thead>
	
			<cfloop query="arguments.qclasses">
				<tr>
					<td width="15%" nowrap=true><b><a href="#name#.html" title="Command in #package#">#command#</a></b></td>
					<td>
						<cfset meta = metadata>
						<cfif structkeyexists(meta, "hint") and len(meta.hint) gt 0>
							#listgetat( meta.hint, 1, chr(13)&chr(10)&'.' )#
						</cfif>
					</td>
				</tr>
			</cfloop>
	
		</table>
	</cfif>
	</div>

</body>
</html>
</cfoutput>