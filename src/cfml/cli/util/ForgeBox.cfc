<!-----------------------------------------------------------------------
********************************************************************************
Copyright 2005-2007 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldboxframework.com | www.luismajano.com | www.ortussolutions.com
********************************************************************************

ForgeBox API REST Wrapper

Connects to forgebox for operations.  This plugin also uses logbox for debugging
and logging.  You must enable logbox for DEBUG level with the correct class name
if you want to add logging for this category only.

Example:
<Category name="myApp.plugins.ForgeBox" levelMax="DEBUG" />
or just add DEBUG to the root logger
<Root levelMax="DEBUG" />


Settings:

----------------------------------------------------------------------->
<cfcomponent hint="ForgeBox API REST Wrapper" output="false">

<!------------------------------------------- CONSTRUCTOR ------------------------------------------>
	
	<cfscript>
		this.ORDER = {
			POPULAR = "popular",
			NEW = "new",
			RECENT = "recent"
		};
	</cfscript>


	<cffunction name="init" access="public" returnType="ForgeBox" output="false" hint="Constructor">
		<cfscript>
			
			// Setup Properties
			instance.APIURL = "http://www.coldbox.org/index.cfm/api/forgebox";
			
			return this;
		</cfscript>
	</cffunction>
	
	<!--- Get/set API URL --->
	<cffunction name="getAPIURL" access="public" returntype="string" output="false" hint="Get the API URL endpoint">
		<cfreturn instance.APIURL>
	</cffunction>
	<cffunction name="setAPIURL" access="public" returntype="void" output="false" hint="Set the API URL endpoint">
		<cfargument name="APIURL" type="string" required="true">
		<cfset instance.APIURL = arguments.APIURL>
	</cffunction>
	
<!------------------------------------------- PUBLIC ------------------------------------------>
	
	<!--- getTypes --->
	<cffunction name="getTypes" output="false" access="public" returntype="query" hint="Get an array of entry types">
		<cfscript>
		var results = "";
		
		// Invoke call
		results = makeRequest(resource="types");
		
		// error 
		if( results.error ){
			$throw("Error making ForgeBox REST Call",results.message);
		}
		
		return results.response.data;				
		</cfscript>	
	</cffunction>
	
	<!--- getEntries --->
	<cffunction name="getEntries" output="false" access="public" returntype="query" hint="Get entries">
		<cfargument name="orderBy"  type="string"  required="false" default="#this.ORDER.POPULAR#" hint="The type to order by, look at this.ORDERBY"/>
		<cfargument name="maxrows"  type="numeric" required="false" default="0" hint="Max rows to return"/>
		<cfargument name="startRow" type="numeric" required="false" default="1" hint="StartRow"/>
		<cfargument name="typeSlug" type="string" required="false" default="" hint="The tye slug to filter on"/>
		<cfscript>
			var results = "";
			var params = {
				orderBY = arguments.orderby,
				maxrows = arguments.maxrows,
				startrow = arguments.startrow,
				typeSlug = arguments.typeSlug	
			};
			
			// Invoke call
			results = makeRequest(resource="entries",parameters=params);
			
			// error 
			if( results.error ){
				$throw("Error making ForgeBox REST Call",results.message);
			}
			
			return results.response.data;				
		</cfscript>	
	</cffunction>
	
	<!--- getEntry --->
	<cffunction name="getEntry" output="false" access="public" returntype="struct" hint="Get an entry from forgebox by slug">
		<cfargument name="slug" type="string" required="true" default="" hint="The entry slug to retreive"/>
		<cfscript>
			var results = "";
			
			// Invoke call
			results = makeRequest(resource="entry/#arguments.slug#");
			
			// error 
			if( results.error ){
				$throw("Error making ForgeBox REST Call",results.message);
			}
			
			return results.response.data;				
		</cfscript>	
	</cffunction>
	
	<!--- install --->
	<cffunction name="install" output="false" access="public" returntype="struct" hint="Install Code Entry">
		<cfargument name="downloadURL"    type="string" required="true" />
		<cfargument name="destinationDir" type="string" required="true" />
		
		<!--- Start Log --->
		<cfset var log 			= createObject("java","java.lang.StringBuffer").init("Starting Download...<br />")>
		<cfset var destination  = arguments.destinationDir>
		<cfset var fileName		= getFileFromPath(arguments.downloadURL)>
		<cfset var results 		= {error=true,logInfo=""}>
		
		<cftry>
			<!--- Download File --->
			<cfhttp url="#arguments.downloadURL#"
					method="GET"
					file="#fileName#"
					path="#destination#">
		
			<cfcatch type="any">
				<cfset log.append("<strong>Error downloading file: #cfcatch.message# #cfcatch.detail#</strong><br />")>
				<cfset results.logInfo = log.toString()>
				<cfreturn results>
			</cfcatch>
		</cftry>	
		
		<!--- has file size? --->
		<cfif getFileInfo(destination & "/" & fileName).size LTE 0>	
			<cfset log.append("<strong>Cannot install file as it has a file size of 0.</strong>")>
			<cfset results.logInfo = log.toString()>
			<cfreturn results>
		</cfif>
		
		<cfset log.append("File #fileName# downloaded succesfully at #destination#, checking type for extraction.<br />")>
		
		<!--- Unzip File? --->
		<cfif listLast(filename,".") eq "zip">
			<cfset log.append("Zip archive detected, beginning to uncompress.<br />")>
			<cfzip action="unzip" file="#destination#/#filename#" destination="#destination#" overwrite="true">
			<cfset log.append("Archive uncompressed and installed at #destination#. Performing cleanup.<br />")>
			<cfset fileDelete(destination & "/" & filename)>
		</cfif>
		
		<cfset log.append("Entry: #filename# sucessfully installed at #destination#.<br />")>
		<cfset results = {error=false,logInfo=log.toString()}>
		
		<cfreturn results>		
	</cffunction>	
	
