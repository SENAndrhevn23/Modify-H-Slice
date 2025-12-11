package options;

import objects.CheckboxThingie;
import flixel.system.ui.FlxSoundTray;
import backend.FFMpeg;
import flixel.input.gamepad.FlxGamepad;

class GameRendererSettingsSubState extends BaseOptionsMenu
{
    var fpsOption:Option;
    var bitOption:Option;
    var gcRateOption:Option;
    var testOption:Option;
    var testChkbox:CheckboxThingie;

    var messageTextBG:FlxSprite;
    var messageText:FlxText;

    var offTimer:FlxTimer = new FlxTimer();

    public static final codecList:Array<String> = [
        'H.264','H.264 QSV','H.264 NVENC','H.264 AMF','H.264 VAAPI',
        'H.265','H.265 QSV','H.265 NVENC','H.265 AMF','H.265 VAAPI',
        'VP8','VP8 VAAPI','VP9','VP9 VAAPI','AV1','AV1 NVENC'
    ];

    public static final codecMap:Map<String, String> = [
        'H.264' => 'libx264','H.264 QSV' => 'h264_qsv','H.264 NVENC' => 'h264_nvenc',
        'H.264 AMF' => 'h264_amf','H.264 VAAPI' => 'h264_vaapi',
        'H.265' => 'libx265','H.265 QSV' => 'hevc_qsv','H.265 NVENC' => 'hevc_nvenc',
        'H.265 AMF' => 'hevc_amf','H.265 VAAPI' => 'hevc_vaapi',
        'VP8' => 'libvpx','VP8 VAAPI' => 'libvpx_vaapi','VP9' => 'libvp9',
        'VP9 VAAPI' => 'libvp9_vaapi','AV1' => 'libsvtav1','AV1 NVENC' => 'av1_nvenc'
    ];

