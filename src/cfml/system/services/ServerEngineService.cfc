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
	property name='consoleLogger'		inject='logbox:logger:console';
	property name='cr'					inject='cr@constants';
	property name='shell'				inject='shell';
	property name="semanticVersion"		inject="semanticVersion";
	property name="artifactService"		inject="artifactService";

	
	/**
	* install the server if not already installed to the target directory
	* 
	* @cfengine	CFML Engine name (lucee, adobe, railo)
	* @baseDirectory base directory for server install
	**/
	public function install( required cfengine, required baseDirectory ) {
		var version = listLen( cfengine, "@" )>1 ? listLast( cfengine, "@" ) : "";
		var engineName = listFirst(cfengine,"@");
		arguments.baseDirectory = !arguments.baseDirectory.endsWith( "/" ) ? arguments.baseDirectory & "/" : arguments.baseDirectory;
				
		if( engineName == "adobe" ) {
			return installAdobe( destination=arguments.baseDirectory, version=version );
		} else if (engineName == "railo") {
			return installRailo( destination=arguments.baseDirectory, version=version );
		} else if (engineName == "lucee") {
			return installLucee( destination=arguments.baseDirectory, version=version );
		} else {
			return installEngineArchive( cfengine, arguments.baseDirectory );
		}
	}

	/**
	* install adobe
	* 
	* @destination target directory
	* @version Version number or empty to use default
	**/
	public function installAdobe( required destination, required version ) {
		var installDetails = installEngineArchive( 'adobe@#version#', destination );	

		// set password to "commandbox"
		// TODO: Just make this changes directly in the WAR files
		fileWrite( installDetails.installDir & "/WEB-INF/cfusion/lib/password.properties", "rdspassword=#cr#password=commandbox#cr#encrypted=false" );
		// set flex log dir to prevent WEB-INF/cfform being created in project dir
		if (fileExists(installDetails.installDir & "/WEB-INF/cfform/flex-config.xml")) {
			var flexConfig = fileRead(installDetails.installDir & "/WEB-INF/cfform/flex-config.xml");

			if(!installDetails.internal && installDetails.initialInstall ) {
				flexConfig = replace(flexConfig, "/WEB-INF/", installDetails.installDir & "/WEB-INF/","all");
 -				fileWrite(installDetails.installDir & "/WEB-INF/cfform/flex-config.xml", flexConfig);
			} else { 
				// TODO: Remove this ELSE block in a future revision. 
				// This will fix the flex-config.xml files that have been corrupted because we weren't checking initialInstall, above.  
				var escapedInstDir=reReplace(installDetails.installDir,"(\\|\/|\.|\:)","\\1","all");
				//reReplace supports 5 backreferences in the replacement substring for case conversions. It doesn't allow escaping of these backreferences though in case you want them literally! 
				var replaceString=reReplace(installDetails.installDir,"\\(u|U|l|L|E)","##chr(92)##\1","all");
				var regex="(?:" & escapedInstDir & ")*" & "\/WEB-INF\/" ;
				flexConfig = reReplace(flexConfig, regex, replaceString & "/WEB-INF/","all");
				fileWrite(installDetails.installDir & "/WEB-INF/cfform/flex-config.xml", evaluate(de(flexConfig)));
			}
		}
		return installDetails;
	}

	/**
	* install lucee
	* 
	* @destination target directory
	* @version Version number or empty to use default
	**/
	public function installLucee( required destination, required version ) {
	var installDetails = installEngineArchive( 'lucee@#version#', destination );
		
	if( !installDetails.internal && installDetails.initialInstall ) {
			configureWebXML( cfengine="lucee", version=installDetails.version, source="#installDetails.installDir#/WEB-INF/web.xml", destination="#installDetails.installDir#/WEB-INF/web.xml" );	}	
		return installDetails;
	}

	/**
	* install railo
	* 
	* @destination target directory
	* @version Version number or empty to use default
	**/
	public function installRailo( required destination, required version ) {
	var installDetails = installEngineArchive( 'railo@#version#', destination );
		if(  installDetails.initialInstall  ) {
			configureWebXML( cfengine="railo", version=installDetails.version, source="#installDetails.installDir#/WEB-INF/web.xml", destination="#installDetails.installDir#/WEB-INF/web.xml" );			
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
		required string destination
		) {
			
		var installDetails = {
			internal : false,
			version : '',
			installDir : '',
			initialInstall : false
		};
		
		var thisTempDir = tempDir & '/' & createUUID();
			
		// Find out what endpoint will service them and ask the endpoint what their name is.
		var endpointData = endpointService.resolveEndpoint( ID, shell.pwd() );
		var endpoint = endpointData.endpoint;
		var engineName = endpoint.getDefaultName( arguments.ID );
		
		// In order to prevent uneccessary work, we're going to try REALLY hard to figure out exactly what engine will be installed 
		// before it actually happens so we can skip this whole mess if it's already in place.
		// if our endpoint is ForgeBox, figure out what version it is going to install.
		if( endpointData.endpointName == 'forgebox' ) {
			var version = endpoint.parseVersion( arguments.ID );
			
			// If the user gave us an exact version, just use it!
			if( semanticVersion.isExactVersion( version ) ) {
				var satisfyingVersion = version;				
			} else {
				consoleLogger.info( "Contacting ForgeBox to determine the best version match for [#version#].  Use an exact 'cfengine' version to skip this check.");
				// If ForgeBox is down, don't rain on people's parade.
				try {
					var satisfyingVersion = endpoint.findSatisfyingVersion( endpoint.parseSlug( arguments.ID ), version ).version;
				} catch( any var e ) {
					
					consoleLogger.error( ".");
					consoleLogger.error( "Aww man,  ForgeBox isn't feeling well.");
					consoleLogger.debug( "#e.message#  #e.detail#");
					consoleLogger.error( "We're going to look in your local artifacts cache and see if one of those versions will work.");
					
					// See if there's something usable in the artifacts cache.  If so, we'll use that version.
					var satisfyingVersion = artifactService.findSatisfyingVersion( endpoint.parseSlug( arguments.ID ), version );
					if( len( satisfyingVersion ) ) {
						arguments.ID = endpoint.parseSlug( arguments.ID ) & '@' & satisfyingVersion;
						consoleLogger.info( ".");
						consoleLogger.info( "Sweet! We found a local version of [#satisfyingVersion#] that we can use in your artifacts.");
						consoleLogger.info( ".");
					} else {
						throw( 'No satisfying version found for [#version#].', 'endpointException', 'Well, we tried as hard as we can.  ForgeBox is unreachable and you don''t have a usable version in your local artifacts cache.  Please try another version.' );
					}
				}				
			}
			installDetails.installDir = destination & engineName & "-" & replace( satisfyingVersion, '+', '.', 'all' );
			installDetails.version = satisfyingVersion;
			
		} else {
			
			// For all other endpoints, create a predictable folder based on the endpoint ID.
			// If the file that the endpoint points to changes, you'll have to forget the server to pick up changes.
			// The alternative is re-downloading the engine EVERY. SINGLE. TIME.
			installDetails.installDir = destination & engineName;
			
		}
		
		// If we're starting a Lucee server whose version matches the CLI engine, then don't download anyting, we're using internal jars.
		if( listFirst( arguments.ID, '@' ) == 'lucee' && server.lucee.version == replace( installDetails.version, '+', '.', 'all' ) ) {
			installDetails.internal = true;
			return installDetails;
		}
		
		// Check to see if this WAR has already been exploded
		if( fileExists( installDetails.installDir & '/WEB-INF/web.xml' ) ) {
			consoleLogger.info( "WAR/zip archive already installed.");
			return installDetails;
		}
		 
		// Install the engine via our standard package service
		installDetails.initialInstall = true;
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
		
		consoleLogger.info( "Exploding WAR/zip archive...");
		zip action="unzip" file="#theArchive#" destination="#installDetails.installDir#" overwrite="true";
				
		// Catch this to gracefully handle where the OS or another program 
		// has the folder locked.
		try {
			directoryDelete( thisTempDir, true );
		} catch( any e ) {
			consoleLogger.error( '#e.message##CR#The folder is possibly locked by another program.' );
			logger.error( '#e.message# #e.detail#' , e.stackTrace );
		}
		return installDetails;
	}
	
	/**
	* configure web.xml file for Lucee and Railo
	* TODO: Just make these changes directly in the WAR files
	* 
	* @cfengine lucee or railo
	* @source source web.xml
	* @destination target web.xml
	**/
	public function configureWebXML( required cfengine, required version, required source, destination ) {
		var webXML = XMLParse( source );
		var servlets = xmlSearch(webXML,"//:servlet-class[text()='#lcase( cfengine )#.loader.servlet.CFMLServlet']");
		var initParam = xmlElemnew(webXML,"http://java.sun.com/xml/ns/javaee","init-param");
		initParam.XmlChildren[1] = xmlElemnew(webXML,"param-name");
		initParam.XmlChildren[1].XmlText = "#lcase( cfengine )#-web-directory";
		initParam.XmlChildren[2] = xmlElemnew(webXML,"param-value");
		initParam.XmlChildren[2].XmlText = "/WEB-INF/#lcase( cfengine )#/{web-context-label}";
		arrayInsertAt(servlets[1].XmlParent.XmlChildren,4,initParam);
		
		// Lucee 5+ has a LuceeServlet as well as will create the WEB-INF by default in your web root
		if( arguments.cfengine == 'lucee' && val( listFirst( arguments.version, '.' )) >= 5 ) {			
			var servlets = xmlSearch(webXML,"//:servlet-class[text()='#lcase( cfengine )#.loader.servlet.LuceeServlet']");
			var initParam = xmlElemnew(webXML,"http://java.sun.com/xml/ns/javaee","init-param");
			initParam.XmlChildren[1] = xmlElemnew(webXML,"param-name");
			initParam.XmlChildren[1].XmlText = "#lcase( cfengine )#-web-directory";
			initParam.XmlChildren[2] = xmlElemnew(webXML,"param-value");
			initParam.XmlChildren[2].XmlText = "/WEB-INF/#lcase( cfengine )#/{web-context-label}";
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