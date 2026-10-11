package com.haidilao.haidilao_cam

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import androidx.annotation.OptIn
import androidx.core.content.FileProvider
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import com.google.common.collect.ImmutableList
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

@OptIn(UnstableApi::class)
class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.haidilao.haidilao_cam/video_watermark"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "applyVideoWatermark" -> {
                    val inputPath = call.argument<String>("inputPath")
                    val outputPath = call.argument<String>("outputPath")
                    val watermarkPngPath = call.argument<String>("watermarkPngPath")
                    val targetAspectRatio = call.argument<Double>("targetAspectRatio")?.toFloat()

                    if (inputPath == null || outputPath == null) {
                        result.error("INVALID_ARGS", "inputPath and outputPath required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val inputFile = File(inputPath)
                        if (!inputFile.exists()) {
                            result.error("FILE_NOT_FOUND", "Input video not found: $inputPath", null)
                            return@setMethodCallHandler
                        }

                        val mediaItem = MediaItem.fromUri(Uri.fromFile(inputFile))
                        val effectsList = mutableListOf<Effect>()

                        // 1. Aspect Ratio Crop Effect (Center crop matching live camera viewfinder BoxFit.cover)
                        if (targetAspectRatio != null && targetAspectRatio > 0f) {
                            effectsList.add(Presentation.createForAspectRatio(targetAspectRatio, Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP))
                        }

                        // 2. Transparent Watermark Overlay (Fixed overlay matching the cropped frame 1:1)
                        if (watermarkPngPath != null) {
                            val wmFile = File(watermarkPngPath)
                            if (wmFile.exists()) {
                                val bitmap = BitmapFactory.decodeFile(watermarkPngPath)
                                if (bitmap != null) {
                                    val overlay = BitmapOverlay.createStaticBitmapOverlay(bitmap)
                                    effectsList.add(OverlayEffect(ImmutableList.of(overlay)))
                                }
                            }
                        }

                        val effects = Effects(listOf(), effectsList)
                        val editedMediaItem = EditedMediaItem.Builder(mediaItem)
                            .setEffects(effects)
                            .build()

                        val outputFile = File(outputPath)
                        outputFile.parentFile?.mkdirs()
                        if (outputFile.exists()) {
                            outputFile.delete()
                        }

                        android.util.Log.d("VideoWatermark", "Starting transform: input=$inputPath, output=$outputPath, effects=${effectsList.size}")

                        val transformer = Transformer.Builder(applicationContext)
                            .setVideoMimeType(MimeTypes.VIDEO_H264)
                            .addListener(object : Transformer.Listener {
                                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                                    android.util.Log.d("VideoWatermark", "Transform completed successfully: $outputPath")
                                    // Generate companion thumbnail
                                    try {
                                        val retriever = MediaMetadataRetriever()
                                        retriever.setDataSource(outputPath)
                                        val frame = retriever.getFrameAtTime(100000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                                        if (frame != null) {
                                            val thumbPath = outputPath.substringBeforeLast('.') + "_thumb.jpg"
                                            val fos = FileOutputStream(File(thumbPath))
                                            frame.compress(Bitmap.CompressFormat.JPEG, 85, fos)
                                            fos.flush()
                                            fos.close()
                                        }
                                        retriever.release()
                                    } catch (e: Exception) {
                                        android.util.Log.e("VideoWatermark", "Thumbnail generation error", e)
                                    }

                                    runOnUiThread {
                                        result.success(outputPath)
                                    }
                                }

                                override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                                    android.util.Log.e("VideoWatermark", "Transform failed", exportException)
                                    runOnUiThread {
                                        result.error("TRANSFORM_ERROR", exportException.message, null)
                                    }
                                }
                            })
                            .build()

                        transformer.start(editedMediaItem, outputPath)
                    } catch (e: Exception) {
                        android.util.Log.e("VideoWatermark", "Setup exception", e)
                        result.error("EXCEPTION", e.message, null)
                    }
                }
                "openVideo" -> {
                    val videoPath = call.argument<String>("videoPath")
                    if (videoPath != null) {
                        try {
                            val videoFile = File(videoPath)
                            val uri = FileProvider.getUriForFile(
                                this,
                                "${applicationContext.packageName}.fileprovider",
                                videoFile
                            )
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "video/*")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "videoPath required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
