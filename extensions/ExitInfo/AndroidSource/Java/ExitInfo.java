/// GameMaker Android 原生扩展：读取"上一次进程退出原因"
///
/// 用途：区分**前台闪退**与**用户上滑清理 / 系统强杀**。
///   纯 GML 做不到这件事：MIUI 的 SwipeUpClean 是系统侧直接把进程干掉，
///   App 拿不到 onPause、也跑不到下一帧 Step（实测 logcat 里音频是被杀那一刻才停的）。
///   唯一权威来源就是 Android 自己的 ApplicationExitInfo（API 30+，本机 SDK 35）。
///
/// 返回 ApplicationExitInfo.REASON_* 的数值（double）：
///   2  SIGNALED                      ⇒ 被信号杀（含原生崩溃）—— 算闪退
///   4  ANR                           ⇒ 无响应 —— 算闪退
///   5  (REASON_CRASH_NATIVE)         ⇒ 原生崩溃 —— 算闪退
///   6  (REASON_CRASH)                ⇒ Java 崩溃 —— 算闪退
///   1  EXIT_SELF                     ⇒ 自己 exit()（game_end() 也是 1）—— 交给面包屑标记再判
///   10 USER_REQUESTED (SwipeUpClean/强杀) / 11 / 16 PACKAGE_UPDATED / 3 LOW_MEMORY ⇒ 正常离开
///   -1 拿不到（老系统、无记录、异常）—— 交给面包屑标记再判
package ${YYAndroidPackageName};

import android.app.Activity;
import android.app.ActivityManager;
import android.os.Build;
import android.os.Process;
import android.util.Log;

import ${YYAndroidPackageName}.RunnerActivity;

import java.util.List;

public class ExitInfo extends ExtensionBase {

    private static final String TAG = "ExitInfo";

    public void Init() {
        // 无需初始化：每次调用现查即可
    }

    /// 上一次进程退出的 reason 码；拿不到返回 -1
    public double getLastExitReason() {
        try {
            if (Build.VERSION.SDK_INT < 30) return -1.0;
            Activity act = RunnerActivity.CurrentActivity;
            if (act == null) return -1.0;
            ActivityManager am = (ActivityManager) act.getSystemService(Activity.ACTIVITY_SERVICE);
            if (am == null) return -1.0;
            // maxNum=8：取最近若干条，跳过本进程自己（理论上不会出现）
            List<android.app.ApplicationExitInfo> list = am.getHistoricalProcessExitReasons(null, 0, 8);
            if (list == null) return -1.0;
            int myPid = Process.myPid();
            for (int i = 0; i < list.size(); i++) {
                android.app.ApplicationExitInfo it = list.get(i);
                if (it == null) continue;
                if (it.getPid() == myPid) continue;
                return (double) it.getReason();
            }
            return -1.0;
        } catch (Throwable t) {
            Log.w(TAG, "getLastExitReason failed: " + t);
            return -1.0;
        }
    }

    /// 上一次退出的 description（Android 自己写的说明，
    /// 例如 "stop com.t10.game due to SwipeUpClean"）；拿不到返回 ""
    public String getLastExitDescription() {
        try {
            if (Build.VERSION.SDK_INT < 30) return "";
            Activity act = RunnerActivity.CurrentActivity;
            if (act == null) return "";
            ActivityManager am = (ActivityManager) act.getSystemService(Activity.ACTIVITY_SERVICE);
            if (am == null) return "";
            List<android.app.ApplicationExitInfo> list = am.getHistoricalProcessExitReasons(null, 0, 8);
            if (list == null) return "";
            int myPid = Process.myPid();
            for (int i = 0; i < list.size(); i++) {
                android.app.ApplicationExitInfo it = list.get(i);
                if (it == null) continue;
                if (it.getPid() == myPid) continue;
                String d = it.getDescription();
                return (d == null) ? "" : d;
            }
            return "";
        } catch (Throwable t) {
            Log.w(TAG, "getLastExitDescription failed: " + t);
            return "";
        }
    }
}
