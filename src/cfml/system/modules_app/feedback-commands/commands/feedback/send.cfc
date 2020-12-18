/**

**/
component aliases="feedback" {
	property name='shell'				inject='shell';

	function run( summary="", description="" )  {

			var body = getMessageStructure( summary, description );

			var email = ConfigService.getSetting( 'feedback.email', '' );

			if( len(email) ){
				if( confirm( "Would you like to post your feedback with the following account? [#email#] (yes/no)") ){

					var token = shell.ask( "Jira Authentication Token:", '*', false, false, false );
					var auth = toBase64( email & ":" & token );
					cfhttp(method="POST", charset="utf-8", url="https://ortussolutions.atlassian.net/rest/api/3/issue/", result="result") {
						cfhttpparam(name="body",type="body", value='#serializeJSON(body)#');
						cfhttpparam(name="Content-Type", type="header", value="application/json");
						cfhttpparam(name="Authorization", type="header", value=" Basic #auth#");
					}

					if (result.status_code == 201) {
						print.greenLine( "Feedback sended! Thank you!" );
					}else{
						print.yellowLine( "Aw, There was an error, posting your feedback" );
					}
				}
			}else{
				print.yellowLine( "Before posting a feedback, please configure you jira account ( help feedback )" );
			}
			
	}

	function getMessageStructure( string summary="", string description="" ){
		return {
			"fields": 
				{
				"summary": "#summary#",
				"issuetype": {
						"id": "1"
					},
				"project": 
					{
						"key": "COMMANDBOX"
					},
					"description": {
						"type": "doc",
						"version": 1,
						"content": [
							{
								"type": "paragraph",
								"content": [
									{
										"text": "#description#",
										"type": "text"
									}
								]
							}
						]
					}
				}
			};
	}

}