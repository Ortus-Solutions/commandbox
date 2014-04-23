<cfparam name="URL.output" default="html">
<cfparam name="url.quiet" default="false">
<cfparam name="url.email" default="false">
<cfparam name="url.recipients" default="????@????.com">
<!--- change this! --->
<cfset dir = expandPath(".") />
<cfoutput><h1>
		#dir# 
	</h1></cfoutput>
<cfset DTS = createObject("component","mxunit.runner.DirectoryTestSuite") />
<cfset excludes = "" />
<cfinvoke component="#DTS#" 
	method="run"
	directory="#dir#" 
	recurse="true" 
	excludes="#excludes#"
	returnvariable="Results"
	componentpath="tests">
<!---  [WEE]<-- Fill this in! This is the root component path for your tests. if your tests are at {webroot}/app1/test, then your componentpath will be app1.test   --->
<cfsetting showdebugoutput="true">
<cfoutput>
	<cfsavecontent variable="recenthtml">
		<cfif NOT StructIsEmpty(DTS.getCatastrophicErrors())>
			<cfdump var="#DTS.getCatastrophicErrors()#" expand="false" label="#StructCount(DTS.getCatastrophicErrors())# Catastrophic Errors" />
		</cfif>
		#results.getResultsOutput(URL.output)# 
	</cfsavecontent>
</cfoutput>
<cfif NOT url.quiet>
	<cfoutput>#recenthtml#</cfoutput>
</cfif>
<cfif url.email>
	<!--- change this 'from' email! --->
	<cfmail from="????@????.com" to="#url.recipients#" subject="Test Results : #DateFormat(now(),'short')# @ #TimeFormat(now(),'short')#" type="html">
		#recenthtml# 
	</cfmail>
</cfif>
<cftry>
	<cfdirectory action="create" directory="#expandPath("/tests/")#/results">
	<cfcatch></cfcatch>
</cftry>
<cffile action="write" file="#expandPath("/tests/")#/results/#DateFormat(now(),'mm-dd-yyyy')#_#TimeFormat(now(),'hhmmss')#-results.html" output="#recenthtml#">
