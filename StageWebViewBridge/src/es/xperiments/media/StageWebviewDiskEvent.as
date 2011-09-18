package es.xperiments.media
{
	import flash.events.Event;

	/**
	 * @author xperiments
	 */
	public class StageWebviewDiskEvent extends Event
	{
		
		public static const START_DISK_PARSING : String = "START_DISK_PARSING";
		public static const END_DISK_PARSING : String = "END_DISK_PARSING";

		public function StageWebviewDiskEvent( type : String, bubbles : Boolean = false, cancelable : Boolean = false )
		{
			super( type, bubbles, cancelable );
			
		}
	}
}
