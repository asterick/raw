package runtime.video
{
    import flash.geom.Matrix;
    import flash.geom.Point;
    
    import flash.display.Graphics;
    import flash.display.Bitmap;
    import flash.display.Sprite;
    import flash.display.Shape;
    import flash.display.Shader;
    import flash.display.BlendMode;
    import flash.display.BitmapData;
    import flash.display.DisplayObject;
    import flash.display.DisplayObjectContainer;    

    import flash.utils.ByteArray;
    import flash.utils.Endian;

    public class ShapeList
    {
		private static const TOP_LEFT:Point = new Point(0,0);
        
        // This is a new blend mode (flash 10 only)
        // For flash 9 compatibilty, an ADD blend mode could be used.
		[Embed("shaders/transparent.pbj",mimeType="application/octet-stream")]
		private static const _TRANSPARENT_SHADER_BYTECODE:Class;
        private static const TRANSPARENT_SHADER:Shader = new Shader( new _TRANSPARENT_SHADER_BYTECODE() );

        private var _shapeList:Object;
        private var _adjustBitmap:Bitmap;
        
        private var _copyPage:BitmapData;
        private var _cacheShape:Shape;

        public function ShapeList( code:ByteArray, copy:BitmapData ):void
        {
            if( code == null )
                return ;

            // Seek to the start of our shape buffer
            code.endian = Endian.BIG_ENDIAN;
            code.position = 0;
            
            _shapeList = new Object();
            _copyPage = copy;
            
            while( code.position < code.length )
            {
                var container:Sprite = new Sprite();
                _shapeList[code.position] = container;
                
                // Do not cache between generated shapes
                _cacheShape = null;
                generateShape( container, code );
            }
        }

        public function drawShape( buffer:BitmapData, pos:uint, m:Matrix ):void
        {
            var inv:Matrix = m.clone();
            inv.invert();

            var shape:DisplayObjectContainer = _shapeList[(pos << 1) & 0xFFFF];

            for( var i:uint = 0; i < shape.numChildren; i++ )
            {
                var child:DisplayObject = shape.getChildAt(i);
                
                // Bitmaps are not transformed
                if( child is Bitmap )
                    continue ;

                child.transform.matrix = m;
            }
            
            buffer.draw( shape );
        }
        
        // --- Pre-decode shape buffer into flash usable sprites
        
        private function generateShape( container:Sprite, code:ByteArray, pt:Point = null, color:int = -1 ):void
        {
            var type:uint = code.readUnsignedByte();

            if( pt == null )
                pt = TOP_LEFT;

            if ( type >= 0xC0 )
                createPolygon( container, code, pt, (color < 0) ? (type & 0x3F) : color );
            else if( type == 2 )
                createMultiPart( container, code, pt );
            else
                throw new Error( "Unknown shape type: " + type.toString(16) );
        }
        
        private function createMultiPart( container:Sprite, code:ByteArray, pt:Point ):void
        {
            // Multipart reference point
            pt = pt.clone();            
            pt.x -= code.readUnsignedByte();
            pt.y -= code.readUnsignedByte();
            
            // Find all subshapes in memory
            var count:int = code.readUnsignedByte();
            while ( count-- >= 0 )
            {
                // Locate the offset in memory to subshape
                var offset:uint = code.readUnsignedShort();
                
                // Create polygon reference point
                var p:Point = pt.clone();                
                p.x += code.readUnsignedByte();
                p.y += code.readUnsignedByte();
                
                // Read a color if nessessary
                var color:int = -1;                
                if( offset & 0x8000 )
                    color = (code.readUnsignedShort() >> 8) & 0x7F;

                // Redirect to the polygon in shape memory, and draw it
                var preserve:uint = code.position;
                code.position = (offset << 1) & 0xFFFF;
                generateShape( container, code, p, color );
                code.position = preserve;
            }
        }
        
        private function createPolygon( container:Sprite, code:ByteArray, pt:Point, color:int ):void
        {
            // Setup graphics for rendering
            var shape:Shape;

            if( color > 0x10 )
            {
                // Special shapes clear cache
                shape = new Shape();
                _cacheShape = null;

                var masked:Bitmap = new Bitmap( _copyPage );
                masked.mask = shape;
                shape.visible = false;

                container.addChild(shape);                
                container.addChild(masked);
            }
            else if( color == 0x10 )
            {
                shape = new Shape();
                _cacheShape = null;
                
                shape.blendMode = BlendMode.SHADER;
                shape.blendShader = TRANSPARENT_SHADER;
                container.addChild( shape );
            }
            else
            {
                // Reduce on-screen geometry (elements without effects are pooled)
                if( !_cacheShape )
                {
                    _cacheShape = new Shape();                     
                    container.addChild( _cacheShape );
                }

                shape = _cacheShape;                
            }

            var g:Graphics = shape.graphics;
            g.beginFill( color );
            g.lineStyle();
            
            // --- Begin loading our geometry
            var width:Number = code.readUnsignedByte();
            var height:Number = code.readUnsignedByte();
            var count:uint = code.readUnsignedByte();
                                    
            // Draw a 'thin line'
            if ( width <= 1 || height <= 1 )
            {
                g.drawRect( (pt.x - int(width/2)), (pt.y - int(height/2)), width + 1, height );

                code.position += count * 2;
            }
            // Draw a regular polygon
            else
            {
                var points:Vector.<Point> = new Vector.<Point>();
                var ep:Point;

                var unique:Object = new Object();
                
                while (count-- > 0)
                {
                    var tx:int = code.readUnsignedByte() + pt.x - int(width / 2);
                    var ty:int = code.readUnsignedByte() + pt.y - int(height / 2);
                    ep = new Point( tx, ty );
                
                    unique[ep] = true;
                
                    points.push( ep );
                }

                var i:uint = 0;
                
                for( var k:String in unique )
                    i++;
                
                // This is a line object, not a fill poly
                if( i < 3 )
                    g.lineStyle( 1, color );
            
                g.moveTo( ep.x, ep.y );
                for each( var p:Point in points )
                    g.lineTo( p.x, p.y );
            }

            g.endFill();
        }
    }
}