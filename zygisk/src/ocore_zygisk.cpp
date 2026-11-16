/*
 * ==============================================================================
 * Ocore Unified Performance Engine v3.0 — Per-App Compatibility Profile Module
 * File: zygisk/src/ocore_zygisk.cpp
 * Purpose:
 *   Provides per-application Build metadata simulation for legitimate application
 *   compatibility and rendering/display testing.
 *
 * Security & Safety Policy (Section 11.F Compliance):
 *   1. Strictly scoped to user-bound packages in active_injections of OCORE.json.
 *   2. Never modifies system_server, GMS, Play Store, or root manager packages.
 *   3. Does NOT implement anti-cheat evasion, Play Integrity spoofing, keybox
 *      attestation forgery, or root hiding.
 *   4. Isolates /proc/cpuinfo simulation within the target app's private mount
 *      namespace (CLONE_NEWNS) and only when architecture/core count matches.
 * ==============================================================================
 */

#include "zygisk.hpp"
#include <android/log.h>
#include <fcntl.h>
#include <sched.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <unistd.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <mutex>
#include <sstream>
#include <string>
#include <unordered_map>
#include <unordered_set>

#define LOG_TAG "Ocore_Zygisk"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static constexpr const char *kConfigPath = "/data/adb/modules/Ocore/cortex/OCORE.json";
static constexpr const char *kCpuSpoofPath = "/data/adb/modules/Ocore/cortex/OCORE_spoof";

struct DeviceProfile {
    std::string mode;
    bool with_cpu = false;
    std::string brand;
    std::string manufacturer;
    std::string model;
    std::string device;
    std::string product;
    std::string fingerprint;
    std::string hardware;
    std::string soc_model;
    std::string android_version;
    int sdk_int = 0;
};

namespace {

std::mutex g_config_mutex;
time_t g_last_mtime = 0;
std::unordered_map<std::string, DeviceProfile> g_active_bindings;
std::unordered_set<std::string> g_blacklist = {
    "android",
    "system",
    "com.android.systemui",
    "com.android.settings",
    "com.android.phone",
    "com.google.android.gms",
    "com.google.android.gsf",
    "com.android.vending",
    "me.weishu.kernelsu",
    "com.rifsxd.ksunext",
    "me.bmax.apatch",
    "com.topjohnwu.magisk"
};

bool isValidPackageName(const std::string &pkg) {
    if (pkg.empty() || pkg.size() > 128) return false;
    if (pkg.find('.') == std::string::npos) return false;
    for (char c : pkg) {
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
              (c >= '0' && c <= '9') || c == '_' || c == '.')) {
            return false;
        }
    }
    if (g_blacklist.count(pkg) > 0) return false;
    if (pkg.rfind("com.google.android.gms", 0) == 0) return false;
    return true;
}

std::string extractJsonStringField(const std::string &block, const std::string &key) {
    std::string pat = "\"" + key + "\"";
    size_t pos = block.find(pat);
    if (pos == std::string::npos) return "";
    size_t colon = block.find(':', pos + pat.size());
    if (colon == std::string::npos) return "";
    size_t q1 = block.find('"', colon + 1);
    if (q1 == std::string::npos) return "";
    std::string out;
    for (size_t i = q1 + 1; i < block.size(); ++i) {
        if (block[i] == '\\' && i + 1 < block.size()) {
            char next = block[++i];
            if (next == '/' || next == '"' || next == '\\') out.push_back(next);
            else out.push_back(next);
        } else if (block[i] == '"') {
            return out;
        } else {
            out.push_back(block[i]);
        }
    }
    return "";
}

int extractJsonIntField(const std::string &block, const std::string &key, int fallback) {
    std::string pat = "\"" + key + "\"";
    size_t pos = block.find(pat);
    if (pos == std::string::npos) return fallback;
    size_t colon = block.find(':', pos + pat.size());
    if (colon == std::string::npos) return fallback;
    size_t i = colon + 1;
    while (i < block.size() && (block[i] == ' ' || block[i] == '\t' || block[i] == '"')) ++i;
    int val = 0;
    bool has_digits = false;
    while (i < block.size() && block[i] >= '0' && block[i] <= '9') {
        val = val * 10 + (block[i] - '0');
        has_digits = true;
        ++i;
    }
    return has_digits ? val : fallback;
}

