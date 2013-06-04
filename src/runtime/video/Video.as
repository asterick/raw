package runtime.video
{
	import flash.display.*;
	import flash.geom.*;

	import flash.events.Event;
	import flash.utils.ByteArray;

	import resources.Static;

	public class Video extends Bitmap
	{
        private static const DISPLAY_WIDTH:uint = 320;
        private static const DISPLAY_HEIGHT:uint = 200;
        private static const SCALE_FACTOR:uint = 2;
        
		private static const TOP_LEFT:Point = new Point(0,0);

		private var pages:Vector.<BitmapData>;

		private var copypage:BitmapData;
        private var working:BitmapData;
		private var display:BitmapData;
		private var shadow:BitmapData;
        
        private var shapeBufferA:ShapeList;
        private var shapeBufferB:ShapeList;

		private var paletteGroup:Array;
		private var palette:Array;

		public function Video():void
		{
			// Setup display buffer
			super( makeBuffer() );
			
			pages = Vector.<BitmapData>( [
					copypage = makeBuffer(), 
					display = makeBuffer(), 
					shadow = makeBuffer(), 
					working = makeBuffer()
				] );

			addEventListener( Event.ENTER_FRAME, refresh );
            addEventListener( Event.ADDED_TO_STAGE, scale );
		}
		
		private function scale( e:Event ):void
		{
		    scaleX = scaleY = Math.min( stage.stageWidth / bitmapData.width, stage.stageHeight / bitmapData.height );
	    }	    
		
		private function makeBuffer():BitmapData
		{
		    return new BitmapData( DISPLAY_WIDTH*SCALE_FACTOR, DISPLAY_HEIGHT*SCALE_FACTOR, false );
	    }
		
		// Update active display (paletted)
		private function refresh( e:Event ):void
		{
			bitmapData.paletteMap( display, bitmapData.rect, TOP_LEFT, null, null, palette ); 
		}
		
        public function loadShapes( a:ByteArray, b:ByteArray ):void
        {        
            shapeBufferA = new ShapeList( a, copypage );
            shapeBufferB = new ShapeList( b, copypage );
        }
        
		public function loadPalette( data:ByteArray ):void
		{
			data.position = 0;
			
			paletteGroup = new Array();
			
			for( var pal:Number = 0; pal < 32; pal++ )
			{
				for( var color:Number = 0; color < 16; color++ )
				{
					var old:uint = data.readUnsignedShort();
					
					paletteGroup.push(
						((old & 0x0F00) * 0x1100) |
						((old & 0x00F0) * 0x00110) |
						((old & 0x000F) * 0x000011) );
				}
			}
			
			setPalette(0);
		}

		public function setPalette( color:uint ):void
		{
			palette = paletteGroup.slice( color * 16 );
		}
		
		private function getPage( page:uint ):BitmapData
		{
			switch( page )
			{
				case 0: case 1: case 2: case 3:
					return pages[page];
				case 0xFE:
					return display;
				case 0xFF:
					return shadow;
			}
			
			return pages[0];
		}

		public function select( page:uint ):void
		{
			working = getPage(page);
		}

		public function clear( page:uint, color:uint ):void
		{
			var sheet:BitmapData = getPage(page);
			
			sheet.fillRect( sheet.rect, color & 0xF );
		}
		
		public function setDisplay( page:uint ):void
		{
			if( page == 0xFF )
			{
				var temp:BitmapData = shadow;
				shadow = display;
				display = temp;
			}
			else
			{
				display = getPage(page);
			}
		}
		
		public function load( buffer:ByteArray ):void
		{
		    var temp:BitmapData = new BitmapData( DISPLAY_WIDTH, DISPLAY_HEIGHT, false );
		    var byte:uint = 0;
			
			for( var y:Number = 0; y < DISPLAY_HEIGHT; y++ )
			{
				for( var x:Number = 0; x < DISPLAY_WIDTH; x += 8, byte++ )
				{
					for( var bit:Number = 0; bit < 8; bit ++ )
					{
						var data:uint = 0;

						for( var plane:Number = 0, ptr:uint = byte; plane < 4; plane++, ptr += (DISPLAY_WIDTH*DISPLAY_HEIGHT/8) )
							data |= ((buffer[ptr] << bit) & 0x80) >> (7-plane);

                        temp.setPixel32( x+bit, y, data );
					}
				}
			}
			
			var bitmap:Bitmap = new Bitmap( temp );
			copypage.draw( bitmap, new Matrix( SCALE_FACTOR, 0, 0, SCALE_FACTOR ) );
		}

		public function copy( src:uint, dst:uint, scroll:int ):void
		{
			var target:BitmapData;
			var source:BitmapData;
			
			// Do vertical scroll
			if (src > 3 && src < 0xFE)
			{
				source = getPage(src&3);
				target = getPage(dst);
			
				// Pull pixels up
				if( scroll < 0 )
					target.copyPixels( 
					    source, 
					    new Rectangle( 
					        0, 
					        -scroll* SCALE_FACTOR, 
					        DISPLAY_WIDTH * SCALE_FACTOR, 
					        DISPLAY_HEIGHT * SCALE_FACTOR ), 
					    TOP_LEFT );
				// Push pixels down
				else
					target.copyPixels( source, target.rect, new Point( 0, scroll * SCALE_FACTOR ) );
			}
			else
			{
				source = getPage(src);
				target = getPage(dst);
				
				target.copyPixels( source, target.rect, TOP_LEFT );
			}
		}

        public function drawText( x:int, y:int, res:int, color:uint ):void
        {
            var string:String = Static.STRINGS_ENG[res];
            var dx:int = x * 8;
            
            for( var i:int = 0; i < string.length; i++ )
            {
                var ch:uint = string.charCodeAt(i);
                
                if( ch == 0xA )
                {
                    dx = x * 8;
                    y += 8;
                }
                else if( ch >= 0x20 )
                {
                    drawChar( dx, y, ch, color );
                    dx += 8;
                }
            }
        }
		
		private function drawChar( x:int, y:int, char:uint, color:uint ):void
		{
		    char = (char - 0x20) * 8;
		    
		    for( var yp:int = 0; yp < 8; yp++, char++, y++ )
		        for( var xp:int = 0; xp < 8; xp ++ )
		            if( (Static.FONT[char] << xp) & 0x80 ) 
                        working.fillRect( new Rectangle( 
                            (x+xp)*SCALE_FACTOR, 
                            y*SCALE_FACTOR, 
                            SCALE_FACTOR, SCALE_FACTOR), color );
	    }
        
        public function shape( offset:int, secondary:Boolean, pt:Point, zoom:Number ):void
        {
            // Select the buffer
            var list:ShapeList = secondary ? shapeBufferB : shapeBufferA;
            var m:Matrix = new Matrix();
            
            // Zoom is 2:6 fixed point
            zoom /= 64.0;
            
            m.scale( zoom, zoom );
            m.translate( pt.x, pt.y );
            m.scale( SCALE_FACTOR, SCALE_FACTOR );

            list.drawShape( working, offset, m );
        }
	}
}