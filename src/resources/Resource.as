package resources
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;

	public class Resource
	{
		public static const res:Vector.<Resource> = Vector.<Resource>(decodeResources());

		public static const SOUND:int   = 0;
		public static const MUSIC:int   = 1;
		public static const VIDBUF:int  = 2;
		public static const PALETTE:int = 3;
		public static const SCRIPT:int  = 4;
		public static const BITMAP:int  = 5;
		
		public var type:int;
		public var rank:int;
		public var data:ByteArray;

		public function Resource( t:int, r:int, d:ByteArray ):void
		{
			type = t;
			rank = r;
			data = d;			
		}

		// --- Decode resource data
		private static function decodeResources():Array
		{
			var res:Array = new Array();
			
			var toc:ByteArray = Files.MEMLIST;
			toc.position = 0;
			toc.endian = Endian.BIG_ENDIAN;
			
			while( !toc.readUnsignedByte() )
			{
				var data:ByteArray;

				var type:int = toc.readUnsignedByte();
				toc.readUnsignedShort();
				toc.readUnsignedShort();
				var rank:int = toc.readUnsignedByte();
				var bank:int = toc.readUnsignedByte();
				var pos:int = toc.readInt();
				var packed:int = toc.readInt();
				var unpacked:int = toc.readInt();
				
				if( packed )
				{
					data = new ByteArray();

					Files.BANK[bank].position = pos;
					Files.BANK[bank].readBytes(data,0,packed);

				
					if( packed != unpacked )
						data = Decompress.unpack(data);

					data.endian = Endian.BIG_ENDIAN;
				}

                if ( type == MUSIC )
                    trace( res.length );
                
				res.push( new Resource( type, rank, data ) );
			}

			trace(res.length, "resources successfully decoded.")

			return res;
		}
	}
}
