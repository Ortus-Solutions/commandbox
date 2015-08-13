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

import java.util.Enumeration;

import javax.servlet.ServletConfig;
import javax.servlet.ServletContext;

public class ServletConfigImpl implements ServletConfig{

	private final ServletContext	context;
	private final String			servletName;

	/**
	 * Constructor of the class
	 * 
	 * @param parameters
	 * @param attrs
	 * @param servletName
	 */
	public ServletConfigImpl( CLIContext context, String servletName ){
		this.servletName = servletName;
		this.context = context;
	}

	/**
	 * @see javax.servlet.ServletConfig#getInitParameter(java.lang.String)
	 */
	@Override
	public String getInitParameter( String key ){
		return this.context.getInitParameter( key );
	}

	/**
	 * @see javax.servlet.ServletConfig#getInitParameterNames()
	 */
	@Override
	public Enumeration< String > getInitParameterNames(){
		return this.context.getInitParameterNames();
	}

	@Override
	public ServletContext getServletContext(){
		return this.context;
	}

	/**
	 * @see javax.servlet.ServletConfig#getServletName()
	 */
	@Override
	public String getServletName(){
		return this.servletName;
	}
}