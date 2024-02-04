# Simple 2d Animation Library
- Intended workflow: Blender -> gLTF -> OpenFL/Starling game
- Supported: Objects (empty/quad) TRS animations
- Not supported: bone/armature/skeletal animations, shapekeys animations
- Somewhat supported: Alpha animation, Clipping rect animation (sprite masking)

# Blender setup details

- Cameras, Armatures, skinning, morth tarkets, shapekeys - ignored
- Recognizable objects: Empties for grouping and simple planes (4-vert rectangle, quad) mesh objects
- Quads must be arranged in Blender XY-plane (for top-down view)
- All other nodes in gLTF are ignored
- Quads must have unlit textures - they will used as Texture for corresponding starling node (by default)
- Plane(Quad) can have origin offset - offset converted to Sprite pivot (by default)
- Plane/Empty can have custom props - they are loaded and can be used for customizing starling node creation
- Animations: Armature animations are not supported directly, but can be baked on valid objects to be usable by GLTFScene
- Animations: Actions must be stashed (Dopesheet-Action Editor) or pushed to NLA track (NLA Editor). Export name will be the name of action in any case
- Animations: Actions must always have frame 0 keyed (exporter resets any offset anyway)
- Blender export options: TODO

# Alpha && Clipping animation conventions

gLTF does not support non-TRS animation targets. So some extra efforts required to make it happen with Blender && gLTF.
Basic alpha (alpha_self) derived from node's ScaleZ (Blender z-axis), since it's not used for 2D scaling and defaults to 1.0.

Animated clipping: some Nodes are served as "placeholders" for holding such animations.
Each Empty (in Blender) can contain Plane (quad) Mesh object with the name "#pff:mask".
"#pff:mask" object will have special meaning for animation in Starling:
- ScaleZ = alpha value (alpha_mask) on parent DisplayObjectContainer
- Plane (Quad) rectangle = clipping rect for parent DisplayObjectContainer
- if ScaleX && ScaleY == 0.0 clipping mask ignored completely (on load, no realtime overhead), while alpha animation (alpha_mask) with ScaleZ still can be used

# Compositions:
- Each composition - simple ruleset (on/off) for changing scene nodes visibility en-masse.
So it`s possible, for example, to create several interfaces in one hierarchy - and on/off bunch of layers to "switch" between them
- Named after same feature of Krita

# Plans

- base64 in URIs (buffers, images)
- GLB parsing support && embedded PNGs/JPGs/BINs
- Auto-packing into atlas on request?

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

