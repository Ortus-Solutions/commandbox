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
  property name='tempDir'			inject='tempDir@constants';
  property name='packageService'	inject='PackageService';
  property name='logger'			inject='logbox:logger:{this}';
  property name='consoleLogger'		inject='logbox:logger:console';
  property name="cfengineVersions"	inject="cfengineVersions@constants";
  property name='cr'				inject='cr@constants';

  /**
  * DI complete
  */
  function onDIComplete() {
  }


  /**
  * Checks engine and version, returning default version if version is empty
  * @cfengine    CFML Engine name (lucee, adobe, railo)
  * @version     Version number or empty to get default
  **/
  public function checkVersion( required cfengine, required version) {
    if(isNull(cfengineVersions[cfengine])) {
      throw( message="unknown cfengine type: " & cfengine );
    }
    if(version == "") {
      version = cfengineVersions[cfengine][1];
    } else {
      var versions = cfengineVersions[cfengine];
      var valid = false;
      for(var ver in versions) {
        if(ver.toLowerCase().startsWith(lcase(version))) {
          version = ver;
          valid = true;
        }
      }
      if(!valid) {
        throw( message="unknown #cfengine# version: " & version );
      }
    }
    return version;
  }
  
  /**
  * install the server if not already installed to the target directory
  * @cfengine        CFML Engine name (lucee, adobe, railo)
  * @basedirectory   base directory for server install
  * @version         Version number or empty to use default
  **/
  public function install( required cfengine, required basedirectory, force=false) {
    version = find("@",cfengine) ? listLast(cfengine,"@") : "";
    cfengine = listFirst(cfengine,"@");
    basedirectory = !basedirectory.endsWith("/") ? basedirectory & "/" : basedirectory;
    var engineVersion = checkVersion(cfengine=cfengine,version=version);
    var installDir = basedirectory & cfengine & "-" & engineVersion;
    if(!fileExists(installDir & "/WEB-INF/web.xml") || force) {
      consoleLogger.info("Installing #cfengine# #engineVersion# in #installDir#");
      if( cfengine == "adobe" ) {
        installAdobe( destination=installDir, version=engineVersion );
      } else if (cfengine == "railo") {
        installRailo( destination=installDir, version=engineVersion );
      } else if (cfengine == "lucee") {
        installLucee( destination=installDir, version=engineVersion );
      } else {
       throw( message="unknown engine type:" & cfengine );
      }
    } else {
      consoleLogger.info("Using #cfengine# in #installDir#");
    }
    return installDir;
  }

  /**
  * install adobe
  * @destination     target directory
  * @version         Version number or empty to use default
  **/
  public function installAdobe( required destination, required version ) {
	
	var versionInstalled = installEngineArchive( 'adobe-coldFusion-cf-engine@#version#', destination );
    
    if( left( versionInstalled, 2 ) == 10 || left( version, 2 ) == 11 || left( version, 4 ) == 2016 ) {
		installEngineArchive( 'adobe-coldFusion-cf-engine-tomcat-libs', destination );
	}
	
    // set password to "commandbox"
    fileWrite(destination & "/WEB-INF/cfusion/lib/password.properties", "rdspassword=#cr#password=commandbox#cr#encrypted=false");
  }

  /**
  * install lucee
  * @destination     target directory
  * @version         Version number or empty to use default
  **/
  public function installLucee( required destination, required version ) {
    
	installEngineArchive( 'lucee-cf-engine@#version#', destination );
	
    configureWebXML(cfengine="lucee",source="#destination#/WEB-INF/web.xml",destination="#destination#/WEB-INF/web.xml");
  }

  /**
  * install railo
  * @destination     target directory
  * @version         Version number or empty to use default
  **/
  public function installRailo( required destination, required version ) {
    
	installEngineArchive( 'railo-cf-engine@#version#', destination );
	
    configureWebXML(cfengine="railo",source="#destination#/WEB-INF/web.xml",destination="#destination#/WEB-INF/web.xml");
  }


	/*
	* Downloads a CF engine endpoint and unzips the "Engine.[WAR|zip] archive into the destination
	*/
	function installEngineArchive( required string ID, required string destination ) {
    	var thisTempDir = tempDir & '/' & createUUID();
    	var versionInstalled = '0';
    	 
		packageService.installPackage( ID=arguments.ID, directory=thisTempDir, save=false );
				
		if( packageService.isPackage( thisTempDir ) ) {
			var boxJSON = packageService.readPackageDescriptor( thisTempDir );
			versionInstalled =  boxJSON.version;			
		}
				
		var theArchive = '';
		for( var thisFile in directoryList( thisTempDir ) ) {
			if( listFindNoCase( 'war,zip', listLast( thisFile, '.' ) ) ) {
				theArchive = thisFile;
			}
		}
		
		if( thisFile == '' ) {
			throw( "Package didn't contain a war or zip archive." );
		}
		
		consoleLogger.info( "Exploding WAR/zip archive...");
		zip action="unzip" file="#thisFile#" destination="#destination#" overwrite="true";
				
		// Catch this to gracefully handle where the OS or another program 
		// has the folder locked.
		try {
			directoryDelete( thisTempDir, true );
		} catch( any e ) {
			consoleLogger.error( '#e.message##CR#The folder is possibly locked by another program.' );
			logger.error( '#e.message# #e.detail#' , e.stackTrace );
		}
		return versionInstalled;
	}
  /**
  * configure web.xml file for Lucee and Railo
  * @cfengine        lucee or railo
  * @source          source web.xml
  * @destination     target web.xml
  **/
  public function configureWebXML(required cfengine, required source, destination) {
  	var webXML = XMLParse(source);
    var servlets = xmlSearch(webXML,"//:servlet-class[text()='#lcase(cfengine)#.loader.servlet.CFMLServlet']");
    var initParam = xmlElemnew(webXML,"http://java.sun.com/xml/ns/javaee","init-param");
    initParam.XmlChildren[1] = xmlElemnew(webXML,"param-name");
    initParam.XmlChildren[1].XmlText = "#lcase(cfengine)#-web-directory";
    initParam.XmlChildren[2] = xmlElemnew(webXML,"param-value");
    initParam.XmlChildren[2].XmlText = "/WEB-INF/#lcase(cfengine)#/{web-context-label}";
    arrayInsertAt(servlets[1].XmlParent.XmlChildren,4,initParam);
		var xlt = '<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
		<xsl:output method="xml" encoding="utf-8" indent="yes" xslt:indent-amount="2" xmlns:xslt="http://xml.apache.org/xslt" />
		<xsl:strip-space elements="*"/>
		<xsl:template match="node() | @*"><xsl:copy><xsl:apply-templates select="node() | @*" /></xsl:copy></xsl:template>
		</xsl:stylesheet>';
    fileWrite(destination,toString(XmlTransform(webXML,xlt)));
    return true;
  }

  /**
  * Dynamic completion for cfengine
  */  
  function getCFEngineNames() {
    var engineNames = ["lucee","adobe","railo"];
    var namesAndVersions = [];
    for (var name in engineNames) {
      for (var version in cfengineVersions[name]) {
        arrayAppend(namesAndVersions,name & "@" & ucase(version));
      }
    }
    return namesAndVersions;
  }
  
  /**
  * Dynamic completion for cfengine
  */  
  function getCFEngineVersions(required cfengine) {
    return cfengineVersions[cfengine];
  }

}