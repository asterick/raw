package resources
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	public class Decompress
	{
		private static var _output:ByteArray;
		private static var _byteIndex:int;

		public static function unpack(data:ByteArray):ByteArray
		{			
			// -- read data setings
			data.endian = Endian.BIG_ENDIAN;
			data.position = data.length - 8;
			
			var crc:int = data.readUnsignedInt();
			var size:int = data.readUnsignedInt();

			// -- Begin outputting data
			_output = new ByteArray();
			_output.length = size;
			_byteIndex = size - 1;

			var s:BitStream = new BitStream( data, data.length - 12 );

			while( _byteIndex >= 0 )
			{
				// Short form
				if( ! s.getBits() )
				{
					if( ! s.getBits() )
						copyBlock( s, s.getBits(3) + 1 );
					else
						copyOffset( 2,  s.getBits(8) );
				}
				// Long form compression scheme
				else
				{
					var c:int = s.getBits(2);
					switch( c )
					{
						case 0:
							copyOffset( 3,  s.getBits(9) );
							break ;
						case 1:
							copyOffset( 4, s.getBits(10) );
							break ;
						case 2:
							copyOffset( s.getBits(8)+1, s.getBits(12) );
							break ;
						case 3:
							copyBlock( s, s.getBits(8) + 9 );
							break ;
					}
				}
			}

			return _output;
		}
		
		private static function copyBlock( s:BitStream, count:int ):void
		{
			while( count-- )
				_output[_byteIndex--] = s.getBits(8);				
		}

		private static function copyOffset( count:int, offset:int ):void
		{
			while( count-- )
			{
				_output[_byteIndex] = _output[_byteIndex + offset];
				_byteIndex--;
			}
		}
	}
}