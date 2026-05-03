package com.run.campus_connect

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.NonNull
import com.github.sisong.HPatch
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val installerChannel = "com.run.campus.connect/installer"
    private val ACTION_INSTALL_COMPLETE = "com.run.campus_connect.INSTALL_COMPLETE"

    private val installReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == ACTION_INSTALL_COMPLETE) {
                val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
                if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
                    val confirmationIntent = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                    if (confirmationIntent != null) {
                        confirmationIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(confirmationIntent)
                    }
                }
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(installReceiver, IntentFilter(ACTION_INSTALL_COMPLETE), Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(installReceiver, IntentFilter(ACTION_INSTALL_COMPLETE))
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, installerChannel)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "getSourceApkPath" -> {
                        val splits = applicationInfo.splitSourceDirs
                        if (!splits.isNullOrEmpty()) {
                            result.error(
                                "SPLIT_APK",
                                "App is installed as split APKs. Delta patching requires a non-split installation.",
                                null
                            )
                        } else {
                            result.success(applicationInfo.sourceDir)
                        }
                    }
                    "getNativeLibraryDir" -> result.success(applicationInfo.nativeLibraryDir)
                    "applyPatch" -> {
                        val oldFile   = call.argument<String>("oldFile")
                        val patchFile = call.argument<String>("patchFile")
                        val outFile   = call.argument<String>("outFile")
                        if (oldFile.isNullOrBlank() || patchFile.isNullOrBlank() || outFile.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "oldFile, patchFile and outFile are required", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val code = HPatch.patch(oldFile, patchFile, outFile)
                                if (code == 0) {
                                    result.success(0)
                                } else {
                                    result.error("PATCH_FAILED", "hpatchz returned exit code $code", null)
                                }
                            } catch (e: Exception) {
                                result.error("PATCH_EXCEPTION", e.message ?: "unknown error", null)
                            }
                        }.start()
                    }
                    "installApkSession" -> {
                        val apkPath = call.argument<String>("apkPath")
                        if (apkPath.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "apkPath is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            installWithPackageInstaller(apkPath)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(installReceiver)
    }

    private fun installWithPackageInstaller(apkPath: String) {
        val apkFile = File(apkPath)
        if (!apkFile.exists()) {
            throw IllegalStateException("APK file not found at $apkPath")
        }

        val params = PackageInstaller.SessionParams(
            PackageInstaller.SessionParams.MODE_FULL_INSTALL
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            params.setInstallReason(PackageManager.INSTALL_REASON_USER)
        }

        val packageInstaller = packageManager.packageInstaller
        val sessionId = packageInstaller.createSession(params)
        val session = packageInstaller.openSession(sessionId)

        FileInputStream(apkFile).use { input ->
            session.openWrite("base.apk", 0, apkFile.length()).use { output ->
                input.copyTo(output)
                session.fsync(output)
            }
        }

        val intent = Intent(ACTION_INSTALL_COMPLETE).setPackage(packageName)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            sessionId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
        
        session.commit(pendingIntent.intentSender)
        session.close()
    }
}
