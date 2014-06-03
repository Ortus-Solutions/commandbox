component {
	
	this.name="CommandBox Testing Harness - " & hash( getCurrentTemplatePath() );
	this.applicationTimeout = createTimeSpan( 0, 0, 5, 0 );
	this.sessionTimeout = createTimeSpan( 0, 0, 5, 0 );
	this.sessionmanagement="true";
	
	// mappings	
	this.mappings[ "/tests" ] = getDirectoryFromPath( getCurrentTemplatePath() );
	this.mappings[ '/commandbox' ] = '../src/cfml';
	this.mappings[ '/wirebox' ] 	= '../src/cfml/system/wirebox';
	this.mappings[ '/mxunit' ] 		= '../src/cfml/system/wirebox/system/compat';
	
	function onApplicationStart() {
		new wirebox.system.ioc.Injector( 'commandbox.system.config.WireBox' );
		return true;
	}
		
}