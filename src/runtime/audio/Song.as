package runtime.audio
{
    import flash.utils.ByteArray;

    import resources.Resource;
    import runtime.audio.Mixer;

    public class Song
    {
        public var delay:uint;

        public var instruments:Vector.<Instrument>;
        public var order:Vector.<uint>;
        
        public var patterns:Vector.<Vector.<Vector.<Pattern>>>;

        public function Song( source:ByteArray ):void
        {
            var i:int;
            
            source.position = 0;
            
            delay = source.readUnsignedShort();

            instruments = new Vector.<Instrument>(0x16);

            for( i = 1; i < 16; i++ )
            {
                var res:uint = source.readUnsignedShort();
                var vol:uint = source.readUnsignedShort();
                
                var samples:ByteArray = Resource.res[res].data;
                
                if( samples )
                    instruments[i] = new Instrument( samples, vol );
                    
            }

            var numOrders:uint = source.readUnsignedShort();
            var maxPattern:uint = 0;
            order = new Vector.<uint>();
            
            for( i = 0; i < numOrders; i++ )
            {
                var patternNum:uint = source.readUnsignedByte();

                maxPattern = Math.max( patternNum, maxPattern );
                order.push( patternNum );
            }
            
            source.position = 0xC0;
            
            patterns = new Vector.<Vector.<Vector.<Pattern>>>(maxPattern);
            
            for( i = 0; i <= maxPattern; i++ )
            {
                patterns[i] = new Vector.<Vector.<Pattern>>(64);
                
                for( var r:uint = 0; r < 64; r++ )
                {
                    patterns[i][r] = new Vector.<Pattern>(4);
                    
                    for ( var ch:uint = 0; ch < 4; ch ++ )
                        patterns[i][r][ch] = new Pattern( source );
                }
            }
        }
    }
}