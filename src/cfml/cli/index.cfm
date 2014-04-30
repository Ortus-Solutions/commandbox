<cfoutput>
	
	<h1>CommandBox</h1>
	
	<cfset ch = new commandHandler( new shell() )>
	
	<cfsavecontent variable="command">
	brad test foobar 
	"goo" 
	'doo' 
	 "this is a test" 
	      test\"er 
	      12\=34
	</cfsavecontent>
		<!---
	<cfsavecontent variable="command">
	brad test 
	param=1 
	arg="no"
	 me='you' 
	  arg1="brad wood" 
	  arg2="Luis \"The Dev\" Majano" 
	  test  =  		 mine 	 
	   tester   	=  	 'YOU' 	
	     tester2   	=  	 "YOU2"
	</cfsavexcontent>
		--->
		
		
	#command#<br><br><br>
		
	<cfdump var="#ch.runCommandline( trim( command ) )#">

</cfoutput>