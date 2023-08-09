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
			var interceptData_serverInfo_name = systemSettings.getSystemSetting( 'interceptData.SERVERINFO.name', '' );
			// Lookup by name
			if( listLen( settingName, '@' ) > 1 ) {
				var serverInfo = serverService.getServerInfoByName( listLast( settingName, '@' ) );
				settingName = listFirst( settingName, '@' );
			// If we're running inside of a server-related package script, use that server
			} else if( interceptData_serverInfo_name != '' ) {
				var serverInfo = serverService.getServerInfoByName( interceptData_serverInfo_name );
			// Lookup by current working directory
			} else {
				var serverInfo = serverService.getServerInfoByWebroot( shell.pwd() );
			}
			// We may not be in a web root, but we may be in a folder that contains a server.json file that belongs to a server
			var serverJSONPath = shell.pwd() & '/server.json';
			if( !serverInfo.count() && fileExists( serverJSONPath ) ) {
				var serverInfo = serverService.getServerInfoByServerConfigFile( serverJSONPath );
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
