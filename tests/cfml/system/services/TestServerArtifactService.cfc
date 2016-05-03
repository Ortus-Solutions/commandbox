component extends="mxunit.framework.TestCase" {

  public void function beforeTests()  {
    workDir = expandPath("/tests/work");
    resourceDir = expandPath("/tests/resource");
    if(directoryExists(workDir)){
    	directoryDelete(workDir,true);
    }
    directoryCreate(workDir);
  }

  public void function setUp()  {
    //application.wirebox.clearSingletons();
    setting requesttimeout="240";
    shell = application.wirebox.getInstance( 'Shell' );
    serverArtifactService = application.wirebox.getInstance( 'ServerArtifactService' );
    workDir = expandPath("/tests/work");
  }

  public void function testInstallLucee()  {
    var artifacts = serverArtifactService.install(cfengine="lucee", basedirectory=workDir);
    assertTrue(artifacts.endsWith("4.5.2.018"));
    request.debug(artifacts);
  }

  public void function testInstallLucee5()  {
    var artifacts = serverArtifactService.install(cfengine="lucee@5.0.0.243-SNAPSHOT", basedirectory=workDir);
    assertTrue(artifacts.endsWith("5.0.0.243-SNAPSHOT"));
    request.debug(artifacts);
  }

  public void function testInstallAdobe()  {
    var artifacts = serverArtifactService.install(cfengine="adobe", basedirectory=workDir);
    assertTrue(artifacts.endsWith("11.0.0.289974"));
    request.debug(artifacts);
  }

  public void function testInstallAdobe9()  {
    var artifacts = serverArtifactService.install(cfengine="adobe@9.0.2.282541", basedirectory=workDir);
    assertTrue(artifacts.endsWith("9.0.2.282541"));
    request.debug(artifacts);
  }

  public void function testInstallRailo()  {
    var artifacts = serverArtifactService.install(cfengine="railo", basedirectory=workDir);
    assertTrue(artifacts.endsWith("4.2.1.008"));
    request.debug(artifacts);
  }

  public void function testCheckVersion()  {
    var version = serverArtifactService.checkVersion(cfengine="railo", version="4");
    assertEquals("4.2.1.008",version);
    version = serverArtifactService.checkVersion(cfengine="railo", version="4.2");
    assertEquals("4.2.1.008",version);
    version = serverArtifactService.checkVersion(cfengine="railo", version="4.2.1");
    assertEquals("4.2.1.008",version);
    version = serverArtifactService.checkVersion(cfengine="railo", version="");
    assertEquals("4.2.1.008",version);

    version = serverArtifactService.checkVersion(cfengine="lucee", version="4");
    assertEquals("4.5.2.018",version);
    version = serverArtifactService.checkVersion(cfengine="lucee", version="4.5");
    assertEquals("4.5.2.018",version);
    version = serverArtifactService.checkVersion(cfengine="lucee", version="5");
    assertEquals("5.0.0.236-SNAPSHOT",version);
    version = serverArtifactService.checkVersion(cfengine="lucee", version="");
    assertEquals("4.5.2.018",version);

    version = serverArtifactService.checkVersion(cfengine="adobe", version="9");
    assertEquals("9.0.2.282541",version);
    version = serverArtifactService.checkVersion(cfengine="adobe", version="10");
    assertEquals("10.0.12.286680",version);
    version = serverArtifactService.checkVersion(cfengine="adobe", version="11");
    assertEquals("11.0.0.289974",version);
    version = serverArtifactService.checkVersion(cfengine="adobe", version="");
    assertEquals("11.0.0.289974",version);
  }

  public void function testConfigureRailo()  {
  	var source = resourceDir & "/railo/web.xml";
  	var destination = workDir & "/railo-web.xml";
    var artifacts = serverArtifactService.configureWebXML("railo",source, destination);
    debug(artifacts);
  }

  public void function testConfigureLucee()  {
  	var source = resourceDir & "/lucee/web.xml";
  	var destination = workDir & "/lucee-web.xml";
    var artifacts = serverArtifactService.configureWebXML("lucee",source, destination);
    debug(artifacts);
  }

}