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

			if( callStackGet().filter( (c)=>c.function=='onSystemSettingExpansion' ).len()>2 ) {
				throw( message='Endless recursion detected while trying to evaluate [#interceptData.setting#].', detail='Trying to reference details of a server in its own sever.json can cause this catch-22 scenario.', type='CommandException' )	
			}

			// Lookup by name
			if( listLen( settingName, '@' ) > 1 ) {
				var serverInfo = serverService.getServerInfoByName( listLast( settingName, '@' ) );
				settingName = listFirst( settingName, '@' );
			// Lookup by current working directory
			} else {
				var serverInfo = serverService.getServerInfoByWebroot( shell.pwd() );
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
