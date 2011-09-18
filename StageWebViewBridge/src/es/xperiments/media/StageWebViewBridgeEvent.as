package es.xperiments.media
{
	import flash.events.Event;

	/**
	 * @author xperiments
	 */
	public class StageWebViewBridgeEvent extends Event
	{
		
		public static const ON_GET_SNAPSHOT : String = "ON_GET_SNAPSHOT";
		public function StageWebViewBridgeEvent( type : String, bubbles : Boolean = false, cancelable : Boolean = false )
		{
			super( type, bubbles, cancelable );
			
		}
	}
}
