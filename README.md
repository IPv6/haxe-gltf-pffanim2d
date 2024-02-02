# Simple 2d Animation Library for Blender->gLTF->OpenFL/Starling game workflow
- Supported: Objects (empty/quad) TRS animations
- Not supported: bone/armature/skeletal animations, shapekeys animations
- Somewhat supported: Alpha animation, clipping zone animation (sprite masking)

# Alpha && Clipping animation conventions

Since gLTF does not support non-TRS animation targets some extra efforts needed to make it with Blender (gLTF). For this purpuse some Nodes are served as "placeholders" for such animations. In Blender each Empty can contain Plane Mesh (quad mesh) with the name "#pff:mask". Such objects have special meaning when creating animation:
- ScaleZ = alpha value on parent DisplayObjectContainer
- Plane (Quad) rectangle serving as clipping rect for parent DisplayObjectContainer
- if ScaleX && ScaleY == 0.0 clipping mask ignored completely on load (no overhead), while alpha animation with ScaleZ still can be used

# Run demo

```
haxelib install openfl
haxelib install starling
cd ./demo
openfl test mac
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

