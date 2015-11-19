package
{
    import flash.display.*;
    import flash.ui.Keyboard;
    import flash.events.*;
    import flash.utils.ByteArray;
    import flash.net.FileReference;
    import flash.utils.getTimer;

    import resources.*;
    import runtime.audio.*;
    import runtime.video.*;
    import runtime.logic.*;
    import util.*;
    
    public class Main extends MovieClip
    {
        private static const keycode:Vector.<Boolean> = new Vector.<Boolean>(0x10000);

        public static const frame:Video = new Video();
        public static const mixer:Mixer = new Mixer();
        
        private var left:Boolean;
        private var right:Boolean;
        private var up:Boolean;
        private var down:Boolean;
        private var action:Boolean;
        
        private var nextTime:uint;

        public function Main():void
        {
            trace("\n\n--- Another World (Remake)");
            stage.scaleMode = StageScaleMode.SHOW_ALL;
            stage.quality = StageQuality.LOW;

            // Startup audio sub-system
            mixer.startMixer();
            
            // Startup bideo sub-system
            addChild( frame );          
            stage.addEventListener( Event.ENTER_FRAME, Loop );
            stage.addEventListener( KeyboardEvent.KEY_DOWN, keyDown );
            stage.addEventListener( KeyboardEvent.KEY_UP, keyUp );
                        
            // Start game at the first runtime position
            LoadResource( 16001 );
            Machine.variables[0x54] = 0x81;

            // game checks these variables.  I don't know what for. (copy protection?)
            Machine.variables[0xBC] = 0x10;
            Machine.variables[0xF2] = 4000;
            Machine.variables[0xDC] = 33;

//            stage.addEventListener( MouseEvent.MOUSE_UP, save );
        }

        private function save(e:Event):void
        {
            var fr:FileReference = new FileReference();
            fr.save( Resource.res[7].data, "song.bin" );
        }
        
        public static function LoadResource( res:int ):void
        {
            // Storyboard change
            if( res >= 16000 )
            {
                var settings:Object = Static.RUN_SET[res - 16000];

                frame.loadShapes( settings.shapea.data, settings.shapeb.data );
                frame.loadPalette( settings.palette.data );
                mixer.reset();

                Machine.restart( settings.program.data );
            }
            // Regular resource (only care about video buffer)
            else
            {
                var r:Resource = Resource.res[res];
                
                if( r.type == Resource.VIDBUF )
                    frame.load(r.data);
            }            
        }

        private function keyDown( e:KeyboardEvent ):void
        {
            if( e.keyCode == Keyboard.F1 )
                Machine.dumpTrace = !Machine.dumpTrace;
            
            keycode[ e.keyCode ] = true;
        }
        
        private function keyUp( e:KeyboardEvent ):void
        {
            keycode[ e.keyCode ] = false;
        }
        
        private function Loop(e:Event):void
        {
            var currentTime:uint = getTimer();

            if( nextTime <= currentTime )
            {
                // Run through the execution loop!
                inputs();
                Machine.execute();
            
                // Note: this is a little slower than the original game
                nextTime = currentTime + Machine.variables[Machine.VAR_PAUSE_SLICES] * 17;
            }
        }

        private static function inputs():void
        {
            var u:Boolean = keycode[Keyboard.UP];
            var d:Boolean = keycode[Keyboard.DOWN];
            var l:Boolean = keycode[Keyboard.LEFT];
            var r:Boolean = keycode[Keyboard.RIGHT];
            var a:Boolean = keycode[Keyboard.SPACE] || keycode[Keyboard.ENTER];
            
            var m:uint = 
                (u ? 0x08 : 0) |
                (d ? 0x04 : 0) |
                (l ? 0x02 : 0) |
                (r ? 0x01 : 0);
            
            Machine.variables[Machine.VAR_HERO_POS_UP_DOWN] = u ? -1 : (d ? 1 : 0);
            Machine.variables[Machine.VAR_HERO_POS_JUMP_DOWN] = u ? -1 : (d ? 1 : 0);
            Machine.variables[Machine.VAR_HERO_POS_LEFT_RIGHT] = l ? -1 : (r ? 1 : 0);
            Machine.variables[Machine.VAR_HERO_POS_MASK] = m;
            
            Machine.variables[Machine.VAR_HERO_ACTION] = a ? 1 : 0;
            Machine.variables[Machine.VAR_HERO_ACTION_POS_MASK] = m | (a ? 0x80 : 0);
        }       
    }
}
