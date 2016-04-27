component {

	this.name="CommandBox Testing Harness - " & hash( getCurrentTemplatePath() );
	this.applicationTimeout = createTimeSpan( 0, 0, 5, 0 );
	this.sessionTimeout = createTimeSpan( 0, 0, 5, 0 );
	this.sessionmanagement="true";

	// mappings

	boolean function onRequestStart( required targetPage ){
		new wirebox.system.ioc.Injector( 'tests.config.WireBox' );
		return true;
	}

	function onRequestEnd( required targetPage ){
		structDelete( application, "wirebox" );
	}

}