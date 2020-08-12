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

	property name="systemSettings"	inject="SystemSettings";
	property name="JSONService"		inject="JSONService";
	property name="ConfigService"	inject="ConfigService";
	property name="fileSystemUtil"	inject="fileSystem";

	function onSystemSettingExpansion( struct interceptData ) {
		
		// ${json.property.name@file.json}
		if( interceptData.setting.lcase().startsWith( 'json.' ) ) {
			
			var settingName = interceptData.setting.replaceNoCase( 'json.', '', 'one' );
			var fileName = fileSystemUtil.resolvepath( settingName.listLast( '@' ) );
			var settingName = settingName.listFirst( '@' );
			
			if( !fileExists( fileName ) ) {
				return;
			}
			
			var JSONRaw = fileRead( fileName );
			if( !isJSON( JSONRaw ) ) {
				return;
			}
			var JSON = deserializeJSON( JSONRaw );
			interceptData.setting = JSONService.show( JSON, settingName, interceptData.defaultValue );
			
			// Stop processing expansions on this setting
			interceptData.resolved=true;
			return true;
			
		// ${configsetting.property.name}
		} else if( interceptData.setting.lcase().startsWith( 'configsetting.' ) ) {
			
			var settingName = interceptData.setting.replaceNoCase( 'configsetting.', '', 'one' );
			interceptData.setting = ConfigService.getSetting( settingName, interceptData.defaultValue );
			
			if( !isSimpleValue( interceptData.setting ) ) {
				interceptData.setting = serializeJSON( interceptData.setting );
			}
			
			// Stop processing expansions on this setting
			interceptData.resolved=true;
			return true;
		}
		
	}
	
}
