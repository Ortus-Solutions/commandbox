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

	property name="packageService"	inject="packageService";
	property name="systemSettings"	inject="SystemSettings";
	property name="JSONService"		inject="JSONService";
	property name="fileSystemUtil"	inject="fileSystem";

	function onSystemSettingExpansion( struct interceptData ) {

		// ${boxjson.slug}
		if( interceptData.setting.lcase().startsWith( 'boxjson.' ) ) {

			var settingName = interceptData.setting.replaceNoCase( 'boxjson.', '', 'one' );

			var boxJSON = packageService.readpackageDescriptor( shell.pwd() );
			interceptData.setting = JSONService.show( boxJSON, settingName, interceptData.defaultValue );

			if( !isSimpleValue( interceptData.setting ) ) {
				interceptData.setting = serializeJSON( interceptData.setting );
			}

			// Stop processing expansions on this setting
			interceptData.resolved=true;
			return true;
		}

	}

}