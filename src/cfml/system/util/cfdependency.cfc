component {

  cfdependency.version = "2.0.0";

  function init(localRepo=getDirectoryFromPath(getMetadata(this).path) & "/repo", repositories="default", javatools = false) {
    localRepositoryPath = localRepo;
    remotes = [];
    paths = {};
    thisdir = getDirectoryFromPath(getMetadata(this).path);
    if(isSimpleValue(repositories) && repositories == "default") {
      addDefaultRepositories();
    } else {
      for(var repo in repositories){
        addRemoteRepository(repo.name,repo.url,repo.type);
      }
    }
    if(javatools) {
      get(["cfml:javatools:zip:1.1.0"]);
    }
  }
/*
 * AETHER
 **/

  function onMissingMethod( methodName, methodArguments ) {
    if(isNull(aether)) {
      if(!fileExists(localRepositoryPath & "org/cfmlprojects/aether/#cfdependency.version#/aether-#cfdependency.version#.jar")) {
        get(["cfml:javatools:zip:1.1.0"]);
        get(["org.cfmlprojects:aether:jar:#cfdependency.version#"]);
      }
      javaloader = create("cfml:javatools","LibraryLoader").init(pathlist=thisdir & "aether/lib/", id="aether-classloader");
      aether = new aether.Aether(localPath=localRepositoryPath, javaloader=javaloader, repositories=remotes);
    }
    return aether.callMethod(argumentCollection=arguments);
  }

/*
 * /AETHER
 **/

  public function setLocalRepositoryPath(required path) {
    localRepositoryPath = path;
  }

  public function create(required dependency, required componentName, args) {
//    return new "#paths[dependency]#.#componentName#" (argumentColection = args);
    return createObject("#paths[dependency].cfcPath#.#componentName#");
  }
  public function dirFor(required dependency) {
    return createObject("#paths[dependency].directory#");
  }

  public function get(required array dependencies, dest="", unzip = "", transitive=true) {
    var artifacts = simpleResolve(dependencies=dependencies,transitive=transitive);
    var managedDest = dest == "" ? true : false;
    var directories = "";
    if (dest == "") {
      dest = expandPath("/WEB-INF/cfdependency");
      if(!directoryExists(dest)) {
        directoryCreate(dest);
      }
    }
    for(var artifact in artifacts) {
      var file = artifact.file;
      var versionSafe = rereplace(artifact.version,"[\.-]","_","all");
      var groupDir = replace(artifact.groupId,".","/","all");
      var todir = managedDest ? dest & "/#groupDir#/#artifact.artifactId#/#versionSafe#" : dest;
      artifact.directory = todir;
      directories = listContains(directories,todir) ? directories : listAppend(directories,todir);
      paths["#artifact.groupId#:#artifact.artifactId#"] = {
        cfcPath = "WEB-INF.cfdependency.#artifact.groupId#.#artifact.artifactId#.#versionSafe#",
        directory = todir
      };
      if(!directoryExists(todir)) {
        directoryCreate(todir,true);
      }
      if(file.endsWith(".zip") && unzip == "") {
        unzip = true;
      }
      unzip = unzip == "" ? false : unzip;
      if(unzip && zipContentDiffers(file,dest)) {
        zip action="unzip" file="#file#" destination="#todir#" overwrite=true;
      } else {
        fileCopy(file,todir);
      }
    }
    return {artifacts = artifacts, directories = directories};
  }

  public function simpleResolve(required dependencies, Boolean transitive = true, scope="runtime") {
    var artifacts = [];
    if(isArray(dependencies)) {
      for(var afact in dependencies) {
        var arrayFiles = simpleResolve(afact,transitive,scope);
        for(var file in arrayFiles) {
          arrayAppend(artifacts,file);
        }
      }
      return artifacts;
    }
    var artifact = toArtifact(dependencies);
    var artifactPom = toPomArtifact(dependencies);
    var filePath = getPathForLocalArtifact(dependencies);
    artifact.file = filePath;
    if(artifact.version.endsWith("SNAPSHOT") || !fileExists(filePath) || !hashMatch(filePath)) {
      var pomfile = getRemoteArtifact(artifactPom);
      artifact.file = getRemoteArtifact(dependencies);
      arrayAppend(artifacts,artifact);
      if(transitive) {
        var mavenData = xmlParse(pomFile);
        var deps = xmlSearch(mavendata,"//*[name() = 'project']/*[name()='dependencies']/*[name()='dependency']");
        for(var depXml in deps) {
          var dep = {};
          for(var el in depXML.XmlChildren) {
            dep[el.xmlName] = el.xmlText;
          }
          if(!isNull(dep.version) && (isNull(dep.scope) || dep.scope == scope)) {
            var depArtifact = toArtifact(dep);
            depArtifact.file = getRemoteArtifact(depArtifact);
            arrayAppend(artifacts, depArtifact);
          }
        }
      }
    } else {
      arrayAppend(artifacts,artifact);
    }
    return artifacts;
  }

  public function addRemoteRepository(required name,required repourl, type="default"){
    var repo = { name : name, type: type, repourl: repourl };
    arrayAppend(variables.remotes,repo);
    if(!isNull(aether))
      aether.addRemoteRepository(name,repourl,type);
  }

  private function addDefaultRepositories(){
    var userHome = createObject("java","java.lang.System").getProperty("user.home");
    addRemoteRepository( "cfdistro", "file://#userHome#/cfdistro/artifacts/" );
    addRemoteRepository( "cfmlprojects", "http://cfmlprojects.org/artifacts/" );
    addRemoteRepository( "central", "http://repo1.maven.org/maven2/" );
  }

  public function toArtifact( Required coords, Struct properties={} ) {
    var artifact = {groupId:"", artifactId:"", extension:"jar", classifier:"", version:""};
    if(isStruct(coords)) {
      structAppend(artifact,coords);
      return artifact;
    }
    var java = {
      Pattern : createObject("java","java.util.regex.Pattern")
    };
    var p = java.Pattern.compile( "([^: ]+):([^: ]+)(:([^: ]*)(:([^: ]+))?)?:([^: ]+)" );
    var m = p.matcher( coords );
    if ( !m.matches() ){
        throw( message = "Bad artifact coordinates " & coords
            & ", expected format is <groupId>:<artifactId>[:<extension>[:<classifier>]]:<version>" );
    }
    artifact.groupId = m.group( 1 );
    artifact.artifactId = m.group( 2 );
    artifact.extension = isEmpty(m.group( 4 )) ? "jar" : m.group( 4 );
    artifact.type = artifact.extension;
    artifact.classifier = isEmpty(m.group( 6 )) ? "" : m.group( 6 );
    artifact.version = m.group( 7 );
    artifact.file = "";
    artifact.properties = properties;
    return artifact;
  }

  public function toPomArtifact( required artifact ) {
    artifact = toArtifact(artifact);
    var pom = duplicate(artifact);
    pom.extension = "pom";
    pom.type = artifact.extension;
    pom.classifier = "";
    return pom;
  }

  public function getPathForArtifact( Required artifact ) {
    artifact = toArtifact(artifact);
    var slashGroupId = replace( artifact.groupId, ".", "/", "all" );
    var classifierPath = artifact.classifier == "" ? "" : "-#artifact.classifier#";
    var artifactPath = "#slashGroupId#/#artifact.artifactId#/#artifact.version#/#artifact.artifactId#-#artifact.version##classifierPath#.#artifact.extension#";
    return artifactPath;
  }

  public function getPathForLocalArtifact( Required artifact ) {
    var artifactPath = localRepositoryPath & "/" & getPathForArtifact(artifact);
    return artifactPath;
  }

  private function getRemoteArtifact(artifact) {
    artifact = toArtifact(artifact);
    var filePath = getPathForArtifact(artifact);
    var mavenMetaPath = getDirectoryFromPath(filePath).replaceAll(artifact.version&"\/$","") & "maven-metadata.xml";
    var mavenMetaFile = getRemoteFile(mavenMetaPath);
    mavenMetaPath = getDirectoryFromPath(filePath) & "maven-metadata.xml";
    try {
	    mavenMetaFile = getRemoteFile(mavenMetaPath);
    } catch(any e) {
      // not all artifacts have a maven-metadata.xml, but snapshots should for sure
    }
    if(artifact.version.toUpperCase().endsWith("SNAPSHOT")) {
        var snapshot = getSnapshotVersion(mavenMetaFile);
        filePath = rereplace(filePath,"SNAPSHOT\.(.+)","#snapshot#.\1");
        getRemoteFile(filePath);
    } else {
      getRemoteFile(filePath);
    }
    return localRepositoryPath & "/" & filePath;
  }

  private function getRemoteFile(filepath) {
    var localPath = localRepositoryPath & "/" & filepath;
    logMessage( "resolving #filepath# (#localPath#)" );
    if(hashMatch(localPath)) {
      logMessage( "already resolved #filepath# (#localPath#)" );
      return localPath;
    }
    for(var repository in remotes) {
      logMessage( "Trying remote repository #repository.name#..." );
      var fileUrl = repository.repourl & filepath;
      logMessage( "Downloading #fileUrl#..." );
      if(!directoryExists(getDirectoryFromPath(localPath)))
        directoryCreate(getDirectoryFromPath(localPath));
      httpGet("#fileUrl#.md5","#localPath#.md5");
      httpGet("#fileUrl#.sha1","#localPath#.sha1");
//      createObject("java","java.lang.System").out.println("Getting #fileURL# to #localPath#");
      httpGet("#fileUrl#","#localPath#");
      if( hashMatch(localPath)) {
        break;
      } else {
        if(fileExists(localPath)) {
          var hashes = lcase(serializeJSON(getHash(localPath)));
          logMessage( "incorrect hash for #localPath# #hashes#" );
        }      
      }
    }
    if( !hashMatch(localPath)) {
      var hashes = lcase(serializeJSON(getHash(localPath)));
      logMessage( "could not get #filePath# or hash incorrect #hashes#" );
      throw(message="could not get #filePath# or hash incorrect #hashes#",detail=messages.toString());
    }
    return localPath;
  }

  public function httpGet(uri,toFile){
  	var httpResult = "";
    if(uri.startsWith("file:")) {
      if(fileExists(uri)) {
        fileCopy(uri,toFile);
        logMessage("Copied #uri# to #toFile#");
      }
    } else {
      http url=uri file=toFile result="httpResult" timeout="300" getAsBinary="true";
      if(httpResult.status_code != 200) {
        fileDelete(toFile);
        logMessage("#httpResult.statuscode# error for #uri#");
      } else {
        logMessage("Downloaded #uri# to #toFile#");
      }
    }
  }

  private function getSnapshotVersion(mavenMetaFile) {
    var mavenData = xmlParse(mavenMetaFile);
    var snapshots = xmlSearch(mavendata,"//*[name() = 'metadata']/*[name() = 'versioning']/*[name()='snapshot']");
    return snapshots[1].XmlChildren[1].XmlText & "-" & snapshots[1].XmlChildren[2].XmlText;
  }

  private Boolean function hashMatch(filePath) {
  	var hashes = getHash(filePath);
  	var fileHash = hashes.fileHash;
  	var goodHash = hashes.goodHash;
    if( fileHash != "" && fileHash == goodHash) {
      return true;
    }
    return false;
  }

  private any function getHash(filePath) {
    if(fileExists("#filePath#.sha1") && fileExists(filePath)) {
      var fileHash = lcase(hash(fileReadBinary(filePath),"sha1"));
      var goodHash = lcase(fileRead(filePath & ".sha1"));
    } else if(fileExists("#filePath#.md5") && fileExists(filePath)) {
      var fileHash = lcase(hash(fileReadBinary(filePath),"md5"));
      var goodHash = lcase(fileRead(filePath & ".md5"));
    } else {
    	var fileHash = "";
    	var goodHash = "";
    }
    return {fileHash:fileHash,goodHash:goodHash};
  }

  private Boolean function hasValidHash(artifact) {
    var filePath = getPathForLocalArtifact(artifact);
    return hashMatch(filePath);
  }

  public function zipContentDiffers(zipfile,targetDirectory) {
    var zf = createObject("java","java.util.zip.ZipFile").init(zipFile);
    var e = zf.entries();
    while (e.hasMoreElements()) {
      var ze = e.nextElement();
      if(!fileExists(targetDirectory & "/#ze.getName()#")) {
        return true;
      }
      if(!ze.isDirectory()) {
        var crc = crc32(targetDirectory & "/#ze.getName()#");
        if(ze.getCrc() != crc) {
          return true;
        }
      }
    }
    zf.close();
    return false;
  }

 function crc322(file) {
    var input = fileReadBinary(file);
    var bytes = input;
    var java = {
      CRC32 = createObject("java","java.util.zip.CRC32")
    };
    var checksum = java.CRC32.init();
    checksum.reset();
    checksum.update(bytes, 0, len(bytes));
    var checksumValue = checksum.getValue();
    return checksumValue;
  }


  public function crc32(file) {
    var java = {
      CRC32 = createObject("java","java.util.zip.CRC32")
      ,BufferedInputStream = createObject("java","java.io.BufferedInputStream")
      ,ByteArrayOutputStream = createObject("java","java.io.ByteArrayOutputStream")
      ,ReflectArray = createObject("java","java.lang.reflect.Array")
      ,FileInputStream = createObject("java","java.io.FileInputStream")
      ,File = createObject("java","java.io.File")
      ,Long = createObject("java","java.lang.Long")
    };
    var bis = java.BufferedInputStream.init(java.FileInputStream.init(java.File.init(arguments.file)));
    var read = 0;
    var checksum = java.CRC32.init();
    var buffer = java.ByteArrayOutputStream.init().toByteArray().getClass().getComponentType();
    buffer = java.ReflectArray.newInstance(buffer, 4096);
    while ((read = bis.read(buffer)) != -1) {
      checksum.update(buffer, 0, read);
    }
    bis.close();
    return checksum.getValue();
  }

  public function logMessage(message){
    if(isNull(messages)) {
      messages = [];
    }
    arrayAppend(messages,message);
   }

  public function getInstance(){
    if ( instance == null ){
      lock type="exclusive" timeout="3" {
        if ( isNull(instance) ){
            instance = new Manager();
        }
      }
    }
    return instance;
  }

  public function dropInstance(){
    instance = javacast("null","");
  }

}