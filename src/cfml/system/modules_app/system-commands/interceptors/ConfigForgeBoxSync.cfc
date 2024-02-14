/**
 *********************************************************************************
 * Copyright Since 2014 CommandBox by Ortus Solutions, Corp
 * www.coldbox.org | www.ortussolutions.com
 ********************************************************************************
 *
 * I am an interceptor that listens for system setting expansions
 *
 */
component accessors=true {
	// Flag to track when we're already syncing to prevent recursive calls
	property name="syncing" type="boolean" default="false";

	function init() {
		variables.userDataCache = {};
	}

	/**
	 * When config is updated, push settings
	 */
	function onConfigSettingSave( struct interceptData ) {
		if( !autoSyncEnabled() || !hasElligibleForgeBoxAccount() ) {
			return;
		}
		pushConfig();
	}

	/**
	 * When CLI starts, pull settings
	 */
	function onCLIStart( struct interceptData ) {
		if( !autoSyncEnabled() || !hasElligibleForgeBoxAccount() || interceptData.shellType != 'interactive' ) {
			return;
		}
		pullConfig();
	}

	/**
	 * When logging into forgebox or switching users, pull settings
	 */
	function onEndpointLogin( struct interceptData ) {
		if( !autoSyncEnabled() || !hasElligibleForgeBoxAccount() || getAutoSyncForgeBoxAccount() != interceptData.endpointName ) {
			return;
		}
		pullConfig();
	}

	/**
	 * When uninstalling a system module, push settings
	 */
	function postUninstall( struct interceptData ) {
		if( !interceptData.system || !autoSyncEnabled() || !hasElligibleForgeBoxAccount() ) {
			return;
		}
		pushConfig();
	}

	/**
	 * When installing a system module, push settings
	 */
	function postInstall( struct interceptData ) {
		if( !interceptData.system || !autoSyncEnabled() || !hasElligibleForgeBoxAccount() ) {
			return;
		}
		pushConfig();
	}


	/**
	 * wrapper for pushing config
	 */
	private function pushConfig() {
		doIfNotAlreadySyncing( ()=>{
			var endpointName = getAutoSyncForgeBoxAccount();
			getInstance('printBuffer').yellowLine( 'Syncing config settings to #endpointName#...' ).toConsole();
			getInstance( name='CommandDSL', initArguments={ 'name' : 'config sync push' } )
				.params(
					endpointName = endpointName,
					overwrite = getInstance('configService').getSetting( 'configAutoSync.overwrite', false )
				)
				.run();
		} );
	}

	/**
	 * wrapper for pulling config
	 */
	private function pullConfig() {
		doIfNotAlreadySyncing( ()=>{
			var endpointName = getAutoSyncForgeBoxAccount();
			getInstance('printBuffer').yellowLine( 'Syncing config settings from #endpointName#...' ).toConsole();
			getInstance( name='CommandDSL', initArguments={ 'name' : 'config sync pull' } )
			.params(
				endpointName = endpointName,
				overwrite = getInstance('configService').getSetting( 'configAutoSync.overwrite', false )
			)
			.run();
		} );
	}


	/**
	 * Name of ForgeBox endpoint
	 */
	private function getAutoSyncForgeBoxAccount() {
		var configService = getInstance('configService');
		return configService.getSetting(
			'configAutoSync.endpoint',
			configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' )
		);
	}

	/**
	 * Check if ForgeBox account is elligible for auto-sync
	 */
	private function hasElligibleForgeBoxAccount() {
		try {
			var endpointName = getAutoSyncForgeBoxAccount();
			var oEndpoint = getInstance('EndpointService').getEndpoint( endpointName );
			var APIToken = oEndpoint.getAPIToken();
			var forgebox = oEndpoint.getForgebox();

			if( !len( APIToken ) ) {
				return false;
			}

			// Look up account for this user and cache for as long as the CLI is open
			variables.userDataCache[APIToken] = variables.userDataCache[APIToken] ?: forgebox.whoami( APIToken );

			// Do they have a Pro plan?
			return ( variables.userDataCache[APIToken].subscription.plan.slug ?: '' ) == 'pro';

		} catch(any e) {
			getInstance('printBuffer').redLine( 'Error getting ForgeBox account [#getAutoSyncForgeBoxAccount()#] for config auto sync: #e.message# #e.detail# #e.tagContext[1].template#:#e.tagContext[1].line#' ).toConsole();
			return false;
		}
	}

	/**
	 * Check if auto-sync is enabled and CLI is not offline
	 */
	private function autoSyncEnabled() {
		var configService = getInstance('configService');
		return configService.getSetting( 'configAutoSync.enable', true ) && !configService.getSetting( 'offlineMode', false );
	}

	/**
	 * A wrapper to only sync if not already syncing
	 */
	private function doIfNotAlreadySyncing( udf ) {
		if( getSyncing() ) {
			return;
		}
		setSyncing( true );
		try{
			udf();
		} catch( any e ) {
			getInstance('printBuffer').redLine( 'Error syncing config settings with #getAutoSyncForgeBoxAccount()#: #e.message# #e.detail# #e.tagContext[1].template#:#e.tagContext[1].line#' ).toConsole();
		} finally{
			setSyncing( false );
		}
	}
}
