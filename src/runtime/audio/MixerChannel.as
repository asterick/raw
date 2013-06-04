package runtime.audio
{
    import flash.utils.ByteArray;
    
    public class MixerChannel
    {
        public var data:ByteArray;

        public var frequency:Number;      // Position increments per sample
        public var position:Number;

        public var volume:Number;

        public var looping:Boolean;
        public var loopStart:uint;
        public var loopEnd:uint;  
    }
}