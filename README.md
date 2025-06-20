# VideoSnap

VideoSnap is an macOS command line tool for recording video and audio from any
attached capture device (including screen capture from connected iOS devices).

You can specify which device to capture from (by device name), the duration,
encoding and a delay period (before capturing starts).

By default VideoSnap will capture both video and audio from the default capture
device at 30fps, with a Medium quality preset and a short (0.5s) warm-up delay.

If no duration is specified, VideoSnap will record until you cancel with
[Ctrl+c] or you can pause (and resume) recording with [Ctrl+z].

VideoSnap can list attached capture devices by name.

## Requirements

 * macOS 10.9+ (Intel/M1)
 * A web cam or iOS device

If you need to capture video on older versions of macOS (e.g. 32-bit OSX) try
[wacaw](http://webcam-tools.sourceforge.net)

## Installation

Download the [latest
release](https://github.com/matthutchinson/videosnap/releases) and run the
installer.

This will copy the binary and man page to your `/usr/local` directory.

## Usage

The following options are available:

```
  -l    List attached capture devices
  -w    Set delay before capturing starts (in seconds, default 0.5s)
  -t    Set duration of video (in seconds)
  -d    Set the capture device by name (use -l to list attached devices)
  -p    Set the encoding preset (use High, Medium (default), Low, 640x480, 1280x720, 1920x1080, or 3840x2160)
  -r    Set custom resolution (e.g. 1920x1080, overrides preset)
  -b    Set custom bitrate in bps (e.g. 5000000 for 5Mbps)
  -f    Fit full image without cropping (default is to fill and crop)
  -v    Turn ON verbose mode (OFF by default)
  -h    Show help
  --no-audio
        Don't capture audio (audio IS captured by default)
```

### Examples

Capture 10.75 secs of video in 1280x720 720p HD format saving to
movie-{timestamp}.mov

    videosnap -t 10.75 -p '1280x720'

Capture 1 minute of video (Medium preset), but no audio from the "FaceTime HD
Camera (Built-in)" device, delaying for 5 secs, saving to video.mov

    videosnap -t 60 -w 5 -d 'FaceTime HD Camera (Built-in)' --no-audio video.mov

List all attached devices by name

    videosnap -l

### Warming Up

Since some camera hardware can take a while to warm up, a default delay of 0.5
seconds is applied. Override this with the `-w` argument (0 meaning no delay).

**NOTE**: Videosnap will also wait 0.5s to allow any connected devices to be
discovered (e.g. for iOS screen capture).

### Encoding Presets

The AVFoundation framework provides the following video encoding presets:

| Resolution    | Comments                                                  |
| ------------- | --------------------------------------------------------- |
| High          | Highest recording quality. This varies per device.        |
| Medium        | Suitable for Wi-Fi sharing. The actual values may change. |
| Low           | Suitable for 3G sharing. The actual values may change.    |
| 640x480       | VGA.                                                      |
| 1280x720      | 720p HD.                                                  |
| 1920x1080     | Full HD.                                                  |
| 3840x2160     | 4K Ultra HD.                                              |

Use the `-p` flag to choose a preset.

### Custom Resolution and Bitrate

You can also specify a custom resolution and bitrate for more precise control:

```
videosnap -r 1920x1080 -b 10000000 movie.mov
```

This will record at 1920x1080 resolution with a bitrate of 10Mbps. When using custom 
resolution and bitrate, the preset (`-p`) option is ignored.

- `-r WxH` - Set custom resolution (e.g. 1920x1080)
- `-b bitrate` - Set custom bitrate in bps (e.g. 5000000 for 5Mbps)

### Fit Option

By default, videosnap will fill the frame and crop if necessary to match your exact resolution. If you want to fit the entire image without cropping, use the `-f` flag:

```
videosnap -r 1280x720 -f movie.mov   # Fit to 720p without cropping
```

- `-f` - Fit full image without cropping (default is to fill and crop)

### Capturing from connected iOS devices

It is possible to screen capture video & audio from an attached iOS device.

For the device to be discovered you must confirm that you
**Trust This Computer** on the device when it is connected and unlocked.

There are some limitations when capturing from iOS devices:

  * When capturing, the iOS device will not output audio through its speakers (but audio will be recorded to the movie file, unless --no-audio is specified).
  * Occasionally the device fails to be discovered. This can happen when:
    * Another process is already capturing from the device
    * The macOS kernel fails to connect to the DAL assistant (Device Abstraction Layer)
  * For best results, connect your iOS device, unlock it, and wait a few seconds before starting the capture.

## Help

Get command help with:

    videosnap -h
    # or via the man page with
    man videosnap

If you have any problems, please do [raise an
issue](https://github.com/matthutchinson/videosnap/issues) on GitHub. When
reporting a bug, remember to mention what platform and hardware you are using
and the steps I can take to reproduce the issue.

## Development

I try to keep the project up to date with the latest general XCode release.

After opening `videosnap.xcodeproj`, you can set the arguments passed to the
command when it runs in XCode, simply edit the `Run` action in the default
`videosnap` Scheme. (Product -> Scheme -> Edit Scheme...)

You can also build the project from the command line. After cloning run:

```
  xcodebuild clean install
  # you'll find the build executable at
  ./build/Debug/videosnap
  # which symlinks to here
  ./build/pkgroot/usr/local/bin/videosnap
```

If you see this message:

    xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory "..."

Try this to fix your environment:

    sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

## Contributing

Bug [reports](https://github.com/matthutchinson/videosnap/issues) and [pull
requests](https://github.com/matthutchinson/videosnap/pulls) are welcome on
GitHub. Before submitting pull requests, please read the [contributing
guidelines](https://github.com/matthutchinson/videosnap/blob/master/CONTRIBUTING.md)
for more details.

This project is intended to be a safe, welcoming space for collaboration, and
contributors are expected to adhere to the [Contributor
Covenant](http://contributor-covenant.org) code of conduct. See
[here](https://github.com/matthutchinson/videosnap/blob/master/CODE_OF_CONDUCT.md)
for more details.

## Development

VideoSnap is coded with Objective-C and uses the
[AVFoundation](https://developer.apple.com/av-foundation/) framework. You can
build the project with [Xcode](http://developer.apple.com/xcode/) (using the
Xcode project workspace in the repository, or with the `xcodebuild` command).

## Future Work

Work in progress is usually mentioned at the top of the
[CHANGELOG](https://github.com/matthutchinson/videosnap/blob/master/CHANGELOG.md).
If you'd like to get involved in contributing, here are some ideas:

* Allow VideoSnap to pipe captured bytes to the STDOUT stream
* Submit VideoSnap as a package for [Homebrew](http://brew.sh)
* Allow more size/quality options for video and/or audio
* Smile detection while capturing video/image, determine a happiness factor/score
* Allow VideoSnap to capture a single frame to an image file (with compression
  options based on file type like [ImageSnap](https://github.com/rharder/imagesnap))
* A comprehensive test suite

## License

VideoSnap is distributed under the terms of the [MIT
License](http://opensource.org/licenses/MIT).

## Who's Who?

* [VideoSnap](http://github.com/matthutchinson/videosnap) by [Matthew Hutchinson](http://matthewhutchinson.net)
* Inspired by [ImageSnap](https://github.com/rharder/imagesnap) by [@rharder](https://github.com/rharder)
