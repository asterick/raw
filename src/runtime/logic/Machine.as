package runtime.logic
{    
    import flash.geom.Point;
	import flash.utils.ByteArray;
	import util.Format;

    import resources.Resource;
    import runtime.audio.Instrument;
	
	public class Machine
	{
		public static const VAR_RANDOM_SEED:uint          = 0x3C;
		public static const VAR_LAST_KEYCHAR:uint         = 0xDA;
		public static const VAR_HERO_POS_UP_DOWN:uint     = 0xE5;
		public static const VAR_MUS_MARK:uint             = 0xF4;
		public static const VAR_SCROLL_Y:uint             = 0xF9;
		public static const VAR_HERO_ACTION:uint          = 0xFA;
		public static const VAR_HERO_POS_JUMP_DOWN:uint   = 0xFB;
		public static const VAR_HERO_POS_LEFT_RIGHT:uint  = 0xFC;
		public static const VAR_HERO_POS_MASK:uint        = 0xFD;
		public static const VAR_HERO_ACTION_POS_MASK:uint = 0xFE;
		public static const VAR_PAUSE_SLICES:uint         = 0xFF;

		// --- Execution threads
		public static const NUM_THREADS:uint = 64;
		public static const threads:Vector.<Machine> = Vector.<Machine>(createThreads());
		
		public static var dumpTrace:Boolean = false;

		// --- Playback frequency constants
		private static const FREQ_TABLE:Vector.<uint> = Vector.<uint>([
		     3327,  3523,  3729,  3951,  4182,  4430, 
		     4697,  4972,  5279,  5593,  5926,  6280, 
		     6653,  7046,  7457,  7902,  8363,  8860, 
		     9395,  9943, 10559, 11186, 11852, 12560, 
		    13307, 14093, 14915, 15839, 16727, 17720, 
		    18840, 19886, 21056, 22372, 23706, 25032, 
		    26515, 28185, 29829, 31677]);
		
		private const OpTable:Vector.<Function> = Vector.<Function>([
            opSetI,     opSet,      opAdd,      opAddI,
            opJsr,      opReturn,   opBreak,    opJmp,
            opSetVec,   opDbra,  	opSi, 		opFade,
    		opVec,		opSetWS,	opClr,		opCopy,
    		opShow,		opBigEnd,	opText, 	opSub,
    		opAndI,		opOrI,  	opLsl,		opLsr,
    		opPlay,		opLoad,		opSong
	    ]);
		
		// --- Execution variables (program is the same across all threads) 
		private static var data:ByteArray;
		public static const variables:Vector.<int> = new Vector.<int>(0x100);

		private static var stack:Vector.<uint> = new Vector.<uint>();
		private var pc:uint;
		private var paused:Boolean;
		private var halted:Boolean;
		
		// Execution has changed
		private var will_adjust:Boolean;
		private var next_pc:uint;
		private var next_halt:Boolean;

		private var will_pause:Boolean;
		private var next_pause:Boolean;

        private var core:uint;

		// Static constuctor
		private static function createThreads():Array
		{
			var threads:Array = new Array();

			while( threads.length < NUM_THREADS )
				threads.push( new Machine(threads.length) );
            
			return threads;
		}

		public function Machine( index:uint ):void
		{
		    core = index;
		    
			will_adjust = false;
			will_pause = false;
			
			halted = true;
			paused = false;
			pc = 0;
		}
        
        public static function restart( program:ByteArray ):void
		{
			data = program;

			// Kill all threads
			for each( var t:Machine in threads )
				t.halted = true;

            // Seed random with Flash random (better than system clock)
			variables[VAR_RANDOM_SEED] = int16(Math.random()*0xFFFF);

			// Thread 0 is reset to init
            threads[0].initalize( 0 );
		}
		
		public static function execute():void
		{
            var running:Array = new Array();
            var i:uint = 0;
			// Alter execution for next step
			for each( t in threads )
			{
				if( t.will_adjust )
				{
				    t.will_adjust = false;
					t.pc = t.next_pc;
					t.halted = t.next_halt;
				}
				
				if( t.will_pause )
				{
				    t.will_pause = false;
					t.paused = t.next_pause;
				}
				
				if( t.running )
				    running.push(i);

				i++
			}

            if( dumpTrace )
            {
                trace("---------------------------");
                trace( "Running threads: ", running);
            }

			// Step all known threads
			for each( var t:Machine in threads )
			    t.execute();
		}
    

        public function get running():Boolean
        {
            return !halted && !paused;
        }

		private function execute():void
		{
			try
			{
				while( running )
				{
					data.position = pc;
					executeOp( data.readUnsignedByte() );
					pc = data.position;
				}
			}
			catch( e:RuntimeBreak )
			{
				// Thread broke execution
				pc = data.position;
			}
            catch ( e:Error )
            {
                trace(">>>","EXECUTION ERROR", e.message);
                halted = true;
                throw e;
            }
		}

		// ---- Thread startup call
		private function initalize( start:uint ):void
		{
			will_adjust = true;			
			next_pc = start;
			next_halt = false;
		}
		
		private static function int16( value:int ):int
		{
			return ( value & 0x8000 ) * 0x1FFFF | (value & 0x7FFF);
		}
		
		private function debug( style:String, ... rest ):void
		{
            if( !dumpTrace )
        	    return ;

		    var out:String = Format.format.apply( null, [style].concat(rest) );		    
		    trace( Format.format( "LOGIC>> ${{0:2X}} ${{1:4X}}:\t", core, pc ) + out );
	    }
		
		private function executeOp( code:uint ):void
		{
			var off:uint;
			var x:int;
			var y:int;
			var zoom:uint;
			
			// Draw shape short form
			if( code & 0x80 )
			{
				off = (code << 8) | data.readUnsignedByte();
				x = data.readUnsignedByte();
				y = data.readUnsignedByte();
				
				if( y >= 200 )
				{
					x += y - 199;
					y = 199;
				}

				debug( "shape.s\t${{0:4X}} {{1}} {{2}}", off, x, y );

                Main.frame.shape( off, false, new Point(x, y), 0x40 );
			}
			else if( code & 0x40 )
			{
                off = data.readUnsignedShort();

				// -- X Position
				switch( code & 0x30 )
				{
					case 0x00:
						x = data.readShort();
						break ;
					case 0x10:
						x = variables[data.readUnsignedByte()];
						break ;
					case 0x20:
						x = data.readUnsignedByte();
						break ;
					case 0x30:
						x = data.readUnsignedByte() | 0x100;
						break ;
				}
				
				// -- Y Position
				switch( code & 0x0C )
				{
					case 0x00:
						y = data.readShort();
						break ;
					case 0x04:
						y = variables[data.readUnsignedByte()];
						break ;
					case 0x08:
					case 0x0C:
						y = data.readUnsignedByte();
						break ;
				}

                switch( code & 0x03 )
				{
					case 0x00:
						zoom = 0x40;
						break ;
					case 0x01:
						zoom = variables[data.readUnsignedByte()];
						break ;
					case 0x02:
						zoom = data.readUnsignedByte();
						break ;
					case 0x03:
						zoom = 0x40;
						break ;
				}
				
				debug( "shape.s\t${{0:4X}} {{1}} {{2}} {{3}}", off, x, y, zoom );
                
				Main.frame.shape( off, (code & 3) == 3, new Point(x, y), zoom );
			}
			//
			else
			{
			    OpTable[code]();
			}
		}
		
        private function opSetI():void
        {
			var dst:uint = data.readUnsignedByte();
			var val:int = data.readShort();

			debug( "set.i\t[${{0:2X}}] {{1}}", dst, val );

			variables[dst] = val;
        }


        private function opSet():void
        {
			var dst:uint = data.readUnsignedByte();
    		var src:uint = data.readUnsignedByte();
		
    		debug( "set\t[${{0:2X}}] [${{1:2X}}]\t; = {{2}}", dst, src, variables[src] );
		
    		variables[dst] = variables[src];
		}

        private function opAdd():void
        {
			var dst:uint = data.readUnsignedByte();
			var src:uint = data.readUnsignedByte();
			
			debug( "add\t[${{0:2X}}] [${{1:2X}}]\t; {{2}} + {{3}}", dst, src, variables[dst], variables[src] );
			
			variables[dst] = int16( variables[dst] + variables[src] );
		}

        private function opAddI():void
        {
			var dst:uint = data.readUnsignedByte();
			var val:int = data.readShort();
			
			debug( "addi\t[${{0:2X}}] {{1}}\t; {{2}}", dst, val, variables[dst] );
			
			variables[dst] = int16( variables[dst] + val );
		}

        private function opJsr():void
        {
			var offset:uint = data.readUnsignedShort();

			debug( "jsr\t${{0:4X}}", offset );

			stack.push(data.position);
			data.position = offset;
        }

        private function opReturn():void
        {
			debug( "return" );

			data.position = stack.pop();
		}

        private function opBreak():void
        {
		    debug( "break" );
		    
			throw new RuntimeBreak();
		}
						
        private function opJmp():void
        {
			var offset:uint = data.readUnsignedShort();
            
		    debug( "jmp\t${{0:4X}}", offset );

			data.position = offset;
        }
						
        private function opSetVec():void
        {
			var dst:uint = data.readUnsignedByte();
			var offset:uint = data.readUnsignedShort();

		    debug( "setvec\t${{0:2X}} ${{1:4X}}", dst, offset );

			threads[dst].initalize(offset);
		}
						
        private function opDbra():void
        {
			var dst:uint = data.readUnsignedByte();
			var offset:uint = data.readUnsignedShort();

            debug( "dbra\t{{0}} ${{1:4X}}\t; {{2}}", dst, offset, variables[dst] );

			variables[dst] = int16(variables[dst] - 1);
			
			if( variables[dst] != 0 )
				data.position = offset;
		}


		private function opSi():void
		{
			var mode:uint = data.readUnsignedByte();
            var s:uint = data.readUnsignedByte();
			var a:int = variables[s];
			var b:int;

            var cp:String = ['eq','ne','gt','ge','lt','le'][mode & 0x7];
            var offset:uint;

			if( mode & 0x80 )
			{
			    var r:uint = data.readUnsignedByte();
				b = variables[r];
			    offset = data.readUnsignedShort();
				
				debug( "si\t[${{0:2X}}] {{1}} [${{2:2X}}] ${{3:4X}}\t; {{4}} {{1}} {{5}}", s, cp, r, offset, a, b );
			}
			else if( mode & 0x40 )
			{
				b = data.readShort();
			    offset = data.readUnsignedShort();

				debug( "si\t[${{0:2X}}] {{1}} {{2}} ${{3:4X}}\t; {{4}}", s, cp, b, offset, a );
			}
			else
			{
				b = data.readUnsignedByte();
			    offset = data.readUnsignedShort();

				debug( "si\t[${{0:2X}}] {{1}} {{2}} ${{3:4X}}\t; {{4}}", s, cp, b, offset, a );
			}
				
			switch( mode & 0x7 )
			{
				case 0x00:
					if( a == b )
						data.position = offset;
					break ;
				case 0x01:
					if( a != b )
						data.position = offset;
					break ;
				case 0x02:
					if( a > b )
						data.position = offset;
					break ;
				case 0x03:
					if( a >= b )
						data.position = offset;
					break ;
				case 0x04:
					if( a < b )
						data.position = offset;
					break ;
				case 0x05:
					if( a <= b )
						data.position = offset;
					break ;
				default:
					throw new Error("Unrecoginized conditional code: " + (mode&7) );
					break ;
			}
		}
					
		private function opFade():void
		{
		    var palette:uint = data.readUnsignedShort();

		    debug( "fade\t${{0:4X}}", palette );

			Main.frame.setPalette( palette >> 8 );
		}

		private function opVec():void
		{
			var start:uint = data.readUnsignedByte();
			var end:uint = data.readUnsignedByte();
			var mode:uint = data.readUnsignedByte();

		    debug( "vec\t${{0:2X}} ${{1:2X}} {{2}}", start, end, mode );

			if( mode == 2 )
			{
				while( start <= end )
				{
					threads[start].will_adjust = true;
					threads[start].next_halt = true;
					start++;
				}
			}
			else if( mode < 2 )
			{
				while( start <= end )
				{
					threads[start].will_pause = true;
					threads[start].next_pause = (mode == 1);
					start++;
				}
			}					
		}
						
		private function opSetWS():void
		{
			var page:uint = data.readUnsignedByte();
			
			debug( "setws\t${{0:2X}}", page );
			
			Main.frame.select( page );
		}

		private function opClr():void
		{
			var page:uint = data.readUnsignedByte();
			var color:uint = data.readUnsignedByte();
			
			debug( "clr\t${{0:2X}} {{1}}", page, color );
			
			Main.frame.clear( page, color );
		}

		private function opCopy():void
		{
			var dst:uint = data.readUnsignedByte();
			var src:uint = data.readUnsignedByte();

			debug( "copy\t${{0:2X}} ${{1:2X}}\t; Y_SCROLL = {{2}}", dst, src, variables[VAR_SCROLL_Y] );

			Main.frame.copy( dst, src, variables[VAR_SCROLL_Y] );
		}

		private function opShow():void
		{
			var page:uint = data.readUnsignedByte();
			
			debug( "show\t${{0:2X}}", page );

			Main.frame.setDisplay( page );
            variables[0xf7] = 0;
		}

		private function opBigEnd():void
		{
    	    debug( "bigend" );
		
		    halted = true;
    		throw new RuntimeBreak();
    	}
						
		private function opText():void
		{
            var resource:uint = data.readUnsignedShort();
            var x:uint = data.readUnsignedByte();
            var y:uint = data.readUnsignedByte();
            var color:uint = data.readUnsignedByte();

		    debug( "text\t{{0}} {{1}} {{2}} {{3}}", resource, x, y, color );

		    Main.frame.drawText( x, y, resource, color );
		}
						
		private function opSub():void
		{
			var dst:uint = data.readUnsignedByte();
		    var src:uint = data.readUnsignedByte();
			
			debug( "sub\t[${{0:2X}}] [${{1:2X}}]\t; {{2}} - {{3}}", dst, src, variables[dst], variables[src] );
			
			variables[dst] = int16( variables[dst] - variables[src] );
		}

		private function opAndI():void
		{
			var dst:uint = data.readUnsignedByte();
			var val:int = data.readShort();
			
			debug( "andi\t[${{0:2X}}] {{1}}\t; {{2}}", dst, val, variables[dst] );
			
			variables[dst] = int16( variables[dst] & val );
		}

		private function opOrI():void
		{
			var dst:uint = data.readUnsignedByte();
			var val:int = data.readShort();

			debug( "ori\t[${{0:2X}}] {{1}}\t; {{2}}", dst, val, variables[dst] );

			variables[dst] = int16( variables[dst] | val );
		}

		private function opLsl():void
		{
			var dst:uint = data.readUnsignedByte();
			var shift:int = data.readShort();

			debug( "lsl\t[${{0:2X}}] {{1}}\t; {{2}}", dst, shift, variables[dst] );

			variables[dst] = int16(( variables[dst] & 0xFFFF ) << shift );
		}

		private function opLsr():void
		{
			var dst:uint = data.readUnsignedByte();
			var shift:int = data.readShort();

			debug( "lsr\t[${{0:2X}}] {{1}}\t; {{2}}", dst, shift, variables[dst] );

			variables[dst] = int16(( variables[dst] & 0xFFFF ) >> shift );
		}

		private function opPlay():void
		{
		    var res:uint = data.readUnsignedShort();
		    var freq:uint = FREQ_TABLE[data.readUnsignedByte()];
		    var volume:Number = data.readUnsignedByte();
		    var channel:uint = data.readUnsignedByte();

		    debug( "play\t{{0:4X}} {{1}} {{2}} {{3}}", res, freq, volume, channel );
		    
            var samples:ByteArray = Resource.res[res].data;
            
            if( samples )
            {
                Main.mixer.playSound( 
                    channel, 
                    new Instrument(samples, volume), 
                    freq );
            }
            else
            {
                Main.mixer.stopChannel( channel );
            }
		}

		private function opLoad():void
		{
            var resource:uint = data.readUnsignedShort();

            debug( "load\t${{0:4X}}", resource );
            
			Main.LoadResource( resource );
		}
						
		private function opSong():void
		{
		    var res:uint = data.readUnsignedShort();
		    var delay:uint = data.readUnsignedShort();
		    var pos:uint = data.readUnsignedByte();
		    
		    debug( "song\t{{0:4X}} {{1}} {{2}}", res, delay, pos );
                        
            var song:ByteArray = Resource.res[res].data;
            
            if( song )
                Main.mixer.playSong( song, delay, pos );
            else if( delay != 0 )
                Main.mixer.delay = delay;
            else
                Main.mixer.stopSong();
		}
	}
}