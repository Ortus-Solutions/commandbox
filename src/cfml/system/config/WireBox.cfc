/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* WireBox Configuration
*/
component extends='wirebox.system.ioc.config.Binder' {

	function configure() {

		// auto scan locations
		wirebox.scanLocations = [
			'/commandbox/system'
		];

		// scope registration
		wirebox.scopeRegistration = {
			enabled = true,
			scope   = 'application',
			key		= 'wireBox'
		};

		// Register all event listeners here, they are created in the specified order
		wirebox.listeners = [
			// { class='', name='', properties={} }
		];

		// LogBox
		wirebox.logBoxConfig = 'commandbox.system.config.LogBox';

		wirebox.cacheBox = {
			enabled = true,
			configFile = 'commandbox.system.config.CacheBox'
		};

		wirebox.metadataCache='metadataCache';

		// Register CommandBox DSL for special injection namespaces
		mapDSL( 'commandbox', 'commandbox.system.config.CommandBoxDSL' );
	}

	function onLoad() {

		// Setup constants
		var system					= createObject( 'java', 'java.lang.System' );
		var homeDir					= isNull( system.getProperty( 'cfml.cli.home' ) ) ?
				system.getProperty( 'user.home' ) & '/.CommandBox/' : system.getProperty( 'cfml.cli.home' );
		var tempDir					= homedir & '/temp';
		var artifactDir				= homedir & '/artifacts';
		var userDir					= system.getProperty( 'user.dir' );
		var commandHistoryFile		= homedir & '/.history-command';
		var REPLScriptHistoryFile 	= homedir & '/.history-repl-script';
		var REPLTagHistoryFile 		= homedir & '/.history-repl-tag';
		var cr						= chr( 10 );
		var commandLocations		= [
			// This is where user-installed commands are stored
			// This is deprecated in favor of modules, but leaving it so 'old' style commands will still load.
			'/commandbox-home/commands'
		];
		var ortusArtifactsURL		= 'http://downloads.ortussolutions.com/';
		var ortusPRDArtifactsURL	= 'http://downloads.ortussolutions.com/';
		var colors256Data			= deserializeJSON( fileRead( homedir & '/cfml/system/config/colors.json' ) );
		var semverRegex				= '\d{1,3}(?:\.\d{1,3}){2}(?:-\w+(?:\.\w+)*)?(?:\+\w+(?:\.\w+)*)?';
		// engine versions, first is default - for lucee, first is internal version

		// map constants
		map( 'system@constants' ).toValue( system );
		map( 'homeDir@constants' ).toValue( homeDir );
		map( 'tempDir@constants' ).toValue( tempDir );
		map( 'userDir@constants' ).toValue( userDir );
		map( 'artifactDir@constants' ).toValue( artifactDir );
		map( 'commandHistoryFile@constants' ).toValue( commandHistoryFile );
		map( 'REPLScriptHistoryFile@constants' ).toValue( REPLScriptHistoryFile );
		map( 'REPLTagHistoryFile@constants' ).toValue( REPLTagHistoryFile );
		map( 'cr@constants' ).toValue( cr );
		map( 'commandLocations@constants' ).toValue( commandLocations );
		map( 'ortusArtifactsURL@constants' ).toValue( ortusArtifactsURL );
		map( 'ortusPRDArtifactsURL@constants' ).toValue( ortusPRDArtifactsURL );
		map( 'rewritesDefaultConfig@constants' ).toValue( '#homeDir#/cfml/system/config/urlrewrite.xml' );
		map( 'colors256Data@constants' ).toValue( colors256Data );
		map( 'semverRegex@constants' ).toValue( semverRegex );

		// Map Directories
		mapDirectory( '/commandbox/system/services' );
		mapDirectory( '/commandbox/system/util' );
	}

}
