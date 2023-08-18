/**
*********************************************************************************
* Copyright Since 2014 CommandBox by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano
*/
component {
	function configure() {
		interceptors = [
			{ class="#moduleMapping#.interceptors.JSONSystemSettingExpansions" },
			{ class="#moduleMapping#.interceptors.ConfigForgeBoxSync" }
		];
	}
}
