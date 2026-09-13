package com.jarvis.app.jarvis

import android.content.Context
import android.content.Intent
import java.text.Normalizer

class AppLauncher(private val context: Context) {
    fun openByName(query: String): Boolean {
        val packageManager = context.packageManager
        val apps = packageManager.getInstalledApplications(0)
        val normalizedQuery = normalize(query)
        val match = apps
            .mapNotNull { app ->
                val label = packageManager.getApplicationLabel(app).toString()
                val normalizedLabel = normalize(label)
                val score = when {
                    normalizedLabel == normalizedQuery -> 0
                    normalizedLabel.startsWith(normalizedQuery) -> 1
                    normalizedLabel.contains(normalizedQuery) -> 2
                    else -> 99
                }
                if (score < 99) Triple(score, label, app.packageName) else null
            }
            .sortedBy { it.first }
            .firstOrNull()
            ?: return false
        val intent = packageManager.getLaunchIntentForPackage(match.third) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        return true
    }

    private fun normalize(value: String): String = Normalizer.normalize(value.lowercase().trim(), Normalizer.Form.NFD)
        .replace("\\p{InCombiningDiacriticalMarks}+".toRegex(), "")
}
