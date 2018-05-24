<!-----------------------------------------------------------------------
********************************************************************************
Copyright 2005-2007 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
www.coldboxframework.com | www.luismajano.com | www.ortussolutions.com
********************************************************************************
@author Brad Wood, Luis Majano, Denny Valliant

ForgeBox API REST Wrapper

Connects to forgebox for operations.  This plugin also uses logbox for debugging
and logging.  You must enable logbox for DEBUG level with the correct class name
if you want to add logging for this category only.

Example:
<Category name="myApp.plugins.ForgeBox" levelMax="DEBUG" />
or just add DEBUG to the root logger
<Root levelMax="DEBUG" />


----------------------------------------------------------------------->
<cfcomponent hint="ForgeBox API REST Wrapper" output="false" accessors="true" singleton>

	<!--- DI --->
	<cfproperty name="progressableDownloader" 	inject="ProgressableDownloader">
	<cfproperty name="progressBar" 				inject="ProgressBar">
	<cfproperty name="CommandBoxlogger" 		inject="logbox:logger:{this}">
	<cfproperty name="configService" 			inject="configService">

	<!--- Properties --->
	<cfproperty name="endpointURL">
	<cfproperty name="apiURL">
	<cfproperty name="installURL">

<!------------------------------------------- CONSTRUCTOR ------------------------------------------>

	<cfscript>
		this.ORDER = {
			POPULAR 	= "popular",
			NEW 		= "new",
			RECENT 		= "recent",
			INSTALLS 	= "installs"
		};
	</cfscript>


	<cffunction name="init" access="public" returnType="ForgeBox" output="false" hint="Constructor">
		<cfscript>

			// Setup Properties
			variables.endpointURL 	= "https://www.forgebox.io";
			variables.APIURL 		= "#variables.endpointURL#/api/v1/";
			variables.installURL 	= "http://www.coldbox.org/forgebox/install/";
			variables.types 		= "";

			return this;
		</cfscript>
	</cffunction>