bool extractJsonBoolField(const std::string &block, const std::string &key, bool fallback) {
    std::string pat = "\"" + key + "\"";
    size_t pos = block.find(pat);
    if (pos == std::string::npos) return fallback;
    size_t colon = block.find(':', pos + pat.size());
    if (colon == std::string::npos) return fallback;
    size_t sub = block.find_first_not_of(" \t\r\n", colon + 1);
    if (sub == std::string::npos) return fallback;
    if (block.compare(sub, 4, "true") == 0) return true;
    if (block.compare(sub, 5, "false") == 0) return false;
    return fallback;
}

void reloadConfigIfNeeded() {
    std::lock_guard<std::mutex> lock(g_config_mutex);
    struct stat st {};
    if (stat(kConfigPath, &st) != 0) {
        return;
    }
    if (st.st_mtime == g_last_mtime && !g_active_bindings.empty()) {
        return;
    }
    std::ifstream ifs(kConfigPath);
    if (!ifs.is_open()) {
        LOGW("Unable to open %s", kConfigPath);
        return;
    }
    std::stringstream ss;
    ss << ifs.rdbuf();
    std::string content = ss.str();
    if (content.empty()) return;

    g_active_bindings.clear();
    size_t act_pos = content.find("\"active_injections\"");
    if (act_pos == std::string::npos) {
        g_last_mtime = st.st_mtime;
        return;
    }
    size_t brace_start = content.find('{', act_pos);
    if (brace_start == std::string::npos) return;

    size_t cursor = brace_start + 1;
    while (cursor < content.size()) {
        size_t pkg_q1 = content.find('"', cursor);
        if (pkg_q1 == std::string::npos) break;
        size_t pkg_q2 = content.find('"', pkg_q1 + 1);
        if (pkg_q2 == std::string::npos) break;
        std::string pkg = content.substr(pkg_q1 + 1, pkg_q2 - pkg_q1 - 1);

        size_t obj_start = content.find('{', pkg_q2);
        if (obj_start == std::string::npos) break;
        int depth = 1;
        size_t pos = obj_start + 1;
        while (pos < content.size() && depth > 0) {
            if (content[pos] == '{') ++depth;
            else if (content[pos] == '}') --depth;
            ++pos;
        }
        if (depth != 0) break;
        std::string entry_block = content.substr(obj_start, pos - obj_start);
        cursor = pos;

        if (!isValidPackageName(pkg)) continue;

        DeviceProfile prof;
        prof.mode = extractJsonStringField(entry_block, "mode");
        prof.with_cpu = extractJsonBoolField(entry_block, "with_cpu", false);
        prof.brand = extractJsonStringField(entry_block, "BRAND");
        prof.manufacturer = extractJsonStringField(entry_block, "MANUFACTURER");
        prof.model = extractJsonStringField(entry_block, "MODEL");
        prof.device = extractJsonStringField(entry_block, "DEVICE");
        prof.product = extractJsonStringField(entry_block, "PRODUCT");
        prof.fingerprint = extractJsonStringField(entry_block, "FINGERPRINT");
        prof.hardware = extractJsonStringField(entry_block, "HARDWARE");
        prof.soc_model = extractJsonStringField(entry_block, "SOC_MODEL");
        prof.android_version = extractJsonStringField(entry_block, "ANDROID_VERSION");
        prof.sdk_int = extractJsonIntField(entry_block, "SDK_INT", 0);

        if (!prof.brand.empty() && !prof.model.empty()) {
            g_active_bindings[pkg] = prof;
        }
    }
    g_last_mtime = st.st_mtime;
}

void setStaticStringField(JNIEnv *env, jclass cls, const char *field_name, const std::string &val) {
    if (val.empty()) return;
    jfieldID fid = env->GetStaticFieldID(cls, field_name, "Ljava/lang/String;");
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
        return;
    }
    if (!fid) return;
    jstring jval = env->NewStringUTF(val.c_str());
    if (!jval) return;
    env->SetStaticObjectField(cls, fid, jval);
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
    }
    env->DeleteLocalRef(jval);
}

void setStaticIntField(JNIEnv *env, jclass cls, const char *field_name, int val) {
    if (val <= 0) return;
    jfieldID fid = env->GetStaticFieldID(cls, field_name, "I");
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
        return;
    }
    if (!fid) return;
    env->SetStaticIntField(cls, fid, static_cast<jint>(val));
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
    }
}

