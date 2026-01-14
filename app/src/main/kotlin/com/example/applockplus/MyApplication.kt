package com.example.applockplus

import android.app.Application
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class MyApplication : Application() {

    companion object {
        const val MAIN_ENGINE_ID = "main_engine"
    }

    override fun onCreate() {
        super.onCreate()

        Log.d("MyApplication", "Initializing MAIN Flutter Engine")

        // PRE-WARM MAIN ENGINE
        val mainEngine = FlutterEngine(this).apply {
            val dartEntrypoint = DartExecutor.DartEntrypoint.createDefault()
            dartExecutor.executeDartEntrypoint(dartEntrypoint)
        }

        FlutterEngineCache.getInstance().put(MAIN_ENGINE_ID, mainEngine)

        Log.d("MyApplication", "Main Flutter Engine cached successfully")
    }
}