package gltf.types;

import haxe.ds.Vector;
import gltf.schema.TAnimationChannelTargetPath;
import gltf.schema.TAnimationInterpolation;
import gltf.schema.TAnimationSampler;
import gltf.schema.TAttributeType;

@:allow(gltf.types.AnimationChannel)
class AnimationSample {
    public var input(default, null):Float = 0;
    public var output(default, null):Vector<Float> = null;
    public var output_in(default, null):Vector<Float> = null;
    public var output_out(default, null):Vector<Float> = null;

    private function new(input:Float, output:Vector<Float>) {
        this.input = input;
        this.output = output;
    }
}

@:allow(gltf.types.Animation)
class AnimationChannel {
    public var node(default, null):Node = null;
    public var samples(default, null):Vector<AnimationSample> = null;
    public var path(default, null):TAnimationChannelTargetPath = null;
    public var interpolation(default, null):TAnimationInterpolation = null;

    private function new() {}

    private function getOutputAtIndex(sampler_type:TAttributeType, outputs:Vector<Float>, input_idx:Int):Vector<Float> {
        var sample = switch(sampler_type) {
            case SCALAR: {
                var o:Vector<Float> = new Vector<Float>(1);
                o[0] = outputs[input_idx];
                o;
            }

            case VEC2: {
                var o:Vector<Float> = new Vector<Float>(2);
                o[0] = outputs[(input_idx * 2) + 0];
                o[1] = outputs[(input_idx * 2) + 1];
                o;
            }

            case VEC3: {
                var o:Vector<Float> = new Vector<Float>(3);
                o[0] = outputs[(input_idx * 3) + 0];
                o[1] = outputs[(input_idx * 3) + 1];
                o[2] = outputs[(input_idx * 3) + 2];
                o;
            }

            case VEC4: {
                var o:Vector<Float> = new Vector<Float>(4);
                o[0] = outputs[(input_idx * 4) + 0];
                o[1] = outputs[(input_idx * 4) + 1];
                o[2] = outputs[(input_idx * 4) + 2];
                o[3] = outputs[(input_idx * 4) + 3];
                o;
            }

            default: {
                throw 'Unhandled animation sampler accessor type: \'' + sampler_type + '\'!';
            }
        }
        return sample;
    }

    private function loadSampler(gltf:GLTF, sampler:TAnimationSampler):Void {
        var inputSampler:Accessor = gltf.accessors[sampler.input];
        var outputSampler:Accessor = gltf.accessors[sampler.output];

        var inputs:Vector<Float> = inputSampler.getFloats();
        var outputs:Vector<Float> = outputSampler.getFloats();
        if(sampler.interpolation != null){
            interpolation = sampler.interpolation;
        }else{
            interpolation = TAnimationInterpolation.LINEAR;
        }
        samples = new Vector<AnimationSample>(inputs.length);
        for(i in 0...inputs.length) {
            if(interpolation == TAnimationInterpolation.CUBICSPLINE){
                // Output length = 3x Input length
                // https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#_overview_2
                var output_sample = getOutputAtIndex(outputSampler.type, outputs, i*3+1);
                var sample = new AnimationSample(inputs[i],output_sample);
                sample.output_in = getOutputAtIndex(outputSampler.type, outputs, i*3+0);
                sample.output_out = getOutputAtIndex(outputSampler.type, outputs, i*3+2);
                samples[i] = sample;
            }else{
                var output_sample = getOutputAtIndex(outputSampler.type, outputs, i);
                samples[i] = new AnimationSample(inputs[i],output_sample);
            }
        }
    }
}