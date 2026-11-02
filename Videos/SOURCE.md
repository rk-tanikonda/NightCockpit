# Bundled original media

`wallpaper.mp4` is Night Cockpit's original **Midnight Drive** demo. Its animation
and stereo engine ambience are generated entirely by `Tools/GenerateDemo.swift`,
without downloaded footage, recordings, textures, logos or third-party samples.
Both video and audio are dedicated to the public domain under CC0 1.0; see
[MEDIA_LICENSE.md](../MEDIA_LICENSE.md).

- Duration: 12 seconds, seamless procedural loop
- Video: 1920 × 1080, H.264, 30 fps
- Audio: synthesized stereo AAC, 48 kHz
- SHA-256: `2c1d6c63962aa4bf5465c6a8c5b1fd10da15bdcdd8afb366dfce9c92136974ff`

To regenerate a separate copy with the macOS 26+ SDK:

```bash
mkdir -p .build
xcrun swiftc -swift-version 5 -parse-as-library Tools/GenerateDemo.swift -o .build/generate-demo
.build/generate-demo /path/to/new-demo.mp4
```

The generator refuses to overwrite existing media. Encoded bytes can differ
between encoder/SDK versions. The bundled file has been decoded and checked for
non-silent audio.

The third-party Formula One clip used during local development is not bundled,
tracked, or licensed by this project. Users may select their own permitted
MP4/MOV through the app or `bash setup.command --video /path/to/video.mp4`.
