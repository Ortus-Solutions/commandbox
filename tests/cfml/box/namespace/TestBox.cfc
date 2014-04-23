component name="TestShell" extends="mxunit.framework.TestCase" {

	public void function setUp()  {
		var shell = new cfml.box.Shell();
		variables.box = new cfml.box.namespace.box(shell);
	}

	public void function testInit()  {
		box.init();
	}

	public void function testUpdate()  {
		box.update();
	}


}