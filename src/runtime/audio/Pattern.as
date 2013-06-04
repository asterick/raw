package runtime.audio 
{
    import flash.utils.ByteArray;
    import resources.Resource;
    public class Pattern
    {
        public static const NO_EFFECT:uint = 0;
        public static const VOLUME_UP:uint = 5;
        public static const VOLUME_DOWN:uint = 6;
        
        public static const NONE:uint = 0;
        public static const NOTE:uint = 1;
        public static const MARK:uint = 2;
        public static const STOP:uint = 3;
        
        public var type:uint;
        
        public var freq:uint;
        public var mark:uint;
        
        public var instrument:uint;
        public var effect:uint;
        public var arg:uint;
        
        public function Pattern( source:ByteArray ):void
        {
            freq = source.readUnsignedShort();
            mark = source.readUnsignedShort();
            
            if ( freq == 0xFFFD )
            {
                type = MARK;
            }
            else if ( freq == 0xFFFE )
            {
                type = STOP;
            }
            else
            {                
                instrument = mark >> 12;
                effect = (mark >> 8) & 0xF;
                arg = mark & 0xFF;
                
                type = instrument ? NOTE : NONE;
            }
        }
    }
}