<!------------------------------------------- PUBLIC ------------------------------------------>

	<!--- getTypes --->
	<cffunction name="getTypes" output="false" access="public" returntype="any" hint="Get an array of entry types">
		<cfargument name="APIToken" type="string" default="">
		<cfscript>
		var results = "";

		// Invoke call
		results = makeRequest(
			resource="types",
			headers = {
				'x-api-token' : arguments.APIToken
			} );

		// error
		if( results.response.error ){
			throw("Error making ForgeBox REST Call", 'forgebox', results.response.messages.toList() );
		}

		return results.response.data;
		</cfscript>
	</cffunction>

	<!--- getTypes --->
	<cffunction name="getCachedTypes" output="false" access="public" returntype="any" hint="Get an array of entry types, locally first else goes and retrieves them">
		<cfargument name="force" type="boolean" default="false">
		<cfargument name="APIToken" type="string" default="">
		<cfscript>
		if( isSimpleValue( variables.types ) OR arguments.force ){
			variables.types = getTypes( APIToken );
		}

		return variables.types;
		</cfscript>
	</cffunction>

	<!--- getEntries --->
	<cffunction name="getEntries" output="false" access="public" returntype="any" hint="Get entries">
		<cfargument name="orderBy"  type="string"  required="false" default="#this.ORDER.POPULAR#" hint="The type to order by, look at this.ORDERBY"/>
		<cfargument name="maxrows"  type="numeric" required="false" default="0" hint="Max rows to return"/>
		<cfargument name="startRow" type="numeric" required="false" default="1" hint="StartRow"/>
		<cfargument name="typeSlug" type="string" required="false" default="" hint="The type slug to filter on"/>
		<cfargument name="searchTerm" type="string" required="false" default="" hint="String to search on"/>
		<cfargument name="APIToken" type="string" default="">
		<cfscript>
			var results = "";
			var params = {
				orderBY = arguments.orderby,
				max = arguments.maxrows,
				offset = arguments.startrow-1,
				typeSlug = arguments.typeSlug,
				searchTerm = arguments.searchTerm
			};

			// Invoke call
			results = makeRequest(
				resource="entries",
				parameters=params,
				headers = {
					'x-api-token' : arguments.APIToken
				});
			// error
			if( results.response.error ){
				throw( "Error making ForgeBox REST Call", 'forgebox', results.response.messages.toList() );
			}

			return results.response.data;
		</cfscript>
	</cffunction>

	<!--- getEntry --->
	<cffunction name="getEntry" output="false" access="public" returntype="struct" hint="Get an entry from forgebox by slug">
		<cfargument name="slug" type="string" required="true" default="" hint="The entry slug to retreive"/>
		<cfargument name="APIToken" type="string" default="">
		<cfscript>
			var results = "";

			// Invoke call
			results = makeRequest(
				resource="entry/#arguments.slug#",
				headers = {
					'x-api-token' : arguments.APIToken
				});

			// error
			if( results.response.error ){
				throw( "Error getting ForgeBox entry [#arguments.slug#]", 'forgebox', results.response.messages.toList() );
			}

			return results.response.data;
		</cfscript>
	</cffunction>

	<!--- isSlugAvailable --->
	<cffunction name="isSlugAvailable" output="false" access="public" returntype="boolean" hint="Verifies if a slug is available">
		<cfargument name="slug" type="string" required="true" default="" hint="The entry slug to verify"/>
		<cfargument name="APIToken" type="string" default="">
		<cfscript>
			var results = "";

			// Invoke call
			results = makeRequest(
				resource="slug-check/#arguments.slug#",
				headers = {
					'x-api-token' : arguments.APIToken
				});

			// error
			if( results.response.error ){
				throw( "Error making ForgeBox REST Call", 'forgebox', results.response.messages.toList() );
			}

			return results.response.data;
		</cfscript>
	</cffunction>

	<cfscript>

	/**
	* Registers a new user in ForgeBox
	*/
	function register(
		required string username,
		required string password,
		required string email,
		required string fName,
		required string lName,
		string APIToken='' ) {

		var results = makeRequest(
			resource="register",
			parameters=arguments,
			method='post',
			headers = {
				'x-api-token' : arguments.APIToken
			} );

		// error
		if( results.response.error ){
			throw( "Sorry, the user could not be added.", 'forgebox', arrayToList( results.response.messages ) );
		}

		return results.response.data;
	}

	/**
	* Look up user based on API Token
	*/
	function whoami( required string APIToken ) {

		var results = makeRequest(
			resource="users/whoami/#APIToken#",
			method='get',
			headers = {
				'x-api-token' : arguments.APIToken
			} );

		// error
		if( results.response.error ){
			throw( arrayToList( results.response.messages ), 'forgebox' );
		}

		return results.response.data;
	}

	/**
	* Authenticates a user in ForgeBox
	*/
	function login(
		required string username,
		required string password ) {

		var results = makeRequest( resource="authenticate", parameters=arguments, method='post' );

		// error
		if( results.response.error ){
			throw( "Sorry, the user could not be logged in.", 'forgebox', arrayToList( results.response.messages ) );
		}

		return results.response.data;
	}

	/**
	* Publishes a package in ForgeBox
	*/
	function publish(
		required string slug,
		required boolean private,
		required string version,
		required string boxJSON,
		required string isStable=true,
		string description='',
		string descriptionFormat='text',
		string installInstructions='',
		string installInstructionsFormat='text',
		string changeLog='',
		string changeLogFormat='text',
		required string APIToken,
		string zipPath = "",
		boolean forceUpload = false
	) {

		var formFields = {
			slug                      = arguments.slug,
			private                   = arguments.private,
			version                   = arguments.version,
			boxJSON                   = arguments.boxJSON,
			isStable                  = arguments.isStable,
			description               = arguments.description,
			descriptionFormat         = arguments.descriptionFormat,
			installInstructions       = arguments.installInstructions,
			installInstructionsFormat = arguments.installInstructionsFormat,
			changeLog                 = arguments.changeLog,
			changeLogFormat           = arguments.changeLogFormat,
			forceUpload               = arguments.forceUpload
		};

		var requestArguments = {
			resource   = "publish",
			headers    = {
				"X-Api-Token"  = arguments.APIToken,
				"Content-Type" = "application/x-www-form-urlencoded"
			},
			formFields = formFields,
			files      = {},
			method     = "post"
		};

		if ( len( arguments.zipPath ) ) {
			requestArguments.files[ "zip" ] = arguments.zipPath;
			requestArguments.multipart = true;
		}

		var results = makeRequest( argumentCollection = requestArguments );

		// error
		if( results.response.error ){
			throw( "Sorry, the package could not be published.", 'forgebox', arrayToList( results.response.messages ) );
		}

		return results.response.data;
	}

	/**
	* Unpublishes a package
	*/
	function unpublish(
		required string slug,
		string version='',
		required string APIToken ) {

		var thisResource = "unpublish/#arguments.slug#";
		if( len( arguments.version ) ) {
			thisResource &= "/#arguments.version#";
		}

		var results = makeRequest( resource=thisResource, method='post', headers={ 'x-api-token' : arguments.APIToken } );

		// error
		if( results.response.error ){
			throw( "Something went wrong unplublishing.", 'forgebox', arrayToList( results.response.messages ) );
		}

		return results.response.data;
	}


	/**
	* Tracks an install
	*/
	function recordInstall(
		required string slug,
		string version='',
		string APIToken='' ) {

		var thisResource = "install/#arguments.slug#";
		if( len( arguments.version ) ) {
			thisResource &= "/#arguments.version#";
		}

		var results = makeRequest(
			resource=thisResource,
			method='post',
			headers = {
				'x-api-token' : arguments.APIToken
			}
		);

		// error
		if( results.response.error ){
			throw( "Something went wrong tracking this installation.", 'forgebox', arrayToList( results.response.messages ) );
		}

		return results.response.data;
	}

	/**
	* Tracks a download
	*/
	function recordDownload(
		required string slug,
		string version,
		string APIToken='' ) {

		var thisResource = "install/#arguments.slug#";
		if( len( arguments.version ) ) {
			thisResource &= "/#arguments.version#";
		}

		var results = makeRequest(
			resource=thisResource,
			method='post',
			headers = {
				'x-api-token' : arguments.APIToken
			} );

		// error
		if( results.response.error ){
			throw( "Something went wrong tracking this download.", 'forgebox', arrayToList( results.response.messages ) );
		}

		return results.response.data;
	}


	/**
	* Autocomplete for slugs
	*/
	function slugSearch(
		required string searchTerm,
		string typeSlug = '',
		string APIToken='' ) {

		var thisResource = "slugs/#arguments.searchTerm#";

		var results = makeRequest(
			resource=thisResource,
			method='get',
			parameters={
				typeSlug : arguments.typeSlug
			},
			headers = {
				'x-api-token' : arguments.APIToken
			} );

		// error
		if( results.response.error ){
			throw( "Error searching for slugs", 'forgebox', arrayToList( results.response.messages ) );
		}

		var opts = results.response.data;

		// If there's only one suggestion and it doesn't have an @ in it, add another suggestion with the @ at the end.
		// This is to prevent the tab completion from adding a space after the suggestion since it thinks it's the only possible option
		// Hitting tab will still populate the line, but won't add the space which makes it easier if the user intends to continue for a specific version.
		if( opts.len() == 1 && !( opts[1] contains '@' ) ) {
			opts.append( opts[1] & '@' );
		}

		return opts;
	}

	function getStorageLocation( required string slug, required string version, required string APIToken ) {
		var results = makeRequest(
			resource = "storage/#slug#/#version#",
			method = "get",
			headers = {
				'x-api-token' : arguments.APIToken
			} );

		// error
		if( results.response.error ){
            throw(
                "Error getting ForgeBox storage location.",
                "forgebox",
                results.response.messages.toList(),
                results.responseheader.status_code ?: 500
            );
		}

		return results.response.data;
	}

	</cfscript>
