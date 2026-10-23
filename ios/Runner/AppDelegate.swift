import Accelerate
import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var deviceChannel: FlutterMethodChannel?
  private var videoChannel: FlutterMethodChannel?
  private var encoder: VideoEncoder?
  private var soundChannel: FlutterMethodChannel?
  private var pencil: AVAudioPlayer?
  private let videoQueue = DispatchQueue(label: "tinta.video")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TintaNative") else { return }
    let messenger = registrar.messenger()

    let device = FlutterMethodChannel(name: "tinta/device", binaryMessenger: messenger)
    device.setMethodCallHandler { call, result in
      guard call.method == "freeSpace" else { return result(FlutterMethodNotImplemented) }
      let home = URL(fileURLWithPath: NSHomeDirectory())
      let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
      if let bytes = values?.volumeAvailableCapacityForImportantUsage {
        result(NSNumber(value: bytes))
      } else {
        result(nil)
      }
    }
    deviceChannel = device

    let video = FlutterMethodChannel(name: "tinta/video", binaryMessenger: messenger)
    video.setMethodCallHandler { [weak self] call, result in self?.handleVideo(call, result) }
    videoChannel = video

    // Pencil sound: one looping player; Dart sets the volume from stroke speed.
    let sound = FlutterMethodChannel(name: "tinta/sound", binaryMessenger: messenger)
    sound.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "start":
        if self.pencil == nil, let asset = args["asset"] as? String,
          let path = Bundle.main.path(forResource: registrar.lookupKey(forAsset: asset), ofType: nil)
        {
          // Ambient: mixes with music and follows the silent switch.
          try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
          self.pencil = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
          self.pencil?.numberOfLoops = -1
          self.pencil?.prepareToPlay()
        }
        self.pencil?.volume = 0
        self.pencil?.currentTime = Double.random(in: 0..<(self.pencil?.duration ?? 1))
        self.pencil?.play()
        result(nil)
      case "volume":
        self.pencil?.setVolume(Float(args["volume"] as? Double ?? 0), fadeDuration: 0.04)
        result(nil)
      case "stop":
        self.pencil?.pause()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    soundChannel = sound
  }

  /// MP4 encoder fed one raw RGBA frame at a time from Dart (replay export).
  private func handleVideo(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    videoQueue.async { [weak self] in
      guard let self else { return }
      do {
        switch call.method {
        case "start":
          self.encoder = try VideoEncoder(
            path: args["path"] as! String,
            width: args["width"] as! Int,
            height: args["height"] as! Int,
            fps: Int32(args["fps"] as! Int))
          DispatchQueue.main.async { result(nil) }
        case "frame":
          guard let encoder = self.encoder, let data = args["rgba"] as? FlutterStandardTypedData else {
            throw EncoderError.notStarted
          }
          try encoder.append(rgba: data.data)
          DispatchQueue.main.async { result(nil) }
        case "finish":
          guard let encoder = self.encoder else { throw EncoderError.notStarted }
          self.encoder = nil
          let error = encoder.finish()
          DispatchQueue.main.async {
            if let error {
              result(FlutterError(code: "encode", message: error.localizedDescription, details: nil))
            } else {
              result(nil)
            }
          }
        case "cancel":
          self.encoder?.cancel()
          self.encoder = nil
          DispatchQueue.main.async { result(nil) }
        default:
          DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
        }
      } catch {
        self.encoder?.cancel()
        self.encoder = nil
        DispatchQueue.main.async {
          result(FlutterError(code: "encode", message: "\(error)", details: nil))
        }
      }
    }
  }
}

enum EncoderError: Error {
  case notStarted
  case noPixelBuffer
  case writerFailed(String)
}

/// H.264 MP4 writer. Frames arrive as tightly packed RGBA rows.
final class VideoEncoder {
  private let writer: AVAssetWriter
  private let input: AVAssetWriterInput
  private let adaptor: AVAssetWriterInputPixelBufferAdaptor
  private let width: Int
  private let height: Int
  private let fps: Int32
  private var frame: Int64 = 0

  init(path: String, width: Int, height: Int, fps: Int32) throws {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.removeItem(at: url)
    self.width = width
    self.height = height
    self.fps = fps
    writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    input = AVAssetWriterInput(mediaType: .video, outputSettings: [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: width * height * 6],
    ])
    input.expectsMediaDataInRealTime = false
    adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
      kCVPixelBufferWidthKey as String: width,
      kCVPixelBufferHeightKey as String: height,
    ])
    writer.add(input)
    guard writer.startWriting() else {
      throw EncoderError.writerFailed(writer.error?.localizedDescription ?? "startWriting")
    }
    writer.startSession(atSourceTime: .zero)
  }

  func append(rgba: Data) throws {
    while !input.isReadyForMoreMediaData {
      if writer.status == .failed { throw EncoderError.writerFailed(writer.error?.localizedDescription ?? "failed") }
      Thread.sleep(forTimeInterval: 0.002)
    }
    guard let pool = adaptor.pixelBufferPool else { throw EncoderError.noPixelBuffer }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
    guard let pixels = buffer else { throw EncoderError.noPixelBuffer }

    CVPixelBufferLockBaseAddress(pixels, [])
    rgba.withUnsafeBytes { raw in
      var src = vImage_Buffer(
        data: UnsafeMutableRawPointer(mutating: raw.baseAddress!),
        height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 4)
      var dst = vImage_Buffer(
        data: CVPixelBufferGetBaseAddress(pixels),
        height: vImagePixelCount(height), width: vImagePixelCount(width),
        rowBytes: CVPixelBufferGetBytesPerRow(pixels))
      let rgbaToBgra: [UInt8] = [2, 1, 0, 3]
      vImagePermuteChannels_ARGB8888(&src, &dst, rgbaToBgra, vImage_Flags(kvImageNoFlags))
    }
    CVPixelBufferUnlockBaseAddress(pixels, [])

    if !adaptor.append(pixels, withPresentationTime: CMTime(value: frame, timescale: fps)) {
      throw EncoderError.writerFailed(writer.error?.localizedDescription ?? "append")
    }
    frame += 1
  }

  /// Blocks until the file is written; returns the error, if any.
  func finish() -> Error? {
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    return writer.status == .completed ? nil : (writer.error ?? EncoderError.writerFailed("finish"))
  }

  func cancel() {
    writer.cancelWriting()
  }
}
