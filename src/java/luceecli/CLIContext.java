/**
 * Copyright (C) 2012 Ortus Solutions, Corp
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3.0 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library.
 */
package luceecli;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.Enumeration;
import java.util.EventListener;
import java.util.Map;
import java.util.Set;

import javax.servlet.Filter;
import javax.servlet.FilterRegistration;
import javax.servlet.FilterRegistration.Dynamic;
import javax.servlet.RequestDispatcher;
import javax.servlet.Servlet;
import javax.servlet.ServletContext;
import javax.servlet.ServletException;
import javax.servlet.ServletRegistration;
import javax.servlet.SessionCookieConfig;
import javax.servlet.SessionTrackingMode;
import javax.servlet.descriptor.JspConfigDescriptor;

import lucee.cli.util.EnumerationWrapper;

@SuppressWarnings( "unchecked" )
public class CLIContext implements ServletContext{
	private final Map< String, Object >	attributes;
	private final int					majorVersion;
	private final int					minorVersion;
	private final Map< String, String >	parameters;
	private final File					root;
	private final File					webInf;

	public CLIContext( File root, File webInf,
			Map< String, Object > attributes, Map< String, String > parameters,
			int majorVersion, int minorVersion ){
		this.root = root;
		this.webInf = webInf;
		this.attributes = attributes;
		this.parameters = parameters;
		this.majorVersion = majorVersion;
		this.minorVersion = minorVersion;
	}

	@Override
	public Dynamic addFilter( String arg0, Class< ? extends Filter > arg1 ){
		return null;
	}

	@Override
	public Dynamic addFilter( String arg0, Filter arg1 ){
		return null;
	}

	@Override
	public Dynamic addFilter( String arg0, String arg1 ){
		return null;
	}

	@Override
	public void addListener( Class< ? extends EventListener > arg0 ){
	}

	@Override
	public void addListener( String arg0 ){
	}

	@Override
	public < T extends EventListener >void addListener( T arg0 ){
	}

	@Override
	public javax.servlet.ServletRegistration.Dynamic addServlet( String arg0,
			Class< ? extends Servlet > arg1 ){
		return null;
	}

	@Override
	public javax.servlet.ServletRegistration.Dynamic addServlet( String arg0,
			Servlet arg1 ){
		return null;
	}

	@Override
	public javax.servlet.ServletRegistration.Dynamic addServlet( String arg0,
			String arg1 ){
		return null;
	}

	@Override
	public < T extends Filter >T createFilter( Class< T > arg0 )
			throws ServletException{
		return null;
	}

	@Override
	public < T extends EventListener >T createListener( Class< T > arg0 )
			throws ServletException{
		return null;
	}

	@Override
	public < T extends Servlet >T createServlet( Class< T > arg0 )
			throws ServletException{
		return null;
	}

	@Override
	public void declareRoles( String ... arg0 ){
	}

	/**
	 * @see javax.servlet.ServletContext#getAttribute(java.lang.String)
	 */
	@Override
	public Object getAttribute( String key ){
		return this.attributes.get( key );
	}

	/**
	 * @see javax.servlet.ServletContext#getAttributeNames()
	 */
	@Override
	public Enumeration< String > getAttributeNames(){
		return new EnumerationWrapper( this.attributes );
	}

	@Override
	public ClassLoader getClassLoader(){
		return null;
	}

	@Override
	public ServletContext getContext( String key ){
		return this;
	}

	@Override
	public String getContextPath(){
		return null;
	}

	@Override
	public Set< SessionTrackingMode > getDefaultSessionTrackingModes(){
		return null;
	}

	@Override
	public int getEffectiveMajorVersion(){
		return 0;
	}

	@Override
	public int getEffectiveMinorVersion(){
		return 0;
	}

	@Override
	public Set< SessionTrackingMode > getEffectiveSessionTrackingModes(){
		return null;
	}

	@Override
	public FilterRegistration getFilterRegistration( String arg0 ){
		return null;
	}

	@Override
	public Map< String, ? extends FilterRegistration > getFilterRegistrations(){
		return null;
	}

	/**
	 * @see javax.servlet.ServletContext#getInitParameter(java.lang.String)
	 */
	@Override
	public String getInitParameter( String key ){
		return this.parameters.get( key );
	}

	/**
	 * @see javax.servlet.ServletContext#getInitParameterNames()
	 */
	@Override
	public Enumeration< String > getInitParameterNames(){
		return new EnumerationWrapper( this.parameters );
	}

	@Override
	public JspConfigDescriptor getJspConfigDescriptor(){
		return null;
	}

	/**
	 * @see javax.servlet.ServletContext#getMajorVersion()
	 */
	@Override
	public int getMajorVersion(){
		return this.majorVersion;
	}

