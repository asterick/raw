package resources
{
    import flash.utils.ByteArray;
    import flash.utils.Endian;
    
    public class BitStream
    {
        private var _data:ByteArray;
        
        private var _shift:uint;
        public var _pos:int;
        
        public function BitStream( data:ByteArray, start:int ):void
        {
            _data = data;
            _pos = start;
            
            loadShift();
        }
        
        public function loadShift():void
        {
            _data.endian = Endian.BIG_ENDIAN;

            _data.position = _pos;
            _shift = _data.readUnsignedInt();           
            _pos -= 4;
        }

        public function getBits( count:uint = 1 ):uint
        {
            var out:uint = 0;
            
            while( count-- )
            {
                var bit:uint = _shift & 1;              
                _shift >>>= 1;
                                
                if( !_shift )
                {
                    loadShift();
                    bit = _shift & 1;
                    _shift = (_shift >>> 1) | 0x80000000;
                }
                
                out = (out << 1) | bit;
            }
            
            return out;
        }
    }
}