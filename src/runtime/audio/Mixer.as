package runtime.audio
{
    import flash.media.Sound;
    import flash.media.SoundChannel;
    import flash.events.SampleDataEvent;
    import flash.utils.ByteArray;
    import runtime.audio.Pattern;

    import runtime.audio.MixerChannel;
    import runtime.audio.Song;
    import runtime.audio.Instrument;
    import runtime.logic.Machine;
    
    public class Mixer
    {
        private static const BUFFER_LENGTH:uint = 4096;
        private static const SAMPLE_RATE:uint = 44100;
        private static const AMIGA_SPEED:uint = 7159092;

        // Flash audio
        private var _sound:Sound;
        private var _channel:SoundChannel;

        // Audio playback
        private var _song:Song;
        private var _tickRate:uint;
        private var _currentTick:uint;
        
        private var _currentOrder:int;
        private var _currentRow:int;
        
        private var _channels:Vector.<MixerChannel>;
        
        public function Mixer():void        
        {
            _channels = new Vector.<MixerChannel>(4);
            
            _sound = new Sound();
            _sound.addEventListener( SampleDataEvent.SAMPLE_DATA, fillMixer );
        }
        
        public function startMixer():void
        {
            if( _channel )
                return ;
            
            _channel = _sound.play();
        }
        
        public function stopMixer():void
        {
            _channel.stop();
            _channel = null;
        }
        
        public function stopChannel( ch:uint ):void
        {
            _channels[ch] = null;
        }
        
        public function reset():void
        {
            stopSong();
            
            for ( var i:uint = 0; i < 4; i++ )
                stopChannel(i);
        }
        
        public function playSong( song:ByteArray, rate:int = 0, order:int = 0 ):void
        {
            _song = new Song( song );
            
            if( rate )
                delay = rate;
            else
                delay = _song.delay;
            
            _currentOrder = order;
            _currentRow = 0;
        }
        
        public function set delay( rate:int ):void
        {
            _tickRate = int(rate * 60 * SAMPLE_RATE / AMIGA_SPEED );
            _currentTick = 0;
        }
        
        public function stopSong():void
        {
            _song = null;
        }
        
        public function playSound( ch:uint, inst:Instrument, freq:Number, volumeDelta:int = 0 ):void
        {
            var channel:MixerChannel = new MixerChannel();
            _channels[ch] = channel;

            channel.frequency = freq / SAMPLE_RATE;

            channel.data = inst.data;

            channel.position = inst.playStart;
            channel.loopStart = inst.loopStart;
            channel.loopEnd = inst.loopEnd;
            channel.looping = inst.looping;

            channel.volume = clampAudio( inst.volume + volumeDelta ) / (256.0 * 256.0);
        }
        
        private function clampAudio( volume:int ):int
        {
            if ( volume < 0 )
                return 0;
            
            else if ( volume > 0x3F )
                return 0x3F;
            
            return volume;
        }
        
        private function fillMixer(event:SampleDataEvent):void
        {
            var buffer:ByteArray = event.data as ByteArray;
            
            for ( var s:int=0; s < BUFFER_LENGTH; s++ )
            {
                var sample:Number = 0;
                
                // Mix our audio channel
                for( var ch:uint = 0; ch < _channels.length; ch++ )
                {
                    var channel:MixerChannel = _channels[ch];
                    
                    if( !channel )
                        continue ;
                        
                    var smp:int = channel.data[int(channel.position)];
                    sample += (smp > 0x80 ? (smp - 0x100) : smp)  * channel.volume;

                    channel.position += channel.frequency;
                    
                    if( channel.position >= channel.loopEnd )
                    {
                        if( channel.looping )
                            channel.position = channel.loopStart;
                        else
                            _channels[ch] = null;
                    }
                }
                
                buffer.writeFloat(sample);
                buffer.writeFloat(sample);

                // --- BEGIN SONG PLAYBACK ----
                if( !_song || ++_currentTick < _tickRate )
                    continue ;

                _currentTick = 0;
                
                // Advance order
                if ( _currentRow >= 64 )
                {
                    _currentRow = 0;
                    
                    if ( ++_currentOrder > _song.order.length )
                        stopSong();
                    
                        continue ;
                }

                var patterns:Vector.<Pattern> = _song.patterns[ _song.order[ _currentOrder ] ][ _currentRow++ ];
                
                for ( ch = 0; ch < 4; ch++ )
                {
                    var pat:Pattern = patterns[ch];
                    
                    if ( pat.type == Pattern.NOTE )
                    {
                        var delta:int = 0;
                        
                        if ( pat.effect == Pattern.VOLUME_DOWN )
                            delta = -pat.arg;
                        if ( pat.effect == Pattern.VOLUME_UP )
                            delta = +pat.arg;
                        
                        playSound( ch, _song.instruments[pat.instrument], AMIGA_SPEED / (pat.freq * 2), delta );
                    }
                    else if ( pat.type == Pattern.STOP )
                    {
                        stopChannel( ch );
                    }
                    else if ( pat.type == Pattern.MARK )
                    {
                        Machine.variables[Machine.VAR_MUS_MARK] = patterns[ch].mark;
                    }
                }
            }
        }
    }
}