	/**
	 * @see javax.servlet.ServletContext#getMimeType(java.lang.String)
	 */
	@Override
	public String getMimeType( String file ){
		throw notSupported( "getMimeType(String file)" );
		// TODO
		// return ResourceUtil.getMymeType(config.getResource(file),null);
	}

	/**
	 * @see javax.servlet.ServletContext#getMinorVersion()
	 */
	@Override
	public int getMinorVersion(){
		return this.minorVersion;
	}

	@Override
	public RequestDispatcher getNamedDispatcher( String name ){
		throw notSupported( "getNamedDispatcher(String name)" );
	}

	public File getRealFile( String realpath ){
		if( realpath.startsWith( "/WEB-INF" ) ) {
			return new File( this.webInf, realpath );
		}
		File relPath = new File( this.root, realpath );
		if( relPath.exists() ) {
			return relPath;
		}
		return new File( realpath );
	}

	/**
	 * @see javax.servlet.ServletContext#getRealPath(java.lang.String)
	 */
	@Override
	public String getRealPath( String realpath ){
		return getRealFile( realpath ).getAbsolutePath();
	}

	@Override
	public RequestDispatcher getRequestDispatcher( String path ){
		throw notSupported( "getNamedDispatcher(String name)" );
	}

	/**
	 * @see javax.servlet.ServletContext#getResource(java.lang.String)
	 */
	@Override
	public URL getResource( String realpath ) throws MalformedURLException{
		File file = getRealFile( realpath );
		return file.toURI().toURL();
	}

	/**
	 * @see javax.servlet.ServletContext#getResourceAsStream(java.lang.String)
	 */
	@Override
	public InputStream getResourceAsStream( String realpath ){
		try {
			return new FileInputStream( getRealFile( realpath ) );
		} catch ( IOException e ) {
			return null;
		}
	}

	@Override
	public Set< String > getResourcePaths( String realpath ){
		throw notSupported( "getResourcePaths(String realpath)" );
	}

	public File getRoot(){
		return this.root;
	}

	@Override
	public String getServerInfo(){
		// deprecated
		throw notSupported( "getServlet()" );
	}

	@Override
	public Servlet getServlet( String arg0 ) throws ServletException{
		// deprecated
		throw notSupported( "getServlet()" );
	}

	@Override
	public String getServletContextName(){
		// can return null
		return null;
	}

	@Override
	public Enumeration< String > getServletNames(){
		// deprecated
		throw notSupported( "getServlet()" );
	}

	@Override
	public ServletRegistration getServletRegistration( String arg0 ){
		return null;
	}

	@Override
	public Map< String, ? extends ServletRegistration > getServletRegistrations(){
		return null;
	}

	@Override
	public Enumeration< Servlet > getServlets(){
		// deprecated
		throw notSupported( "getServlet()" );
	}

	@Override
	public SessionCookieConfig getSessionCookieConfig(){
		return null;
	}

	@Override
	public String getVirtualServerName(){
		return null;
	}

	/**
	 * @see javax.servlet.ServletContext#log(java.lang.Exception,
	 *      java.lang.String)
	 */
	@Override
	public void log( Exception e, String msg ){
		log( msg, e );
	}

	/**
	 * @see javax.servlet.ServletContext#log(java.lang.String)
	 */
	@Override
	public void log( String msg ){
		log( msg, null );
	}

	/**
	 * @see javax.servlet.ServletContext#log(java.lang.String,
	 *      java.lang.Throwable)
	 */
	@Override
	public void log( String msg, Throwable t ){// TODO better
		if( t == null ) {
			System.out.println( msg );
		} else {
			System.out.println( msg + ":\n" + t.getMessage() );
			// if(t==null)log.log(Log.LEVEL_INFO, "ServletContext", msg);
			// else log.log(Log.LEVEL_ERROR, "ServletContext",
			// msg+":\n"+ExceptionUtil.getStacktrace(t,false));
		}
	}

	private RuntimeException notSupported( String method ){
		throw new RuntimeException( new ServletException( "method " + method
				+ " not supported" ) );
	}

	/**
	 * @see javax.servlet.ServletContext#removeAttribute(java.lang.String)
	 */
	@Override
	public void removeAttribute( String key ){
		this.attributes.remove( key );
	}

	/**
	 * @see javax.servlet.ServletContext#setAttribute(java.lang.String,
	 *      java.lang.Object)
	 */
	@Override
	public void setAttribute( String key, Object value ){
		this.attributes.put( key, value );
	}

	@Override
	public boolean setInitParameter( String arg0, String arg1 ){
		return false;
	}

	@Override
	public void setSessionTrackingModes( Set< SessionTrackingMode > arg0 ){
	}

}