<!------------------------------------------- PRIVATE ------------------------------------------>

	<!--- S3Request --->
    <cffunction name="makeRequest" output="false" access="private" returntype="struct" hint="Invoke a ForgeBox REST Call">
    	<cfargument name="method" 			type="string" 	required="false" default="GET" hint="The HTTP method to invoke"/>
		<cfargument name="resource" 		type="string" 	required="false" default="" hint="The resource to hit in the forgebox service."/>
		<cfargument name="body" 			type="any" 		required="false" default="" hint="The body content of the request if passed."/>
		<cfargument name="headers" 			type="struct" 	required="false" default="#structNew()#" hint="An struct of HTTP headers to send"/>
		<cfargument name="parameters"		type="struct" 	required="false" default="#structNew()#" hint="An struct of HTTP URL parameters to send in the request"/>
		<cfargument name="timeout" 			type="numeric" 	required="false" default="20" hint="The default call timeout"/>
		<cfscript>
			var results = {error=false,response={},message="",responseheader={},rawResponse=""};
			var HTTPResults = "";
			var param = "";
			var jsonRegex = "^(\{|\[)(.)*(\}|\])$";
			
			// Default Content Type
			if( NOT structKeyExists(arguments.headers,"content-type") ){
				arguments.headers["content-type"] = "";
			}
		</cfscript>
		
		<!--- REST CAll --->
		<cfhttp method="#arguments.method#" 
				url="#getAPIURL()#/json/#arguments.resource#" 
				charset="utf-8" 
				result="HTTPResults" 
				timeout="#arguments.timeout#">
			
			<!--- Headers --->
			<cfloop collection="#arguments.headers#" item="param">
				<cfhttpparam type="header" name="#param#" value="#arguments.headers[param]#" >
			</cfloop>	
			
			<!--- URL Parameters: encoded automatically by CF --->
			<cfloop collection="#arguments.parameters#" item="param">
				<cfhttpparam type="URL" name="#param#" value="#arguments.parameters[param]#" >
			</cfloop>	
			
			<!--- Body --->
			<cfif len(arguments.body) >
				<cfhttpparam type="body" value="#arguments.body#" >
			</cfif>	
		</cfhttp>
		
		<cfscript>
			// Log
			//log.debug("ForgeBox Rest Call ->Arguments: #arguments.toString()#",HTTPResults);
			
			// Set Results
			results.responseHeader 	= HTTPResults.responseHeader;
			results.rawResponse 	= HTTPResults.fileContent.toString();
			
			// Error Details found?
			results.message = HTTPResults.errorDetail;
			if( len(HTTPResults.errorDetail) ){ results.error = true; }
			// Try to inflate JSON
			results.response = deserializeJSON(results.rawResponse,false);
			
			return results;
		</cfscript>	
	</cffunction>
	
	<!--- Throw Facade --->
	<cffunction name="$throw" access="public" hint="Facade for cfthrow" output="false">
		<!--- ************************************************************* --->
		<cfargument name="message" 	type="string" 	required="yes">
		<cfargument name="detail" 	type="string" 	required="no" default="">
		<cfargument name="type"  	type="string" 	required="no" default="Framework">
		<!--- ************************************************************* --->
		<cfthrow type="#arguments.type#" message="#arguments.message#"  detail="#arguments.detail#">
	</cffunction>
	
	<!--- Dump facade --->
	<cffunction name="$dump" access="public" hint="Facade for cfmx dump" returntype="void">
		<cfargument name="var" required="yes" type="any">
		<cfargument name="isAbort" type="boolean" default="false" required="false" hint="Abort also"/>
		<cfdump var="#var#">
		<cfif arguments.isAbort><cfabort></cfif>
	</cffunction>
	
	<!--- Abort Facade --->
	<cffunction name="$abort" access="public" hint="Facade for cfabort" returntype="void" output="false">
		<cfabort>
	</cffunction>
	
</cfcomponent>