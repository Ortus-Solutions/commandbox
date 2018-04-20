/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
*
*
*/
component accessors="true" singleton="true" {

	// DI
	property name='tempDir'				inject='tempDir@constants';
	property name='packageService'		inject='PackageService';
	property name='endpointService'		inject='EndpointService';
	property name='logger'				inject='logbox:logger:{this}';
	property name='cr'					inject='cr@constants';
	property name='shell'				inject='shell';
	property name="semanticVersion"		inject="provider:semanticVersion@semver";
	property name="artifactService"		inject="artifactService";
	property name="wirebox"				inject="wirebox";


	/**
	* install the server if not already installed to the target directory
	*
	* @cfengine	CFML Engine name (lucee, adobe, railo)
	* @baseDirectory base directory for server install
	* @serverInfo The struct of server settings
	* @serverHomeDirectory Override where the server's home with be
	**/
	public function install( required cfengine, required baseDirectory, required struct serverInfo, required string serverHomeDirectory ) {
		var version = listLen( cfengine, "@" )>1 ? listLast( cfengine, "@" ) : "stable";
		var engineName = listFirst( cfengine, "@" );
		arguments.baseDirectory = !arguments.baseDirectory.endsWith( "/" ) ? arguments.baseDirectory & "/" : arguments.baseDirectory;

		if( engineName == "adobe" ) {
			return installAdobe( destination=arguments.baseDirectory, version=version, serverInfo=serverInfo, serverHomeDirectory=serverHomeDirectory );
		} else if (engineName == "railo") {
			return installRailo( destination=arguments.baseDirectory, version=version, serverInfo=serverInfo, serverHomeDirectory=serverHomeDirectory );
		} else if (engineName == "lucee") {
			return installLucee( destination=arguments.baseDirectory, version=version, serverInfo=serverInfo, serverHomeDirectory=serverHomeDirectory );
		} else {
			return installEngineArchive( cfengine, arguments.baseDirectory, serverInfo, serverHomeDirectory );
		}
	}

	/**
	* install adobe
	*
	* @destination target directory
	* @version Version number or empty to use default
	* @serverInfo Struct of server settings
	* @serverHomeDirectory Override where the server's home with be
	**/
	public function installAdobe( required destination, required version, required struct serverInfo, required string serverHomeDirectory ) {
		var installDetails = installEngineArchive( 'adobe@#version#', destination, serverInfo, serverHomeDirectory );

		return installDetails;
	}

	/**
	* install lucee
	*
	* @destination target directory
	* @version Version number or empty to use default
	* @serverInfo struct of server settings
	* @serverHomeDirectory Override where the server's home with be
	**/
	public function installLucee( required destination, required version, required struct serverInfo, required string serverHomeDirectory ) {
		var installDetails = installEngineArchive( 'lucee@#version#', destination, serverInfo, serverHomeDirectory );

		if( installDetails.initialInstall ) {
			configureWebXML( cfengine="lucee", version=installDetails.version, source=serverInfo.webXML, destination=serverInfo.webXML, serverInfo=serverInfo );
		}
		return installDetails;
	}

	/**
	* install railo
	*
	* @destination target directory
	* @version Version number or empty to use default
	* @serverInfo struct of server settings
	* @serverHomeDirectory Override where the server's home with be
	**/
	public function installRailo( required destination, required version, required struct serverInfo, required string serverHomeDirectory ) {
	var installDetails = installEngineArchive( 'railo@#version#', destination, serverInfo, serverHomeDirectory );

		if(  installDetails.initialInstall  ) {
			configureWebXML( cfengine="railo", version=installDetails.version, source=serverInfo.webXML, destination=serverInfo.webXML, serverInfo=serverInfo );
		}
		return installDetails;
	}

	/*
	* Downloads a CF engine endpoint and unzips the "Engine.[WAR|zip] archive into the destination
	* The WAR will be placed in a folder named {cfengine}-{version}/ unless an installDir is supplied.
	*
	* @ID The endpoint ID to use for the CF Engine.
	* @destination The folder where this site's servers are stored.
	*/
	function installEngineArchive(
		required string ID,
		required string destination,
		required struct serverInfo,
		required string serverHomeDirectory
		) {

		var job = wirebox.getInstance( 'interactiveJob' );
		
		var installDetails = {
			engineName : '',
			version : '',
			installDir : '',
			initialInstall : false
		};

		var thisTempDir = tempDir & '/' & createUUID();

		// Find out what endpoint will service them and ask the endpoint what their name is.
		var endpointData = endpointService.resolveEndpoint( ID, shell.pwd() );
		var endpoint = endpointData.endpoint;
		var engineName = endpoint.getDefaultName( arguments.ID );
		installDetails.engineName = engineName;

		// In order to prevent uneccessary work, we're going to try REALLY hard to figure out exactly what engine will be installed
		// before it actually happens so we can skip this whole mess if it's already in place.
		// if our endpoint is ForgeBox, figure out what version it is going to install.
		if( endpointData.endpointName == 'forgebox' ) {
			var version = endpoint.parseVersion( arguments.ID );

			// If the user gave us an exact version, just use it!
			// Require buildID like 5.1.0+34
			if( semanticVersion.isExactVersion( version=version, includeBuildID=true ) ) {
				var satisfyingVersion = version;
			} else {
				job.addWarnLog( "Contacting ForgeBox to determine the latest & greatest version of [#engineName##( len( version ) ? ' ' : '' )##version#]...  Use an exact 'cfengine' version to skip this check.");
				// If ForgeBox is down, don't rain on people's parade.
				try {
					var satisfyingVersion = endpoint.findSatisfyingVersion( endpoint.parseSlug( arguments.ID ), version ).version;
					job.addLog( "OK, [#engineName# #satisfyingVersion#] it is!");
				} catch( any var e ) {

					job.addErrorLog( "Aww man,  ForgeBox isn't feeling well.");
					job.addLog( "#e.message#  #e.detail#");
					job.addErrorLog( "We're going to look in your local artifacts cache and see if one of those versions will work.");

					// See if there's something usable in the artifacts cache.  If so, we'll use that version.
					var satisfyingVersion = artifactService.findSatisfyingVersion( endpoint.parseSlug( arguments.ID ), version );
					if( len( satisfyingVersion ) ) {
						arguments.ID = endpoint.parseSlug( arguments.ID ) & '@' & satisfyingVersion;
						job.addLog( "Sweet! We found a local version of [#satisfyingVersion#] that we can use in your artifacts.");
					} else {
						throw( 'No satisfying version found for [#version#].', 'endpointException', 'Well, we tried as hard as we can.  ForgeBox is unreachable and you don''t have a usable version in your local artifacts cache.  Please try another version.' );
					}
				}
			}
			// Overriding server home which is where the exploded war lives
			if( len( arguments.serverHomeDirectory ) ) {
				installDetails.installDir = arguments.serverHomeDirectory;
			// Default is engine-version folder in base dir
			} else {
				installDetails.installDir = destination & engineName & "-" & replace( satisfyingVersion, '+', '.', 'all' );
			}
			installDetails.version = satisfyingVersion;

			var thisEngineTag = installDetails.engineName & '@' & installDetails.version;

		} else {

			// For all other endpoints, create a predictable folder based on the endpoint ID.
			// If the file that the endpoint points to changes, you'll have to forget the server to pick up changes.
			// The alternative is re-downloading the engine EVERY. SINGLE. TIME.
			// Overriding server home which is where the exploded war lives
			if( len( arguments.serverHomeDirectory ) ) {
				installDetails.installDir = arguments.serverHomeDirectory;
			// Default is engine-version folder in base dir
			} else {
				installDetails.installDir = destination & engineName;
			}

			var thisEngineTag = arguments.ID;

		}

		// Set default web.xml path now that we have an install dir
		if( !len( serverInfo.webXML ) ) {
			serverInfo.webXML = "#installDetails.installDir#/WEB-INF/web.xml";
		}
		// Set up server and web context dirs if Railo or Lucee
		if( serverinfo.cfengine contains 'lucee' || serverinfo.cfengine contains 'railo' ) {
			// Default web context
			if( !len( serverInfo.webConfigDir ) ) {
				serverInfo.webConfigDir = "/WEB-INF/#lcase( listFirst( serverinfo.cfengine, "@" ) )#-web";
			}
			// Default server context
			if( !len( serverInfo.serverConfigDir ) ) {
				serverInfo.serverConfigDir = "/WEB-INF";
			}
			// Make relative to WEB-INF if possible
			serverInfo.webConfigDir = replace( serverInfo.webConfigDir, '\', '/', 'all' );
			serverInfo.serverConfigDir = replace( serverInfo.serverConfigDir, '\', '/', 'all' );
			installDetails.installDir = replace( installDetails.installDir, '\', '/', 'all' );

			serverInfo.webConfigDir = replace( serverInfo.webConfigDir, installDetails.installDir, '' );
			serverInfo.serverConfigDir = replace( serverInfo.serverConfigDir, installDetails.installDir, '' );
		}

		var engineTagFile = installDetails.installDir & '/.engineInstall';

		// Check to see if this WAR has already been exploded
		if( fileExists( engineTagFile ) ) {

			// Check and see if another version of this engine has already been started in the server home.
			var previousEngineTag = fileRead( engineTagFile );
			if( previousEngineTag != thisEngineTag ) {
				job.addWarnLog( "You've asked for the engine [#thisEngineTag#] to be started," );
				job.addWarnLog( "but this server home already has [#previousEngineTag#] deployed to it!" );
				job.addWarnLog( "In order to get the new version, you need to run 'server forget' on this server and start it again." );
			}

			job.addLog( "WAR/zip archive already installed.");

			return installDetails;
		}

		// Install the engine via our standard package service
		installDetails.initialInstall = true;

		// If we're starting a Lucee server whose version matches the CLI engine, then don't download anything, we're using internal jars.
		if( listFirst( arguments.ID, '@' ) == 'lucee' && server.lucee.version == replace( installDetails.version, '+', '.', 'all' ) ) {

			job.addLog( "Building a WAR from local jars.");

			// Spoof a WAR file.
			var thisWebinf = installDetails.installDir & '/WEB-INF';
			var thislib = thisWebinf & '/lib';
			var thiServerContext = thisWebinf & '/server-context';
			var thiWebContext = thisWebinf & '/web-context';

			directoryCreate( installDetails.installDir & '/WEB-INF', true, true );
			directoryCopy( '/commandbox-home/lib', thislib, false, '*.jar' );
			fileCopy( expandPath( '/commandbox/system/config/web.xml' ), thisWebinf & '/web.xml');

			// Mark this WAR as being exploded already
			fileWrite( engineTagFile, thisEngineTag );

			return installDetails;
		}

		if( !packageService.installPackage( ID=arguments.ID, directory=thisTempDir, save=false ) ) {
			throw( message='Server not installed.', type="commandException");
		}

		// Look for a war or zip archive inside the package
		var theArchive = '';
		for( var thisFile in directoryList( thisTempDir ) ) {
			if( listFindNoCase( 'war,zip', listLast( thisFile, '.' ) ) ) {
				theArchive = thisFile;
				break;
			}
		}

		// If there's no archive, we don't know what to do!
		if( theArchive == '' ) {
			throw( "Package didn't contain a war or zip archive." );
		}

		job.addLog( "Exploding WAR/zip archive...");
		directoryCreate( installDetails.installDir, true, true );
		zip action="unzip" file="#theArchive#" destination="#installDetails.installDir#" overwrite="false";

		// Mark this WAR as being exploded already
		fileWrite( engineTagFile, thisEngineTag );

		// Catch this to gracefully handle where the OS or another program
		// has the folder locked.
		try {
			directoryDelete( thisTempDir, true );
		} catch( any e ) {
			job.adderrorLog( e.message );
			job.adderrorLog( 'The folder is possibly locked by another program.' );
			logger.error( '#e.message# #e.detail#' , e.stackTrace );
		}
		return installDetails;
	}

	/**
	* configure web.xml file for Lucee and Railo
	*
	* @cfengine lucee or railo
	* @source source web.xml
	* @destination target web.xml
	**/
	public function configureWebXML( required cfengine, required version, required source, required destination, required struct serverInfo ) {
		var webXML = XMLParse( source );
		var servlets = xmlSearch(webXML,"//:servlet-class[text()='#lcase( cfengine )#.loader.servlet.CFMLServlet']");
		var initParam = xmlElemnew(webXML,"http://java.sun.com/xml/ns/javaee","init-param");
		initParam.XmlChildren[1] = xmlElemnew(webXML,"param-name");
		initParam.XmlChildren[1].XmlText = "#lcase( cfengine )#-web-directory";
		initParam.XmlChildren[2] = xmlElemnew(webXML,"param-value");
		initParam.XmlChildren[2].XmlText = serverInfo.webConfigDir;
		arrayInsertAt(servlets[1].XmlParent.XmlChildren,4,initParam);

		var servlets = xmlSearch(webXML,"//:servlet-class[text()='#lcase( cfengine )#.loader.servlet.CFMLServlet']");
		var initParam = xmlElemnew(webXML,"http://java.sun.com/xml/ns/javaee","init-param");
		initParam.XmlChildren[1] = xmlElemnew(webXML,"param-name");
		initParam.XmlChildren[1].XmlText = "#lcase( cfengine )#-server-directory";
		initParam.XmlChildren[2] = xmlElemnew(webXML,"param-value");
		initParam.XmlChildren[2].XmlText = serverInfo.serverConfigDir;
		arrayInsertAt(servlets[1].XmlParent.XmlChildren,4,initParam);

		// Lucee 5+ has a LuceeServlet as well as will create the WEB-INF by default in your web root
		if( arguments.cfengine == 'lucee' && val( listFirst( arguments.version, '.' )) >= 5 ) {
			var servlets = xmlSearch(webXML,"//:servlet-class[text()='#lcase( cfengine )#.loader.servlet.LuceeServlet']");
			var initParam = xmlElemnew(webXML,"http://java.sun.com/xml/ns/javaee","init-param");
			initParam.XmlChildren[1] = xmlElemnew(webXML,"param-name");
			initParam.XmlChildren[1].XmlText = "#lcase( cfengine )#-web-directory";
			initParam.XmlChildren[2] = xmlElemnew(webXML,"param-value");
			initParam.XmlChildren[2].XmlText = serverInfo.webConfigDir;
			arrayInsertAt(servlets[1].XmlParent.XmlChildren,4,initParam);

			var servlets = xmlSearch(webXML,"//:servlet-class[text()='#lcase( cfengine )#.loader.servlet.LuceeServlet']");
			var initParam = xmlElemnew(webXML,"http://java.sun.com/xml/ns/javaee","init-param");
			initParam.XmlChildren[1] = xmlElemnew(webXML,"param-name");
			initParam.XmlChildren[1].XmlText = "#lcase( cfengine )#-server-directory";
			initParam.XmlChildren[2] = xmlElemnew(webXML,"param-value");
			initParam.XmlChildren[2].XmlText = serverInfo.serverConfigDir;
			arrayInsertAt(servlets[1].XmlParent.XmlChildren,4,initParam);
		}

		var xlt = '<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
		<xsl:output method="xml" encoding="utf-8" indent="yes" xslt:indent-amount="2" xmlns:xslt="http://xml.apache.org/xslt" />
		<xsl:strip-space elements="*"/>
		<xsl:template match="node() | @*"><xsl:copy><xsl:apply-templates select="node() | @*" /></xsl:copy></xsl:template>
		</xsl:stylesheet>';
		fileWrite( destination, toString( XmlTransform( webXML, xlt) ) );
		return true;
	}

}
