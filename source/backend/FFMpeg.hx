#if desktop
package backend;

import lime.math.Rectangle;
import haxe.io.Bytes;
import lime.app.Application;
import lime.graphics.Image;
import flixel.FlxG;
import lime.ui.Window;
import sys.FileSystem;
import options.GameRendererSettingsSubState;

class FFMpeg {
    public var x:Int;
    public var y:Int;
    public var width:Int;
    public var height:Int;
    public var image:Image;
    public var bytes:Bytes;
    public var window:Window;
    public var buffer:Rectangle;

    public var target = "render_video";
    public var fileName:String = '';
    public var fileExts:String = '.mp4';
    public var wentPreview:String;
    public var process:Process;

    public static var instance:FFMpeg;

    public function new() {}

    public function init() {
        if (NativeFileSystem.exists(target)) {
            if (!NativeFileSystem.isDirectory(target)) {
                NativeFileSystem.deleteFile(target);
                NativeFileSystem.createDirectory(target);
            }
        } else NativeFileSystem.createDirectory(target);

        window = FlxG.stage.application.window;
        x = window.width;
        y = window.height;

        // Apply widescreen option
        if(ClientPrefs.data.wideScreen) {
            x = Std.int(x * 1.78); // 16:9 widescreen multiplier
        }

        // Apply render scale (dynamicColors could be used to determine effects)
        if(!ClientPrefs.data.dynamicColors) {
            FlxG.stage.application.window.scale = 1;
        }
    }

    public function setup(testMode:Bool = false) {
        var executable:String = #if windows 'ffmpeg.exe' #else 'ffmpeg' #end;

        if (!FileSystem.exists(executable)) {
            if (testMode) throw "FFMpeg not found!";
            trace('"$executable" not found, enabling preview mode...');
            ClientPrefs.data.previewRender = true;
            FlxG.sound.play(Paths.sound('cancelMenu'), ClientPrefs.data.sfxVolume);
            wentPreview = executable + " was not found";
            return;
        }

        var curCodec:String = ClientPrefs.data.codec;
        var isGPU:Bool = CoolUtil.searchFromStrings(curCodec, ['QSV', 'NVENC', 'AMF' ,'VAAPI']);
        if (CoolUtil.searchFromString(curCodec, 'VP')) fileExts = ".webm";

        // File name handling
        if (!testMode) {
            fileName = target + '/' + Paths.formatToSongPath(PlayState.SONG.song);
            if (FileSystem.exists(fileName + fileExts)) {
                var millis = CoolUtil.fillNumber(Std.int(haxe.Timer.stamp() * 1000) % 1000, 3, 48);
                fileName += "-" + DateTools.format(Date.now(), "%Y-%m-%d_%H-%M-%S-") + millis;
            }
        } else {
            fileName = target + '/test-codec-' + curCodec;
        }

        // FFmpeg arguments
        var arguments:Array<String> = [
            '-v', 'quiet', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgba',
            '-s', x + 'x' + y, '-r', Std.string(ClientPrefs.data.targetFPS), '-i', '-',
            '-c:v', GameRendererSettingsSubState.codecMap[curCodec]
        ];

        // Encode mode handling
        switch(ClientPrefs.data.encodeMode) {
            case "CRF/CQP":
                arguments.push('-b:v', '0');
                arguments.push(isGPU ? '-qp' : '-crf', Std.string(ClientPrefs.data.constantQuality));
            case 'VBR', 'CBR':
                arguments.push('-b:v', Std.string(ClientPrefs.data.bitrate * 1_000_000));
                if(ClientPrefs.data.encodeMode == 'CBR') {
                    arguments.push('-maxrate', Std.string(ClientPrefs.data.bitrate * 1_000_000));
                    arguments.push('-minrate', Std.string(ClientPrefs.data.bitrate * 1_000_000));
                }
        }

        // Lossless
        if(ClientPrefs.data.lossless) arguments.push('-preset', 'ultrafast', '-crf', '0');

        // Optional pre-shot or preview
        if(ClientPrefs.data.preshot || ClientPrefs.data.previewRender) {
            arguments.push('-t', '1'); // just render 1 frame for preview
        }

        // Shader / antialiasing effects
        if(!ClientPrefs.data.shaders) arguments.push('-vf', 'format=rgba');

        // Apply swap glitch wiggle effect
        if(ClientPrefs.data.swapGlitchWiggle) {
            arguments.push('-vf', 'glitch=w=10:h=10'); // placeholder, implement properly in shaders
        }

        arguments.push(fileName + fileExts);

        if (!ClientPrefs.data.previewRender && !testMode) trace("Running FFmpeg: " + arguments);

        process = new Process('ffmpeg', arguments);

        buffer = new Rectangle(0, 0, x, y);
        FlxG.autoPause = false;

        // Ready to render
        if (!testMode) FlxG.sound.play(Paths.sound('confirmMenu'), ClientPrefs.data.sfxVolume);
    }

    public function pipeFrame():Void {
        image = window.readPixels();
        bytes = image.getPixels(buffer);
        if(process != null && process.stdin != null) process.stdin.write(bytes);
    }

    public function destroy():Void {
        if(process != null) {
            if(process.stdin != null) process.stdin.close();
            process.close();
            process.kill();
        }
        FlxG.autoPause = ClientPrefs.data.autoPause;
    }
}
#end
