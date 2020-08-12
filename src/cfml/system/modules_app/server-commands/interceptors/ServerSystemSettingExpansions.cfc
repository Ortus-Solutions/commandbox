/**
 *********************************************************************************
 * Copyright Since 2014 CommandBox by Ortus Solutions, Corp
 * www.coldbox.org | www.ortussolutions.com
 ********************************************************************************
 *
 * I am an interceptor that listens for system setting expansions
 *
 */
component {

	property name="serverService"	inject="serverService";
	property name="systemSettings"	inject="SystemSettings";
	property name="JSONService"		inject="JSONService";
	property name="fileSystemUtil"	inject="fileSystem";

	function onSystemSettingExpansion( struct interceptData ) {
		
		// ${serverjson.property.name}
		// ${serverjson.property.name@customServerFile.json}
		if( interceptData.setting.lcase().startsWith( 'serverjson.' ) ) {
			
			var settingName = interceptData.setting.replaceNoCase( 'serverjson.', '', 'one' );
			var fileName = shell.pwd() & 'server.json';
			
			if( listLen( settingName, '@' ) > 1 ) {
				fileName = fileSystemUtil.resolvePath( listLast( settingName, '@' ) );
				settingName = listFirst( settingName, '@' );
			}
			
			var serverJSON = serverService.readServerJSON( fileName );
			interceptData.setting = JSONService.show( serverJSON, settingName, interceptData.defaultValue );
			
			if( !isSimpleValue( interceptData.setting ) ) {
				interceptData.setting = serializeJSON( interceptData.setting );
			}
			
			// Stop processing expansions on this setting
			interceptData.resolved=true;
			return true;
			
			
		// ${serverinfo.property.name}
		// ${serverinfo.property.name@serverName}
		} else if( interceptData.setting.lcase().startsWith( 'serverinfo.' ) ) {
			
			var settingName = interceptData.setting.replaceNoCase( 'serverinfo.', '', 'one' );
			
			// Lookup by name
			if( listLen( settingName, '@' ) > 1 ) {
				var serverDetails = serverService.resolveServerDetails( { name : listLast( settingName, '@' ) } );
				settingName = listFirst( settingName, '@' );
			// Lookup by current working directory
			} else {
				var serverDetails = serverService.resolveServerDetails( { directory : shell.pwd() } );
			}
			// If server wasn't found, use empty struct so we get empty strings instead of serverInfo default values
			if( serverdetails.serverIsNew ) {
				var serverInfo = {};
			} else {
				var serverInfo = serverDetails.serverInfo;	
			}

			interceptData.setting = JSONService.show( serverInfo, settingName, interceptData.defaultValue );
			
			if( !isSimpleValue( interceptData.setting ) ) {
				interceptData.setting = serializeJSON( interceptData.setting );
			}
			
			// Stop processing expansions on this setting
			interceptData.resolved=true;
			return true;
		}
		
	}
	
}
