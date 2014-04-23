<cfcomponent displayname="woohoo"  extends="mxunit.framework.TestCase">
<cfsetting requesttimeout="333" />
	<cfimport taglib="/cfml/box/namespace/cfdistro/home/tag" prefix="ar" />

  <cffunction name="setUp" returntype="void" access="public">
		<cfset request.adminType = "web" />
  </cffunction>

  <cffunction name="tearDown" returntype="void" access="public">
  </cffunction>

	<cffunction name="dumpvar" access="private">
		<cfargument name="var">
		<cfdump var="#var#">
		<cfabort/>
	</cffunction>

	<cffunction name="testAnt">
		<cfscript>
			attributes.generatedContent = '<dependency groupId="org.mxunit" artifactId="core" version="2.1.3" mapping="/mxunit" />';
			attributes.antfile = "";
			var antresults = new cfml.box.namespace.cfdistro.home.tag.cfc.Ant().run(argumentCollection=attributes);
		</cfscript>
	</cffunction>

	<cffunction name="testGetTargets">
		<cfset properties = {"mxunit.haltonerror"="false"} />
		<ar:cfdistro antfile="#expandPath('/tests/')#/../build/build.xml" resultsVar="results" action="getTargets" properties="#properties#" />
		<cfset debug(results)>
		<cfset assertTrue(results.recordcount)>
	</cffunction>

</cfcomponent>