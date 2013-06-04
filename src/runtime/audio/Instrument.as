package runtime.audio
{
    import flash.utils.ByteArray;

    public class Instrument
    {
        public var data:ByteArray;

        public var playStart:uint;
        public var loopStart:uint;
        public var loopEnd:uint;
        
        public var looping:Boolean;

        public var volume:uint;
        
        public function Instrument( sample:ByteArray, vol:uint ):void
        {
            sample.position = 0;

            var oneShotLen:uint = sample.readUnsignedShort()*2;
            var loopLen:uint = sample.readUnsignedShort()*2;
            
            data = sample;
            playStart = 8;

            looping = loopLen > 0;
            loopStart = oneShotLen + playStart;
            loopEnd = oneShotLen + loopLen + playStart;
            
            volume = vol;
        }
    }
}