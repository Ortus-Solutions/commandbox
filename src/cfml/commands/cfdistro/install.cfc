/**
 * download and install cfdistro
 **/
component persistent="false" extends="commandbox.system.BaseCommand" {

	function init(shell) {
		variables.shell = shell;
		reader = shell.getReader();
		thisdir = getDirectoryFromPath(getMetadata(this).path);
		home = thisdir & "/home";
		buildprops = {
			"cfdistro.repo.local.path":shell.getArtifactsDir(),
			"basedir":shell.pwd(),
			"server.jvm.args":"-Xms256M -Xmx326M -XX:PermSize=128M -XX:MaxPermSize=128M  -Djava.net.preferIPv4Stack=true",
			"mappings.list":"/:#shell.pwd()#"
		}
		return this;
	}

	function run(String version="latest")  {
		http url="http://cfmlprojects.org/artifacts/cfdistro/latest/cfdistro.zip" file="#thisdir#/cfdistro.zip";
		zip action="unzip" file="#thisdir#/cfdistro.zip" destination="#home#";
		return "installed";
	}

}