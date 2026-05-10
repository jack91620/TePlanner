package cloud.teplanner.android.push

import cn.jpush.android.service.JCommonService

/**
 * Phase F.4 — required JPush keep-alive service.
 *
 * JPush 5.x abandoned the singleton service model — each integrator
 * must declare a `JCommonService` subclass in their own manifest so
 * the OEM "saved-from-killer" allowlists can target the app's own
 * package. We don't override anything; the parent does the work.
 */
class AppCommonService : JCommonService()
