component {
	
	this.name="mxu";
	this.sessionmanagement="true";
	
	
	this.mappings[ '/commandbox' ] = '../src/cfml';
	this.mappings[ '/wirebox' ] = '../src/cfml/system/wirebox';
	
	function onApplicationStart() {		
		new wirebox.system.ioc.Injector( 'commandbox.system.config.WireBox' );
		return true;
	}
		
}