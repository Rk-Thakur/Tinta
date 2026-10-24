package com.example.tinta

import android.media.AudioAttributes
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val videoThread = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var encoder: VideoEncoder? = null
    private var pencil: MediaPlayer? = null


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "tinta/device").setMethodCallHandler { call, result ->
            if (call.method == "freeSpace") {
                result.success(StatFs(filesDir.absolutePath).availableBytes)
            } else {
                result.notImplemented()
            }
        }

        // Pencil sound: one looping player; Dart sets the volume from stroke speed.
        MethodChannel(messenger, "tinta/sound").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> {
                        val player = pencil ?: createPencil(call.argument<String>("asset")!!).also { pencil = it }
                        player.setVolume(0f, 0f)
                        player.seekTo((Math.random() * player.duration).toInt())
                        player.start()
                    }
                    "volume" -> {
                        val v = (call.argument<Double>("volume") ?: 0.0).toFloat()
                        pencil?.setVolume(v, v)
                    }
                    "stop" -> pencil?.takeIf { it.isPlaying }?.pause()
                    else -> return@setMethodCallHandler result.notImplemented()
                }
                result.success(null)
            } catch (t: Throwable) {
                result.error("sound", t.message, null)
            }
        }

        // MP4 encoder fed one raw RGBA frame at a time from Dart (replay export).
        MethodChannel(messenger, "tinta/video").setMethodCallHandler { call, result ->
            videoThread.execute {
                try {
                    when (call.method) {
                        "start" -> {
                            encoder = VideoEncoder(
                                call.argument<String>("path")!!,
                                call.argument<Int>("width")!!,
                                call.argument<Int>("height")!!,
                                call.argument<Int>("fps")!!,
                            )
                            main.post { result.success(null) }
                        }
                        "frame" -> {
                            val e = encoder ?: throw IllegalStateException("Encoder not started")
                            e.append(call.argument<ByteArray>("rgba")!!)
                            main.post { result.success(null) }
                        }
                        "finish" -> {
                            val e = encoder ?: throw IllegalStateException("Encoder not started")
                            encoder = null
                            e.finish()
                            main.post { result.success(null) }
                        }
                        "cancel" -> {
                            encoder?.release()
                            encoder = null
                            main.post { result.success(null) }
                        }
                        else -> main.post { result.notImplemented() }
                    }
                } catch (t: Throwable) {
                    encoder?.release()
                    encoder = null
                    main.post { result.error("encode", t.message, null) }
                }
            }
        }
    }

    private fun createPencil(asset: String): MediaPlayer {
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
        return assets.openFd(key).use { fd ->
            MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_GAME)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
                isLooping = true
                prepare()
            }
        }
    }

    override fun onStop() {
        super.onStop()
        pencil?.takeIf { it.isPlaying }?.pause()
    }

    override fun onDestroy() {
        pencil?.release()
        pencil = null
        super.onDestroy()
    }
}

/** H.264 MP4 writer: RGBA frames → YUV420 input images → MediaMuxer. */
class VideoEncoder(path: String, private val width: Int, private val height: Int, private val fps: Int) {
    private val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
    private val muxer: MediaMuxer
    private val info = MediaCodec.BufferInfo()
    private var track = -1
    private var muxing = false
    private var frame = 0L

    init {
        File(path).delete()
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
            setInteger(MediaFormat.KEY_BIT_RATE, width * height * 6)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()
        muxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    }

    private fun ptsUs(n: Long) = n * 1_000_000L / fps

    fun append(rgba: ByteArray) {
        var index: Int
        while (true) {
            index = codec.dequeueInputBuffer(10_000)
            if (index >= 0) break
            drain(false)
        }
        val image = codec.getInputImage(index)!!
        val y = image.planes[0]
        val u = image.planes[1]
        val v = image.planes[2]
        for (row in 0 until height) {
            for (col in 0 until width) {
                val i = (row * width + col) * 4
                val r = rgba[i].toInt() and 0xFF
                val g = rgba[i + 1].toInt() and 0xFF
                val b = rgba[i + 2].toInt() and 0xFF
                // BT.601 limited range.
                y.buffer.put(row * y.rowStride + col * y.pixelStride, (((66 * r + 129 * g + 25 * b + 128) shr 8) + 16).toByte())
                if (row % 2 == 0 && col % 2 == 0) {
                    val cr = row / 2
                    val cc = col / 2
                    u.buffer.put(cr * u.rowStride + cc * u.pixelStride, (((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128).toByte())
                    v.buffer.put(cr * v.rowStride + cc * v.pixelStride, (((112 * r - 94 * g - 18 * b + 128) shr 8) + 128).toByte())
                }
            }
        }
        codec.queueInputBuffer(index, 0, width * height * 3 / 2, ptsUs(frame), 0)
        frame++
        drain(false)
    }

    private fun drain(endOfStream: Boolean) {
        while (true) {
            val index = codec.dequeueOutputBuffer(info, 10_000)
            when {
                index == MediaCodec.INFO_TRY_AGAIN_LATER -> if (!endOfStream) return
                index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    track = muxer.addTrack(codec.outputFormat)
                    muxer.start()
                    muxing = true
                }
                index >= 0 -> {
                    val data = codec.getOutputBuffer(index)!!
                    if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                    if (info.size > 0 && muxing) {
                        data.position(info.offset)
                        data.limit(info.offset + info.size)
                        muxer.writeSampleData(track, data, info)
                    }
                    codec.releaseOutputBuffer(index, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                }
            }
        }
    }

    fun finish() {
        var index: Int
        while (true) {
            index = codec.dequeueInputBuffer(10_000)
            if (index >= 0) break
            drain(false)
        }
        codec.queueInputBuffer(index, 0, 0, ptsUs(frame), MediaCodec.BUFFER_FLAG_END_OF_STREAM)
        drain(true)
        release()
    }

    fun release() {
        try { codec.stop() } catch (_: Throwable) {}
        codec.release()
        try { if (muxing) muxer.stop() } catch (_: Throwable) {}
        muxer.release()
    }
}
