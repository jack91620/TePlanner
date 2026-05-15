package cloud.teplanner.android.util

import android.content.Context
import android.content.Intent
import android.net.Uri

/**
 * Public URLs for the Tautomation legal documents. Used by the login
 * page consent line and the Settings → 关于 → 隐私政策 / 用户协议
 * row.
 *
 * Both URLs are placeholders until the markdown drafts under
 * `docs/legal/` are published to a public HTML host. They MUST be
 * live + reachable when the Play Store binary is submitted; reviewers
 * verify them against the listing metadata.
 *
 * Keep in lockstep with iOS [LegalLinks].
 */
object LegalLinks {
    const val PRIVACY_POLICY_URL = "https://teplanner.cloud/legal/privacy.html"
    const val TERMS_OF_SERVICE_URL = "https://teplanner.cloud/legal/terms.html"

    /** Open a URL in the system browser (Chrome / Huawei browser / etc.). */
    fun open(context: Context, url: String) {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (_: Throwable) {
            // No browser installed — extremely rare on Android. Silent
            // failure is acceptable; the user can also reach the URL
            // from any other device.
        }
    }
}
