package resources
{
    import flash.utils.ByteArray;
        
    public class Files
    {
        [Embed("../../lib/MEMLIST.BIN",mimeType="application/octet-stream")]
        private static const _MEMLIST_DATA:Class;
        [Embed("../../lib/BANK01",mimeType="application/octet-stream")]
        private static const _BANK01:Class;
        [Embed("../../lib/BANK02",mimeType="application/octet-stream")]
        private static const _BANK02:Class;
        [Embed("../../lib/BANK03",mimeType="application/octet-stream")]
        private static const _BANK03:Class;
        [Embed("../../lib/BANK04",mimeType="application/octet-stream")]
        private static const _BANK04:Class;
        [Embed("../../lib/BANK05",mimeType="application/octet-stream")]
        private static const _BANK05:Class;
        [Embed("../../lib/BANK06",mimeType="application/octet-stream")]
        private static const _BANK06:Class;
        [Embed("../../lib/BANK07",mimeType="application/octet-stream")]
        private static const _BANK07:Class;
        [Embed("../../lib/BANK08",mimeType="application/octet-stream")]
        private static const _BANK08:Class;
        [Embed("../../lib/BANK09",mimeType="application/octet-stream")]
        private static const _BANK09:Class;
        [Embed("../../lib/BANK0A",mimeType="application/octet-stream")]
        private static const _BANK0A:Class;
        [Embed("../../lib/BANK0B",mimeType="application/octet-stream")]
        private static const _BANK0B:Class;
        [Embed("../../lib/BANK0C",mimeType="application/octet-stream")]
        private static const _BANK0C:Class;
        [Embed("../../lib/BANK0D",mimeType="application/octet-stream")]
        private static const _BANK0D:Class;

        public static const MEMLIST:ByteArray = new _MEMLIST_DATA();

        public static const BANK:Vector.<ByteArray> = Vector.<ByteArray>([
            null,   // There is no bank 0
            new _BANK01(),
            new _BANK02(),
            new _BANK03(),
            new _BANK04(),
            new _BANK05(),
            new _BANK06(),
            new _BANK07(),
            new _BANK08(),
            new _BANK09(),
            new _BANK0A(),
            new _BANK0B(),
            new _BANK0C(),
            new _BANK0D()
        ]);
    }
}