# Simple 2d Animation Library
- Intended workflow: Blender -> gLTF -> OpenFL/Starling game
- Supported: Objects (empty/quad) TRS animations
- Not supported: bone/armature/skeletal animations, shapekeys animations
- Somewhat supported: Alpha animation, Clipping rect animation (sprite masking)

# Alpha && Clipping animation conventions

gLTF does not support non-TRS animation targets. So some extra efforts required to make it happen with Blender && gLTF.
For this purpuse some Nodes are served as "placeholders" for such animations.
Each Empty (in Blender) can contain Plane (quad) Mesh object with the name "#pff:mask".
Plane(Quad) can have origin offset - offset converted to Sprite pivot by default
Such object will have special meaning for animation in Starling:
- ScaleZ = alpha value on parent DisplayObjectContainer
- Plane (Quad) rectangle = clipping rect for parent DisplayObjectContainer
- if ScaleX && ScaleY == 0.0 clipping mask ignored completely (on load, no realtime overhead), while alpha animation with ScaleZ still can be used

# TODO

- base64 in URIs (buffers, images)
- GLB parsing support && embedded PNGs/JPGs/BINs
- Auto-packing into atlas?

# Run demo

```
haxelib install openfl
haxelib install starling
cd ./demo
openfl test <win/mac/...>
```

# Run tests

```
haxelib install buddy
./get-samples.sh
cd ./test
haxe -x TestMain -lib buddy -p ../src
```

# gLTF loading based on haxe-gltf
haxe-gltf: A Haxe library for reading (and eventually, writing) [GLTF](https://github.com/KhronosGroup/glTF) files.