    public function new()
    {
        #if DISCORD_ALLOWED
        DiscordClient.changePresence("Game Renderer", null);
        #end

        title = 'Game Renderer';
        rpcTitle = 'Game Renderer Settings Menu';

        // Core FNF options
        var option:Option = new Option('Use Game Renderer',
            "If checked, It renders a video.\nAnd It forces turn on Botplay and disable debug menu key.",
            'ffmpegMode',
            BOOL);
        option.onChange = resetTimeScale;
        addOption(option);

        var option:Option = new Option('Garbage Collection Rate',
            "Have GC run automatically based on this option.\nSpecified by Frame and It turn on GC forcely.\n0 means disabled. Beware of memory leaks!",
            'gcRate',
            INT);
        addOption(option);
        option.minValue = 0;
        option.maxValue = 10000;
        option.scrollSpeed = 60;
        option.decimals = 0;
        option.onChange = onChangeGCRate;
        gcRateOption = option;

        var option:Option = new Option('Run Major Garbage Collection',
            "Increase the GC range and reduce memory usage.\nIt's for upper option.",
            'gcMain',
            BOOL);
        addOption(option);

        var option:Option = new Option('Video Framerate',
            "How much do you need fps in your video?",
            'targetFPS',
            INT);
        final refreshRate:Int = FlxG.stage.application.window.displayMode.refreshRate;
        option.minValue = 1;
        option.maxValue = 1000;
        option.scrollSpeed = 30;
        option.decimals = 0;
        option.defaultValue = Std.int(FlxMath.bound(refreshRate, option.minValue, option.maxValue));
        option.displayFormat = '%v FPS';
        option.onChange = onChangeFramerate;
        fpsOption = option;
        addOption(option);

        var option:Option = new Option('Video Codec',
            "It's advanced Option. If you don't know, leave this 'H.264'.",
            'codec',
            STRING,
            codecList);
        addOption(option);

        var option:Option = new Option('Encode Mode',
            "It's advanced Option.\nSelect the mode of rendering you want.",
            'encodeMode',
            STRING,
            ['CRF/CQP', 'VBR', 'CBR']);
        option.onChange = resetTimeScale;
        addOption(option);

        var option:Option = new Option('Video Bitrate',
            "Set bitrate in here.",
            'bitrate',
            FLOAT);
        option.minValue = 0.01;
        option.maxValue = 100;
        option.changeValue = 0.01;
        option.scrollSpeed = 3;
        option.decimals = 2;
        option.displayFormat = '%v Mbps';
        bitOption = option;
        option.onChange = onChangeBitrate;
        addOption(option);

        var option:Option = new Option('Video Quality',
            "The quality which set here is constant.",
            'constantQuality',
            FLOAT);
        option.minValue = 0;
        option.maxValue = 51;
        option.scrollSpeed = 20;
        option.decimals = 1;
        option.displayFormat = '%v';
        addOption(option);

        var option:Option = new Option('Unlock Framerate',
            "If checked, fps limit goes 1000 in rendering.",
            'unlockFPS',
            BOOL);
        addOption(option);

        var option:Option = new Option('Pre Rendering',
            "If checked, Render current screen in the first of update method.\nIf unchecked, It does in the last of it.",
            'preshot',
            BOOL);
        addOption(option);

        var option:Option = new Option('Preview Mode',
            "If checked, Skip rendering.\nIf ffmpeg not found, force enabling this.\nIt's for a function for debug too.",
            'previewRender',
            BOOL);
        addOption(option);

        var option:Option = new Option('Test Rendering Each Encoders',
            "Try to test which is encoder available!",
            'dummy',
            BOOL);
        option.onChange = testRender;
        option.setValue(false);
        addOption(option);

        // =====================
        // FNF-Style Advanced FFmpeg Options (22 items)
        // Everything below goes after "Test Rendering Each Encoders"
        // =====================

        addOption(new Option('Video Resolution',
            'Sets the output resolution of the rendered video.',
            'videoResolution',
            STRING,
            ['1280x720','1920x1080','2560x1440','3200x1800','3840x2160','7680x4320','Custom']));

        addOption(new Option('Chroma Subsampling',
            'Controls color accuracy. 4:4:4 provides the highest color fidelity.',
            'chromaSubsampling',
            STRING,
            ['4:2:0','4:2:2','4:4:4']));

        addOption(new Option('Pixel Format',
            'Specifies the pixel format. Higher formats give improved color precision.',
            'pixelFormat',
            STRING,
            ['yuv420p','yuv422p','yuv444p','p010le','yuv444p10le']));

        addOption(new Option('Max Bitrate',
            'Sets the maximum bitrate limit.',
            'maxBitrate',
            FLOAT, [], 1, 10000, 1));

        addOption(new Option('Target Bitrate',
            'Defines the main bitrate used during CBR/VBR encoding.',
            'targetBitrate',
            FLOAT, [], 1, 10000, 1));

        addOption(new Option('GOP Size',
            'Controls the keyframe interval.',
            'gopSize',
            STRING,
            ['1','2','4','8','30','60','Auto']));

        addOption(new Option('Encoder Preset',
            'Controls the speed/quality tradeoff of the encoder.',
            'encoderPreset',
            STRING,
            ['UltraFast','SuperFast','VeryFast','Fast','Medium','Slow','VerySlow']));

        addOption(new Option('Color Range',
            'Full range provides extended contrast and detail.',
            'colorRange',
            STRING,
            ['Limited','Full']));

        addOption(new Option('HEVC Profile',
            'Specifies the HEVC profile used for encoding.',
            'hevcProfile',
            STRING,
            ['Main','Main 10','Main 4:4:4','Main 4:4:4 10-bit']));

        addOption(new Option('Color Matrix',
            'Defines the transformation matrix for color encoding.',
            'colorMatrix',
            STRING,
            ['BT.601','BT.709','BT.2020']));

        addOption(new Option('Color Primaries',
            'Specifies the color gamut used during encoding.',
            'colorPrimaries',
            STRING,
            ['BT.601','BT.709','BT.2020']));

        addOption(new Option('Transfer Function',
            'Controls the tone mapping curve used for brightness.',
            'transferFunction',
            STRING,
            ['Gamma 2.2','Gamma 2.4','BT.1886','HLG','PQ']));

        addOption(new Option('HDR Metadata',
            'Enables HDR metadata inclusion for HDR workflows.',
            'hdrMetadata',
            STRING,
            ['Off','HDR10 Static Metadata','HLG Metadata']));

        addOption(new Option('Buffer Size',
            'Controls bitrate stabilization.',
            'bufferSize',
            FLOAT, [], 1, 1000, 1));

        addOption(new Option('Debanding',
            'Reduces color banding in gradients at higher bit-depths.',
            'debanding',
            STRING,
            ['Off','Low','Medium','High']));

        addOption(new Option('Sharpness',
            'Applies a sharpening filter before encoding.',
            'sharpness',
            STRING,
            ['Off','Mild','Medium','Strong']));

        addOption(new Option('Denoise',
            'Reduces visual noise before encoding.',
            'denoise',
            STRING,
            ['Off','Low','Medium','High']));

        addOption(new Option('Audio Bitrate',
            'Controls the audio quality.',
            'audioBitrate',
            STRING,
            ['96 kbps','128 kbps','192 kbps','256 kbps','320 kbps','Lossless']));

        addOption(new Option('Audio Channels',
            'Outputs multi-channel audio for advanced render setups.',
            'audioChannels',
            STRING,
            ['Mono','Stereo','Surround 5.1','Surround 7.1']));

        addOption(new Option('Audio Sample Rate',
            'Sets the audio sampling frequency.',
            'audioSampleRate',
            STRING,
            ['44100 Hz','48000 Hz','96000 Hz','192000 Hz','384000 Hz']));

        addOption(new Option('Lossless Frames',
            'Uses PNG frames internally for maximum image fidelity.',
            'losslessFrames',
            STRING,
            ['Off','On']));

        addOption(new Option('Custom FFmpeg Args',
            'Allows advanced users to inject custom FFmpeg parameters.',
            'customFFmpegArgs',
            STRING));

        super();

        messageTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        messageTextBG.alpha = 0.6;
        messageTextBG.visible = false;
        add(messageTextBG);

        messageText = new FlxText(50, 0, FlxG.width - 100, '', 24);
        messageText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        messageText.scrollFactor.set();
        messageText.visible = false;
        messageText.antialiasing = ClientPrefs.data.antialiasing;
        add(messageText);

        testChkbox = checkboxGroup.members.filter(o -> o.ID == optionsArray.indexOf(testOption))[0];
    }

