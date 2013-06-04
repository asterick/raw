package util
{
    public class Format
    {
        private static const FORMAT:RegExp = /({{.*?}})/;
        private static const BREAKOUT:RegExp = /{{(?P<arg>\d)(?<format>:((?<decimal>[\d#,.]*)|(?<hex>(?<hex_size>\d*)X)))?}}/i;
        
        public static function format( template:String, ... args ):String
        {
            var units:Array = template.split(FORMAT);
            
            for( var i:uint = 1; i < units.length; i+=2 )
                units[i] = process( units[i], args );

            return units.join('');
        }
        
        public static function print(... rest):void
        {
            trace( format.apply(null, rest) );
        }
        
        private static function process( base:String, args:Array ):String
        {
            if( !BREAKOUT.test( base ) )
                return base;
            
            var match:* = BREAKOUT.exec(base);

            // unformatted
            if( !match.format )
                return args[match.arg].toString();
 
            // Hex formatted
            if( match.hex )
            {
                var length:int = match.hex_size ? Number(match.hex_size) : 0;
                base = args[match.arg].toString(16);

                while( base.length < length )
                    base = " " + base;
                
                return base;
            }

            return base;
        }
    }
}