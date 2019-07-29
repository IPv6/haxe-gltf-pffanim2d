package gltf.types;

import gltf.schema.TGLTF;
import gltf.schema.TBuffer;
import haxe.io.Bytes;
import haxe.ds.Vector;

@:allow(gltf.GLTF)
class Buffer {
    public var uri(default, null):String = "";
    public var name(default, null):String = "";
    public var data(default, null):Bytes = null;

    function new() {}

    function load(gltf:GLTF, buffer:TBuffer, data:Bytes):Void {
        this.uri = buffer.uri;
        this.name = buffer.name;
        this.data = data;
    }

    static function loadFromRawWithGetter(gltf: GLTF, raw: TGLTF, getter: Int->Bytes): Vector<Buffer> {
        var buffers:Vector<Buffer> = new Vector<Buffer>(raw.buffers.length);
        for(i in 0...raw.buffers.length) {
            buffers[i] = new Buffer();
            buffers[i].load(gltf, raw.buffers[i], getter(i));
        }
        return buffers;
    }
}