    function onChangeGCRate()
    {
        gcRateOption.scrollSpeed = interpolate(30, 1000, (holdTime - 0.5) / 5, 3);
    }

    function onChangeFramerate()
    {
        fpsOption.scrollSpeed = interpolate(30, 1000, (holdTime - 0.5) / 5, 3);
    }

    function onChangeBitrate()
    {
        bitOption.scrollSpeed = interpolate(1, 100, (holdTime - 0.5) / 5, 3);
    }

    function resetTimeScale()
    {
        FlxG.timeScale = 1;
    }

    function testRender()
    {
        var video:FFMpeg = new FFMpeg();
        var backupCodec = ClientPrefs.data.codec;
        var result:Bool = true;
        var output:String = 'FPS: ${ClientPrefs.data.targetFPS}, Mode: ${ClientPrefs.data.encodeMode}, ${ClientPrefs.data.encodeMode == "CRF/CQP" ? 'Quality: ${ClientPrefs.data.constantQuality}' : 'Bitrate: ${ClientPrefs.data.bitrate} Mbps'}\n';
        var noFFMpeg:Bool = false;
        var message:String = "";

        video.target = "render_test";
        video.init();

        var cnt:Int = 0;
        var maxLength:Int = 0;
        var space:String;

        for (codec in codecList) {
            maxLength = FlxMath.maxInt(codec.length, maxLength);
        }

        for (codec in codecList) {
            space = "";
            ClientPrefs.data.codec = codec;
            try {
                video.setup(true);
                video.pipeFrame();
                video.destroy();

                result = FileSystem.stat(video.fileName + video.fileExts).size != 0;
            } catch (e) {
                result = false;
                trace(e.message);
                message = e.message;
                if (message == "not found ffmpeg") {
                    noFFMpeg = true; break;
                }
            }

            if (result) {
                ++cnt;
                FlxG.sound.play(Paths.sound('soundtray/Volup'), ClientPrefs.data.sfxVolume);
            } else {
                FlxG.sound.play(Paths.sound('soundtray/Voldown'), ClientPrefs.data.sfxVolume);
            }

            for (i in 0...(maxLength - codec.length)) {
                space += " ";
            }

            output += 'Codec: ${ClientPrefs.data.codec},$space Result: ${result ? "PASS" : "fail"} $message\n';
        }

        output = output.substring(0, output.length - 1);

        messageText.visible = true;
        messageTextBG.visible = true;

        if (noFFMpeg) {
            messageText.text = "ERROR WHILE TESTING FFMPEG FEATURE:\nYou don't have 'FFMpeg.exe' in same Folder as H-Slice.";
            FlxG.sound.play(Paths.sound('cancelMenu'), ClientPrefs.data.sfxVolume);
        } else {
            messageText.text = 'Test simple result: $cnt/$maxLength codecs passed.\n\n' + output;
        }

        messageText.screenCenter(Y);

        CoolUtil.deleteDirectoryWithFiles(video.target);
        FlxG.sound.play(Paths.sound('soundtray/VolMAX'), ClientPrefs.data.sfxVolume);
        ClientPrefs.data.codec = backupCodec;

        var o = curOption;
        o.setValue(true);
        reloadCheckboxes();

        if (offTimer.active) offTimer.cancel();
        offTimer.start(t -> {
            o.setValue(false);
            reloadCheckboxes();
        });
    }

    override function changeSelection(delta:Float, usePrecision:Bool = false) {
        super.changeSelection(delta, usePrecision);

        if (messageText != null) {
            if (messageText.visible || messageTextBG.visible) {
                messageText.visible = false;
                messageTextBG.visible = false;
            }
        }
    }
}