bool isCpuTemplateCompatible() {
    struct stat st {};
    if (stat(kCpuSpoofPath, &st) != 0 || st.st_size <= 0) return false;
    std::ifstream ifs(kCpuSpoofPath);
    std::string line;
    int template_cores = 0;
    while (std::getline(ifs, line)) {
        if (line.rfind("processor", 0) == 0) ++template_cores;
    }
    long host_cores = sysconf(_SC_NPROCESSORS_CONF);
    return (template_cores > 0 && host_cores > 0 && template_cores == host_cores);
}

} // namespace

class OcoreZygiskModule : public zygisk::ModuleBase {
public:
    void onLoad(zygisk::Api *api, JNIEnv *env) override {
        this->api_ = api;
        this->env_ = env;
    }

    void preAppSpecialize(zygisk::AppSpecializeArgs *args) override {
        if (!args || !args->nice_name) {
            api_->setOption(zygisk::Option::DLCLOSE_MODULE_LIBRARY);
            return;
        }
        const char *raw_pkg = env_->GetStringUTFChars(args->nice_name, nullptr);
        if (!raw_pkg) {
            api_->setOption(zygisk::Option::DLCLOSE_MODULE_LIBRARY);
            return;
        }
        std::string pkg(raw_pkg);
        env_->ReleaseStringUTFChars(args->nice_name, raw_pkg);

        // Strip process suffix (e.g. com.example.game:unity -> com.example.game)
        size_t colon = pkg.find(':');
        std::string base_pkg = (colon != std::string::npos) ? pkg.substr(0, colon) : pkg;

        if (!isValidPackageName(base_pkg)) {
            api_->setOption(zygisk::Option::DLCLOSE_MODULE_LIBRARY);
            return;
        }

        reloadConfigIfNeeded();

        DeviceProfile matched;
        bool found = false;
        {
            std::lock_guard<std::mutex> lock(g_config_mutex);
            auto it = g_active_bindings.find(base_pkg);
            if (it != g_active_bindings.end()) {
                matched = it->second;
                found = true;
            }
        }

        if (!found) {
            api_->setOption(zygisk::Option::DLCLOSE_MODULE_LIBRARY);
            return;
        }

        applyBuildProfile(matched);

        // Isolated per-process /proc/cpuinfo simulation only if explicitly enabled & compatible
        if (matched.with_cpu && isCpuTemplateCompatible()) {
            if (unshare(CLONE_NEWNS) == 0) {
                mount(nullptr, "/", nullptr, MS_REC | MS_PRIVATE, nullptr);
                mount(kCpuSpoofPath, "/proc/cpuinfo", nullptr, MS_BIND, nullptr);
            }
        }

        LOGI("Applied profile '%s' (%s %s) to package '%s'",
             matched.mode.c_str(), matched.brand.c_str(), matched.model.c_str(), base_pkg.c_str());
        api_->setOption(zygisk::Option::DLCLOSE_MODULE_LIBRARY);
    }

private:
    void applyBuildProfile(const DeviceProfile &p) {
        jclass build_cls = env_->FindClass("android/os/Build");
        if (env_->ExceptionCheck() || !build_cls) {
            env_->ExceptionClear();
            return;
        }
        setStaticStringField(env_, build_cls, "BRAND", p.brand);
        setStaticStringField(env_, build_cls, "MANUFACTURER", p.manufacturer);
        setStaticStringField(env_, build_cls, "MODEL", p.model);
        setStaticStringField(env_, build_cls, "DEVICE", p.device);
        setStaticStringField(env_, build_cls, "PRODUCT", p.product);
        setStaticStringField(env_, build_cls, "FINGERPRINT", p.fingerprint);
        setStaticStringField(env_, build_cls, "HARDWARE", p.hardware);
        setStaticStringField(env_, build_cls, "SOC_MODEL", p.soc_model);
        env_->DeleteLocalRef(build_cls);

        jclass ver_cls = env_->FindClass("android/os/Build$VERSION");
        if (env_->ExceptionCheck() || !ver_cls) {
            env_->ExceptionClear();
            return;
        }
        setStaticStringField(env_, ver_cls, "RELEASE", p.android_version);
        setStaticIntField(env_, ver_cls, "SDK_INT", p.sdk_int);
        env_->DeleteLocalRef(ver_cls);
    }

    zygisk::Api *api_ = nullptr;
    JNIEnv *env_ = nullptr;
};

REGISTER_ZYGISK_MODULE(OcoreZygiskModule)
