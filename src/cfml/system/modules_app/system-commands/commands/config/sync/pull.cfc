/**
 * Sync remote config settings with locaL settings for your user
 * Settings will be merged together
 * .
 * {code:bash}
 * config sync pull
 * {code}
 * .
 * To completely replace local settings wtih remote settings, use the --overwrite flag
 * .
 * {code:bash}
 * config sync pull --overwrite
 * {code}
 *
 **/
component {

	property name="packageService" inject="packageService";
	property name="ConfigService" inject="ConfigService";
	property name="JSONService" inject="JSONService";
	property name="endpointService" inject="endpointService";
	property name="jsondiff" inject="jsondiff";

	/**
	 * @endpointName  Name of custom forgebox endpoint to use
	 * @endpointName.optionsUDF endpointNameComplete
	 * @overwrite Overwrite local settings entirely with remote settings
	 **/
	function run( string endpointName, boolean overwrite=false ) {
		try {

			endpointName = endpointName ?: configService.getSetting( 'endpoints.defaultForgeBoxEndpoint', 'forgebox' );

			try {
				var oEndpoint = endpointService.getEndpoint( endpointName );
			} catch( EndpointNotFound var e ) {
				error( e.message, e.detail ?: '' );
			}

			var forgebox = oEndpoint.getForgebox();
			var APIToken = oEndpoint.getAPIToken();

			if( !len( APIToken ) ) {
				if( endpointName == 'forgebox' ) {
					error( 'You don''t have a Forgebox API token set.', 'Use "forgebox login" to authenticate as a user.' );
				} else {
					error( 'You don''t have a Forgebox API token set.', 'Use "endpoint login endpointName=#endpointName#" to authenticate as a user.' );
				}
			}
			var modules = {};
			var directory = expandPath( '/commandbox' );
			// package check
			if( packageService.isPackage( directory ) ) {
				modules = packageService
					.buildDependencyHierarchy( directory, 1 )
					.dependencies
					.map( (s,p)=>p.version );
			}
			var userData = forgebox.whoami( APIToken );
			var remoteConfig = forgebox.getConfig( userData.username, APIToken );
			var configSettings = {
				'config' : duplicate( ConfigService.getconfigSettings( noOverrides=true ) ),
				'modules' : modules
			};



			var diffDetails = jsondiff.diff(remoteConfig, configSettings )
				.reduce( ( diffDetails, item )=>{
						diffDetails[ item.type ].append( item );
						return diffDetails;
				}, { add : [], remove : [], change : [] } );

			if( diffDetails.remove.len() ) {
				print.line().boldGreenLine( 'New incoming settings:' );
				diffDetails.remove.each( ( item )=>print.indented( buildPath( item.path ) & ' = ' ).line( item.old ) )
			}

			if( diffDetails.add.len() && overwrite ) {
				print.line().boldRedLine( 'Removed local settings:' );
				diffDetails.add.each( ( item )=>print.indented( buildPath( item.path ) & ' = ' ).line( item.new ) )
			}

			if( diffDetails.change.len() ) {
				print.line().boldYellowLine( 'Changed settings:' );
				diffDetails.change.each( ( item )=>{
					print.indentedLine( buildPath( item.path ) & ' = ' )
						.indentedIndentedRed( 'Old Value: ' ).line( item.new )
						.indentedIndentedGreen( 'New Value: ' ).line( item.old );
				} );
			}

			if( !overwrite ) {
				remoteConfig = JSONService.mergeData( configSettings, remoteConfig );
			}

			if( diffDetails.remove.len() || ( diffDetails.add.len() && overwrite ) ||  diffDetails.change.len() ) {
				configService.setConfigSettings( remoteConfig.config );
				print.line().greenLine( "ClI Settings imported" ).line();
			} else {
				print.greenLine( "All up to to date!").line();
			}

			diffDetails.remove
				.filter( ( item )=>buildPath( item.path ).lCase().startsWith( 'modules.' ) )
				.each( ( item )=>command( 'install' ).params( buildPath( item.path ).listRest( '.' ) & '@' & item.old ).flags( 'system' ).run() )

			diffDetails.change
				.filter( ( item )=>buildPath( item.path ).lCase().startsWith( 'modules.' ) )
				.each( ( item )=>command( 'install' ).params( buildPath( item.path ).listRest( '.' ) & '@' & item.old ).flags( 'system' ).run() )

			if( overwrite ) {
				diffDetails.add
					.filter( ( item )=>buildPath( item.path ).lCase().startsWith( 'modules.' ) )
					.each( ( item )=>command( 'uninstall' ).params( buildPath( item.path ).listRest( '.' ) ).flags( 'system' ).run() )
			}

		} catch( forgebox var e ) {
			// This can include "expected" errors such as "Email already in use"
			error( e.message, e.detail );
		}

	}

	function buildPath( tokens ) {
		return tokens.reduce( ( path, item )=>{
			if( isNumeric( item ) ) {
				return path & "[#item#]";
			}
			return path.listAppend( item, '.' );
		}, '' );
	}

	function endpointNameComplete() {
		return getInstance( 'endpointService' ).forgeboxEndpointNameComplete();
	}

}