<!------------------------------------------- PRIVATE ------------------------------------------>

	<!--- makeRequest --->
    <cffunction name="makeRequest" output="false" access="private" returntype="struct" hint="Invoke a ForgeBox REST Call">
    	<cfargument name="method" 			type="string" 	required="false" default="GET" hint="The HTTP method to invoke"/>
		<cfargument name="resource" 		type="string" 	required="false" default="" hint="The resource to hit in the forgebox service."/>
		<cfargument name="body" 			type="any" 		required="false" default="" hint="The body content of the request if passed."/>
		<cfargument name="headers" 			type="struct" 	required="false" default="#structNew()#" hint="An struct of HTTP headers to send"/>
		<cfargument name="parameters"		type="struct" 	required="false" default="#structNew()#" hint="An struct of HTTP URL parameters to send in the request"/>
		<cfargument name="timeout" 			type="numeric" 	required="false" default="20" hint="The default call timeout"/>
		<cfargument name="formFields" 			type="struct" 	required="false" default="#structNew()#" hint="A struct of form fields to send"/>
		<cfargument name="files" 			type="struct" 	required="false" default="#structNew()#" hint="A struct of files to send"/>
		<cfargument name="multipart" 			type="boolean" 	required="false" default="false" hint="Whether the request needs to be multipart/form-data"/>
		<cfscript>
			var results = {error=false,response={},message="",responseheader={},rawResponse=""};
			var HTTPResults = "";
			var param = "";
			var APIURL = configService.getSetting( 'endpoints.forgebox.APIURL', getAPIURL() );
			if( APIURL.endsWith( '/' ) ) {
				APIURL = left( APIURL, len( APIURL )-1 );
			}

			// Default Content Type
			if( NOT structKeyExists(arguments.headers,"content-type") ){
				arguments.headers[ "Content-Type" ] = "";
			}
			if( arguments.multipart ){
				structDelete( arguments.headers, "Content-Type" );
			}

			var thisURL = '#APIURL#/#arguments.resource#';

			var CFHTTPParams = {
				method=arguments.method,
				url=thisURL,
				charset='utf-8',
				result='HTTPResults',
				timeout=arguments.timeout,
				multipart=arguments.multipart
			};

			// Get proxy settings from the config
			var proxyServer=ConfigService.getSetting( 'proxy.server', '' );
			var proxyPort=ConfigService.getSetting( 'proxy.port', '' );
			var proxyUser=ConfigService.getSetting( 'proxy.user', '' );
			var proxyPassword=ConfigService.getSetting( 'proxy.password', '' );

			if( len( proxyServer ) ) {
				CFHTTPParams.proxyServer = proxyServer;

				if( len( proxyPort ) ) {
					CFHTTPParams.proxyPort = proxyPort;
				}
				if( len( proxyUser ) ) {
					CFHTTPParams.proxyUser = proxyUser;
				}
				if( len( proxyPassword ) ) {
					CFHTTPParams.proxyPassword = proxyPassword;
				}
			}
			// structDelete( arguments.headers, "Content-Type" );
		</cfscript>

		<!--- REST CAll --->
		<cfhttp attributeCollection="#CFHTTPParams#">

			<!--- Headers --->
			<cfloop collection="#arguments.headers#" item="param">
				<cfhttpparam type="header" name="#param#" value="#arguments.headers[param]#" >
			</cfloop>

			<!--- URL Parameters: encoded automatically by CF --->
			<cfloop collection="#arguments.parameters#" item="param">
				<cfhttpparam type="URL" name="#param#" value="#arguments.parameters[param]#" >
			</cfloop>

			<cfloop collection="#arguments.formFields#" item="field">
				<cfhttpparam type="formfield" name="#field#" value="#arguments.formFields[field]#" />
			</cfloop>

			<cfloop collection="#arguments.files#" item="file">
				<cfhttpparam type="file" name="#file#" file="#arguments.files[file]#" />
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

            if (isJSON(results.rawResponse)) {
                results.response = deserializeJSON(results.rawResponse,false);
            } else {
            	var errorDetail = ( HTTPResults.errorDetail ?: '' );
            	var statusMessage = ( HTTPResults.statuscode ?: HTTPResults.status_code ?: '' );
            	// Only append the status message if it's different than the errorDetail
            	if( errorDetail != statusMessage ) {
            		errorDetail &= chr( 10 ) & statusMessage;
            	}
            	errorDetail = ucase( arguments.method ) & ' ' &thisURL & chr( 10 ) & errorDetail;
            	CommandBoxlogger.error( 'Something other than JSON returned. #errorDetail#', 'Actual HTTP Response: ' & results.rawResponse );
				throw( 'Uh-oh, ForgeBox returned something other than JSON.  Run "system-log | open" to see the full response.', 'forgebox', errorDetail );
            }

			return results;
		</cfscript>
	</cffunction>

</cfcomponent>
