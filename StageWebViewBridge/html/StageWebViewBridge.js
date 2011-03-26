if( window.StageWebViewBridge == null )
{
	window.StageWebViewBridge = {};
	window.StageWebViewBridge.callBacks = [];
	window.StageWebViewBridge.doCall = function( jsonArgs )
	{
		var _serializeObject = JSON.parse( atob( jsonArgs ) );
		var method = _serializeObject.method;
		var returnValue = null;
		if( method.indexOf('[SWVMethod]')==-1 )
		{			
			var targetFunction;
			if( method.indexOf('.')==-1)
			{
				targetFunction = window[ method ];
			}
			else
			{
				var splitedPath = method.split('.');
				targetFunction=window;
				for( var i=0; i<splitedPath.length; i++ )
				{
					targetFunction = targetFunction[ splitedPath[ i ] ];
				};
			}
			returnValue = targetFunction.apply(null, _serializeObject.arguments );
		}
		else
		{
			var targetFunction = window.StageWebViewBridge.callBacks[ method ];
			returnValue = targetFunction.apply(null, _serializeObject.arguments );
		}
		if( _serializeObject.callBack !=undefined && returnValue!=null )
		{	
			window.StageWebViewBridge.call( _serializeObject.callBack, null, returnValue );  		
		}

	};
	window.StageWebViewBridge.call = function( )
	{
		var argumentsArray = [];
		var _serializeObject = {};
			_serializeObject.method = arguments[ 0 ];
		if( arguments[ 1 ] !=null ) _serializeObject.callBack = '[SWVMethod]'+arguments[ 0 ];
		
		if( arguments.length>2)
		{
			for (var i = 2; i < arguments.length; i++)
			{
				argumentsArray.push( arguments[ i ] );
			}
		}

		_serializeObject.arguments = argumentsArray;
		if( _serializeObject.callBack !=undefined ) window.StageWebViewBridge.addCallback('[SWVMethod]'+arguments[ 0 ], arguments[ 1 ] );
		window.location.href='about:[SWVData]'+btoa( JSON.stringify( _serializeObject ) );
	};

	window.StageWebViewBridge.addCallback = function( name, fn )
	{
		window.StageWebViewBridge.callBacks[ name ] = fn;
	};			
    
    // workaround to fix application crash when window.alert is called directly from AS3         
	window.alert = function(native)
	{
		window.nativeAlert = native;
	 	return function(str)
	 	{
	    	setTimeout('window.nativeAlert("'+str+'");',10);
	 	}
	}(window.alert);

};