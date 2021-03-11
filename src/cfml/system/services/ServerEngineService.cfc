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

		var installDetails = installEngineArchive( cfengine, arguments.baseDirectory, serverInfo, serverHomeDirectory );

		if( installDetails.engineName contains "adobe" ) {
			return installAdobe( installDetails, serverInfo );
		} else if ( installDetails.engineName contains "railo" ) {
			return installRailo( installDetails, serverInfo );
		} else if ( installDetails.engineName contains "lucee" ) {
			return installLucee( installDetails, serverInfo );
		} else {
			return installDetails;
		}

	}

	/**
	* install adobe
	*
	**/
	public function installAdobe( installDetails, serverInfo ) {

		// Fix Adobe's broken default /CFIDE mapping
		var runtimeConfigPath = installDetails.installDir & "/WEB-INF/cfusion/lib/neo-runtime.xml";
		var CFIDEPath = installDetails.installDir & "/CFIDE";
		if ( fileExists( runtimeConfigPath ) ) {

			var runtimeConfigDoc = XMLParse( runtimeConfigPath );
			// Looking for a <string> tag whose sibling is a <var> tag with a "name" attribute of "/CFIDE".
			var results = xmlSearch( runtimeConfigDoc, "//struct/var[@name='/CFIDE']/string" );
			var oldCFIDEPath = '';
			if( results.len() ) {
				oldCFIDEPath = results[ 1 ].XMLText;
			}

			if( !len( oldCFIDEPath )
				// OR points to a nonexistent directory that is not what we think it should be.
				|| ( !directoryExists( oldCFIDEPath )
					&& oldCFIDEPath != CFIDEPath ) ) {

				// Here you go, sir.
				results[ 1 ].XMLText = CFIDEPath;
				// Write it back out.
				writeXMLFile( runtimeConfigDoc, runtimeConfigPath );
			}
		}

		return installDetails;
	}

	/**
	* install lucee
	*
	**/
	public function installLucee( installDetails, serverInfo ) {

		if( installDetails.initialInstall ) {
			configureWebXML( cfengine="lucee", version=installDetails.version, source=serverInfo.webXML, destination=serverInfo.webXML, serverInfo=serverInfo );
		}
		return installDetails;
	}

	/**
	* install railo
	*
	**/
	public function installRailo( installDetails, serverInfo ) {

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

		if( ID == 'none' ) {
			ID = expandPath( '/server-commands/bin/www-engine.zip' );
		}

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

		// In order to prevent unnecessary work, we're going to try REALLY hard to figure out exactly what engine will be installed
		// before it actually happens so we can skip this whole mess if it's already in place.
		// if our endpoint is ForgeBox, figure out what version it is going to install.
		if( isInstanceOf(endpointData.endpoint, 'forgebox') ) {
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

					if( e.detail contains 'The entry slug sent is invalid or does not exist' ) {
						job.addErrorLog( "#e.message#  #e.detail#" );
						throw( e.message, 'endpointException', e.detail );
					}

					job.addErrorLog( "Aww man, we ran into an issue.");
					job.addLog( "#e.message#  #e.detail#");
					job.addErrorLog( "We're going to look in your local artifacts cache and see if one of those versions will work.");

					// See if there's something usable in the artifacts cache.  If so, we'll use that version.
					var satisfyingVersion = artifactService.findSatisfyingVersion( endpoint.parseSlug( arguments.ID ), version );
					if( len( satisfyingVersion ) ) {
						arguments.ID = endpoint.parseSlug( arguments.ID ) & '@' & satisfyingVersion;
						job.addLog( "Sweet! We found a local version of [#satisfyingVersion#] that we can use in your artifacts.");
					} else {
						if( len( arguments.serverHomeDirectory ) && fileExists( arguments.serverHomeDirectory & '/.engineInstall' ) ) {
							var previousEngineTag = fileRead( arguments.serverHomeDirectory & '/.engineInstall' );
							job.addErrorLog( "No matching artifacts found.");
							job.addErrorLog( "Your custom server home has an engine there [#previousEngineTag#], so we'll just roll with that.");
							var satisfyingVersion = '';

							if( previousEngineTag.listLen( '@' ) > 1 ) {
								satisfyingVersion = previousEngineTag.listLast( '@' );
							}

						} else {
							throw( 'No satisfying version found for [#version#].', 'endpointException', 'Well, we tried as hard as we can.  ForgeBox can''t find the package and you don''t have a usable version in your local artifacts cache.  Please try another version.' );
						}

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

			// For existing engines, grab the version from the engine tag file.
			// This is important so non-forgebox-sourced engines don't revert to stupid names without versions
			if( previousEngineTag.listLen( '@' ) > 1 ) {
				installDetails.engineName = previousEngineTag.listFirst( '@' );
				installDetails.version = previousEngineTag.listLast( '@' );
			}

			calcLuceeRailoContextPaths( installDetails, serverInfo );
			return installDetails;
		}

		// Install the engine via our standard package service
		installDetails.initialInstall = true;

		// If we're starting a Lucee server whose version matches the CLI engine, then don't download anything, we're using internal jars.
		if( listFirst( arguments.ID, '@' ) == getCLIEngineName() && server.lucee.version == replace( installDetails.version, '+', '.', 'all' ) ) {

			job.addLog( "Building a WAR from local jars.");

			// Spoof a WAR file.
			var thisWebinf = installDetails.installDir & '/WEB-INF';
			var thislib = thisWebinf & '/lib';

			directoryCreate( installDetails.installDir & '/WEB-INF', true, true );
			directoryCopy( '/commandbox-home/lib', thislib, false, 'lucee-*.jar' );
			// CommandBox ships with a pack200 compressed Lucee jar. Unpack it for faster start
			unpackLuceeJar( thislib, installDetails.version );

			fileCopy( expandPath( '/commandbox/system/config/web.xml' ), thisWebinf & '/web.xml');

			// Mark this WAR as being exploded already
			fileWrite( engineTagFile, thisEngineTag );

			calcLuceeRailoContextPaths( installDetails, serverInfo );

			var thisServerContext = serverInfo.serverConfigDir;
			if( thisServerContext.startsWith( '/WEB-INF' ) ) {
				thisServerContext = installDetails.installDir & thisServerContext;
			}
			directoryCreate( thisServerContext & '/lucee-server/patches', true, true );
			directoryCreate( thisServerContext & '/lucee-server/deploy', true, true );
			directoryCopy( '/commandbox-home/engine/cfml/cli/lucee-server/patches', thisServerContext & '/lucee-server/patches', false, '*.lco' );
			directoryCopy( '/commandbox-home/engine/cfml/cli/lucee-server/context/extensions/installed/', thisServerContext & '/lucee-server/deploy', false, '*.lex' );

			return installDetails;
		}

		if( !packageService.installPackage( ID=arguments.ID, directory=thisTempDir, save=false ) ) {
			throw( message='Server not installed.', type="commandException");
		}

		// Extract engine name and version from the package.  This is required for non-ForgeBox endpoints
		// since we don't know it until we actually do the installation
		if( packageService.isPackage( thisTempDir ) ) {
			var boxJSON = packageService.readPackageDescriptor( thisTempDir );
			// This ensure the CommandBox server will pick up the correct metadata
			installDetails.version = boxJSON.version;
			installDetails.engineName = boxJSON.slug;
			// This file is so we know the correct version of our server on disk
			thisEngineTag = boxJSON.slug & '@' & boxJSON.version;
		}

		calcLuceeRailoContextPaths( installDetails, serverInfo );

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

	private function calcLuceeRailoContextPaths( installDetails, serverInfo ) {

		// Set up server and web context dirs if Railo or Lucee
		if( installDetails.engineName contains 'lucee' || installDetails.engineName contains 'railo' ) {

			// Loose checking so "lucee-light" still turnes into "lucee"
			var thisName = 'lucee';
			if( installDetails.engineName contains 'railo' ) {
				thisName = 'railo';
			}

			// Default web context
			if( !len( serverInfo.webConfigDir ) ) {
				serverInfo.webConfigDir = "/WEB-INF/#lcase( thisName )#-web";
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
		if( !servlets.len() ) {
			var servlets = xmlSearch(webXML,"//servlet-class[text()='#lcase( cfengine )#.loader.servlet.CFMLServlet']");
		}
		var initParam = xmlElemnew(webXML,"http://java.sun.com/xml/ns/javaee","init-param");
		initParam.XmlChildren[1] = xmlElemnew(webXML,"param-name");
		initParam.XmlChildren[1].XmlText = "#lcase( cfengine )#-web-directory";
		initParam.XmlChildren[2] = xmlElemnew(webXML,"param-value");
		initParam.XmlChildren[2].XmlText = serverInfo.webConfigDir;
		arrayInsertAt(servlets[1].XmlParent.XmlChildren,4,initParam);

		var servlets = xmlSearch(webXML,"//:servlet-class[text()='#lcase( cfengine )#.loader.servlet.CFMLServlet']");
		if( !servlets.len() ) {
			var servlets = xmlSearch(webXML,"//servlet-class[text()='#lcase( cfengine )#.loader.servlet.CFMLServlet']");
		}
		var initParam = xmlElemnew(webXML,"http://java.sun.com/xml/ns/javaee","init-param");
		initParam.XmlChildren[1] = xmlElemnew(webXML,"param-name");
		initParam.XmlChildren[1].XmlText = "#lcase( cfengine )#-server-directory";
		initParam.XmlChildren[2] = xmlElemnew(webXML,"param-value");
		initParam.XmlChildren[2].XmlText = serverInfo.serverConfigDir;
		arrayInsertAt(servlets[1].XmlParent.XmlChildren,4,initParam);

		// Lucee 5+ has a LuceeServlet as well as will create the WEB-INF by default in your web root
		if( arguments.cfengine == 'lucee' && val( listFirst( arguments.version, '.' )) >= 5 ) {
			var servlets = xmlSearch(webXML,"//:servlet-class[text()='#lcase( cfengine )#.loader.servlet.LuceeServlet']");
			if( !servlets.len() ) {
				var servlets = xmlSearch(webXML,"//servlet-class[text()='#lcase( cfengine )#.loader.servlet.LuceeServlet']");
			}
			var initParam = xmlElemnew(webXML,"http://java.sun.com/xml/ns/javaee","init-param");
			initParam.XmlChildren[1] = xmlElemnew(webXML,"param-name");
			initParam.XmlChildren[1].XmlText = "#lcase( cfengine )#-web-directory";
			initParam.XmlChildren[2] = xmlElemnew(webXML,"param-value");
			initParam.XmlChildren[2].XmlText = serverInfo.webConfigDir;
			arrayInsertAt(servlets[1].XmlParent.XmlChildren,4,initParam);

			var servlets = xmlSearch(webXML,"//:servlet-class[text()='#lcase( cfengine )#.loader.servlet.LuceeServlet']");
			if( !servlets.len() ) {
				var servlets = xmlSearch(webXML,"//servlet-class[text()='#lcase( cfengine )#.loader.servlet.LuceeServlet']");
			}
			var initParam = xmlElemnew(webXML,"http://java.sun.com/xml/ns/javaee","init-param");
			initParam.XmlChildren[1] = xmlElemnew(webXML,"param-name");
			initParam.XmlChildren[1].XmlText = "#lcase( cfengine )#-server-directory";
			initParam.XmlChildren[2] = xmlElemnew(webXML,"param-value");
			initParam.XmlChildren[2].XmlText = serverInfo.serverConfigDir;
			arrayInsertAt(servlets[1].XmlParent.XmlChildren,4,initParam);
		}
		writeXMLFile( webXML, destination );
		return true;
	}

	/**
	* Write an XML file to disk and format it so it's human-readable
	*
	* @XMLDoc XML Doc to write (complex value)
	* @path File path to write XML to
	**/
	private function writeXMLFile( XMLDoc, path ) {
		var xlt = '<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
		<xsl:output method="xml" encoding="utf-8" indent="yes" xslt:indent-amount="2" xmlns:xslt="http://xml.apache.org/xslt" />
		<xsl:strip-space elements="*"/>
		<xsl:template match="node() | @*"><xsl:copy><xsl:apply-templates select="node() | @*" /></xsl:copy></xsl:template>
		</xsl:stylesheet>';

		fileWrite( path, toString( XmlTransform( XMLDoc, xlt) ) );
	}

	/**
	* Find the Lucee jar in the lib directory and if it's packed, unpack it.
	* If the unpacked jar is found in artifacts, use it instead.
	* If not, unpack and store in artifacts for next time.
	*
	* @libDirectory Directory where the libs are for the server
	* @luceeVersion Semver for the Lucee version so we can use artifacts
	**/
	private function unpackLuceeJar( libDirectory, luceeVersion ) {
		var job = wirebox.getInstance( 'interactiveJob' );
		var tempDir = wirebox.getInstance( 'tempDir@constants' ) & '/lucee_unpack' & randRange( 1, 500 );

		try {
			// Look for a jar called "lucee-1.2.3-packed.jar
			var luceeJarArr = directoryList( path=libDirectory, filter="lucee*-packed.jar" );

			// If we found one
			if( luceeJarArr.len() ) {
				var luceeJarPath = luceeJarArr[ 1 ];
				var luceeUnpackedJarPath = luceeJarPath.replace( '-packed', '' )
				var explodedJarDir = tempDir & '/explodedJar';
				var explodedJarBundlesDir = explodedJarDir & '/bundles';
				var explodedJarCoreDir = explodedJarDir & '/core';
				var explodedJarExtensionsDir = explodedJarDir & '/extensions';

				// If found in artifacts
				if( artifactService.artifactExists( 'luceejar-unpacked', luceeVersion ) ) {

					// Delete the packed one
					fileDelete( luceeJarPath );
					// And put the artifact in its place
					fileCopy( artifactService.getArtifactPath( 'luceejar-unpacked', luceeVersion ), luceeUnpackedJarPath );

				} else {

					job.addLog( 'Unpacking Lucee jar for faster start (one-time operation)' );

					directoryCreate( explodedJarDir, true, true );
					zip action="unzip" file="#luceeJarPath#" destination="#explodedJarDir#" overwrite="false";

					// Process packed OSGI bundles
					if( directoryExists( explodedJarBundlesDir ) ) {
						var bundleArray = directoryList( path=explodedJarBundlesDir, filter="*.jar.pack.gz" );
						bundleArray.each( unpackInPlace, true, createObject( 'java', 'java.lang.Runtime' ).getRuntime().availableProcessors() );
					}

					// Process Lucee Core file
					if( directoryExists( explodedJarCoreDir ) ) {
						var coreArray = directoryList( path=explodedJarCoreDir, filter="*.pack.gz" );
						coreArray.each( unpackInPlace );
					}

					// Process Lucee Extensions
					if( directoryExists( explodedJarExtensionsDir ) ) {
						var extArray = directoryList( path=explodedJarExtensionsDir, filter="*.lex" );
						var extTmpDir = explodedJarExtensionsDir & '/temp';
						var extJarsTmpDir = extTmpDir & '/jars';
						// For each LEX file
						extArray.each( function( extFile ) {
							directoryCreate( explodedJarDir, true, true );
							zip action="unzip" file="#extFile#" destination="#extTmpDir#" overwrite="false";

							if( directoryExists( extJarsTmpDir ) ) {
								// Process packed OSGI bundles
								var bundleArray = directoryList( path=extJarsTmpDir, filter="*.jar.pack.gz" );
								bundleArray.each( unpackInPlace, true, createObject( 'java', 'java.lang.Runtime' ).getRuntime().availableProcessors() );
							}

							// Delete the old lex and replace with the new unpacked one
							fileDelete( extFile );
							zip action='zip' source=extTmpDir file=extFile;

							directoryDelete( extTmpDir, true );
						} );
					}

					fileDelete( luceeJarPath );
					zip action='zip' source=explodedJarDir file=luceeUnpackedJarPath;

					// Place in artifacts
					fileCopy( luceeUnpackedJarPath, tempDir & 'temp.zip' );
					artifactService.createArtifact( 'luceejar-unpacked', luceeVersion, tempDir & 'temp.zip' );

				}


			} // end if for jar existence

		} catch( any var e ) {
			// If something goes wrong, let the user know in the job logs, but ignore the error.
			// The server will continue to start, but just using the packed jar.
			job.adderrorLog( 'Error unpacking Lucee jar' );
			job.adderrorLog( e.message );
			job.adderrorLog( e.detail );
			job.adderrorLog( e.tagContext[ 1 ].template & ':' &  e.tagContext[ 1 ].line );
		} finally {
			// Clean up
			if( directoryExists( tempDir ) ) {
				try {
					directoryDelete( tempDir, true );
				} catch( any var e2 ) {}
			}
		}

	}

	/**
	* Take a pack200 packed jar and unpack it into the same folder, deleting the original
	*
	* @packedFile Path to the packed file named something.foo.pack.gz. Will be replaced with something.foo
	**/
	private function unpackInPlace( packedFile ) {
		var packedFileDir = getDirectoryFromPath( packedFile );
		var unpackedFile = packedFile.replace( '.pack.gz', '' );

		try {
			// Class to unpack the jars
			var unpacker = createObject( 'java', 'java.util.jar.Pack200' ).newUnpacker();
			// Out stream (the file being written to)
			var out = createObject( 'java', 'java.util.jar.JarOutputStream' ).init( createObject( 'java', 'java.io.FileOutputStream' ).init( unpackedFile ) );
			// In stream (the jar being unpacked)
			var in = createObject( 'java', 'java.util.zip.GZIPInputStream' ).init( createObject( 'java', 'java.io.FileInputStream' ).init( packedFile ) );

			// Do the unpacking
			unpacker.unpack( in, out );

		// This stuff 'gotta happen
		} finally {
			try {
				// Close input stream
				in.close();
			} catch( any var e2 ) {}

			try {
				// Flush and close output stream
				out.flush();
				out.close();
			} catch( any var e2 ) {}

			// Delete original packed file
			fileDelete( packedFile );
		}

	}

	function getCLIEngineName() {
		// You really can't "detect" Lucee Lite, so I'll just guess based on if there any a full list of extensions installed
		if(  extensionList().recordCount < 5 ) {
			return 'lucee-light';
		}
		return 'lucee';
	}

}
