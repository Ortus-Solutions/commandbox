package luceecli;

import java.io.File;
import java.io.IOException;
import java.io.ByteArrayOutputStream;
import java.io.PrintStream;
import java.util.HashMap;
import java.util.Map;
import javax.servlet.ServletException;
import javax.servlet.jsp.JspException;

import lucee.loader.engine.CFMLEngine;
import lucee.loader.engine.CFMLEngineFactory;
import lucee.loader.util.Util;

public class CLIMain {
/**
 * Config
 * 
 * webroot - webroot directory
 * servlet-name - name of the servlet (default:CFMLServlet)
 * server-name - server name (default:localhost)
 * uri - host/scriptname/query
 * cookie - cookies (same pattern as query string)
 */
	/**
	 * @param uri 
	 * @param debug 
	 * @param args
	 * @throws JspException 
	 */
	public static void run(File webroot, File configServerDir, File configWebDir, String uri, boolean debug) throws ServletException, IOException, JspException {
		Map<String, String> config=new HashMap<String, String>();
		config.put("webroot",webroot.getPath());
		config.put("server-config", configServerDir.getAbsolutePath());
		config.put("web-config", configWebDir.getAbsolutePath());
		config.put("uri", new File(uri).toURI().toURL().toExternalForm().replaceAll("file:/(\\w:)", "file://$1"));
		String servletName=config.get("servlet-name");
		if(Util.isEmpty(servletName,true))servletName="CFMLServlet";
		
		Map<String,Object> attributes=new HashMap<String, Object>();
		Map<String, String> initParameters=new HashMap<String, String>();
		initParameters.put("lucee-server-directory", configServerDir.getAbsolutePath());
		initParameters.put("configuration", configWebDir.getAbsolutePath());
		
		CLIContext servletContext = new CLIContext(webroot, configWebDir, attributes, initParameters, 1, 0);
		ServletConfigImpl servletConfig = new ServletConfigImpl(servletContext, servletName);
		PrintStream printStream = new PrintStream(new ByteArrayOutputStream());
		PrintStream origOut = System.out;
		// hide engine startup stuff
		if(!debug) {
			System.setOut(printStream);
		}
		CFMLEngine engine = null;
		try{
			engine = CFMLEngineFactory.getInstance(servletConfig);
		} catch (Exception e) {
			e.printStackTrace();
		} finally {
			System.setOut(origOut);
		}
		printStream.close();
		engine.cli(config,servletConfig);
	}
	/**
	 * @param args
	 * @throws JspException 
	 */
	public static void main(String[] args) throws ServletException, IOException, JspException {
		Map<String,String> config=toMap(args);
		Boolean debug = false;
		
		File currentDir = new File(CLIMain.class.getProtectionDomain().getCodeSource().getLocation().getPath()).getParentFile();
		File libDir=new File(currentDir.getPath()).getCanonicalFile();
		
		// libs dir
		String strLibs=config.get("libs");
		if(strLibs != null && strLibs.length() != 0) {
			libDir=new File(strLibs);
		}

		// debug
		String strDebug=config.get("debug");
		if(!Util.isEmpty(strDebug,true)) debug = true;
		
		if(debug) System.out.println("libDir dir" + libDir.getPath());

		// webroot
		String strRoot=config.get("webroot");
		File root;
		if(Util.isEmpty(strRoot,true)) {
			//root=new File("./").getCanonicalFile();
			root=new File("/").getCanonicalFile();
		} else {
			root=new File(strRoot);
		}
		config.put("webroot",root.getPath());
		//root.mkdirs();

		String strServerroot=config.get("server-config");
		File serverRoot;
		if(Util.isEmpty(strServerroot,true)) {
			serverRoot=new File(libDir.getParentFile(),"server");
			//serverRoot=libDir;
		} else {
			serverRoot=new File(strServerroot);
		}
		config.put("server-config", serverRoot.getAbsolutePath());
		//serverRoot.mkdirs();
		
		String strWebroot=config.get("web-config");
		File webConfig;
		if(Util.isEmpty(strWebroot,true)) {
			webConfig=new File(libDir.getParentFile(),"server/lucee-web");
		} else {
			webConfig=new File(strWebroot);
		}
		config.put("web-config", webConfig.getAbsolutePath());
		//webRoot.mkdirs();

		// if no uri arg, use first non -dashed arg
		String strUri=config.get("uri");
		if(strUri == null || strUri.length() == 0) {
			String raw;
			if(args!=null)for(int i=0;i<args.length;i++){
				raw=args[i].trim();
				if(raw.length() == 0) continue;
				if(!raw.startsWith("-")) {
					File rawFile = new File(raw).getCanonicalFile();
					// otherwise it begins a command line
					if(rawFile.exists()){
						raw = rawFile.getPath();
						config.put("uri",raw);
					}
					break;
				}
			}
		}
		// fix for windows. remove drive letter.  TODO: find out why this is needed
		config.put("uri", new File(config.get("uri")).toURI().toURL().toExternalForm().replaceAll("file:/(\\w:)", "file://$1"));
		// hack to prevent . being picked up as the system path (jacob.x.dll)
		if(System.getProperty("java.library.path") == null) {
			System.setProperty("java.library.path",libDir.getPath());
		} else {
			System.setProperty("java.library.path",libDir.getPath() + ":" + System.getProperty("java.library.path"));
		}
		if(debug) {
			System.out.println("Config:" + config);
		}
		// servletNane
		String servletName=config.get("servlet-name");
		if(Util.isEmpty(servletName,true))servletName="CFMLServlet";
		
		Map<String,Object> attributes=new HashMap<String, Object>();
		Map<String, String> initParameters=new HashMap<String, String>();
		initParameters.put("lucee-server-directory", serverRoot.getAbsolutePath());
		initParameters.put("configuration", webConfig.getAbsolutePath());
		
		CLIContext servletContext = new CLIContext(root, webConfig, attributes, initParameters, 1, 0);
		ServletConfigImpl servletConfig = new ServletConfigImpl(servletContext, servletName);
		PrintStream printStream = new PrintStream(new ByteArrayOutputStream());
		PrintStream origOut = System.out;
		// hide engine startup stuff
		if(!debug) {
			System.setOut(printStream);
		}
		CFMLEngine engine = null;
		try{
			engine = CFMLEngineFactory.getInstance(servletConfig);
		} catch (Exception e) {
			e.printStackTrace();
		} finally {
			System.setOut(origOut);
		}
		printStream.close();

		engine.cli(config,servletConfig);

	}
// java lucee-cli.jar -config=.../lucee-web.xml.cfm -uri=/susi/index.cfm?test=1 -form=name=susi -cgi=user_agent=urs -output=.../test.txt ...

	private static Map<String, String> toMap(String[] args) {
		int index;
		Map<String, String> config=new HashMap<String, String>();
		String raw,key,value;
		if(args!=null)for(int i=0;i<args.length;i++){
			raw=args[i].trim();
			if(Util.isEmpty(raw, true)) continue;
			if(raw.startsWith("-"))raw=raw.substring(1).trim();
			index=raw.indexOf('=');
			if(index==-1) {
				key=raw;
				value="";
			}
			else {
				key=raw.substring(0,index).trim();
				value=raw.substring(index+1).trim();
			}
			config.put(key.toLowerCase(), value);
		}
		return config;
	}
}
