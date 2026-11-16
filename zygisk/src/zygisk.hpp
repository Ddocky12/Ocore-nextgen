#pragma once
// Minimal Zygisk API v4 header definition for Ocore Next-Gen Zygisk Module
#include <jni.h>

namespace zygisk {

struct Api;
struct AppSpecializeArgs;
struct ServerSpecializeArgs;

class ModuleBase {
public:
    virtual void onLoad(Api * /*api*/, JNIEnv * /*env*/) {}
    virtual void preAppSpecialize(AppSpecializeArgs * /*args*/) {}
    virtual void postAppSpecialize(const AppSpecializeArgs * /*args*/) {}
    virtual void preServerSpecialize(ServerSpecializeArgs * /*args*/) {}
    virtual void postServerSpecialize(const ServerSpecializeArgs * /*args*/) {}
    virtual ~ModuleBase() = default;
};

struct AppSpecializeArgs {
    jint &uid;
    jint &gid;
    jintArray &gids;
    jint &runtime_flags;
    jobjectArray &rlimits;
    jint &mount_external;
    jstring &se_info;
    jstring &nice_name;
    jstring &instruction_set;
    jstring &app_data_dir;
    jintArray *fds_to_ignore;
    jboolean *is_child_zygote;
    jboolean *is_top_app;
    jobjectArray *pkg_data_info_list;
    jobjectArray *whitelisted_data_info_list;
    jboolean *mount_data_dirs;
    jboolean *mount_storage_dirs;
    AppSpecializeArgs() = delete;
};

struct ServerSpecializeArgs {
    jint &uid;
    jint &gid;
    jintArray &gids;
    jint &runtime_flags;
    jlong &permitted_capabilities;
    jlong &effective_capabilities;
    ServerSpecializeArgs() = delete;
};

enum Option : int {
    FORCE_DENYLIST_UNMOUNT = 0,
    DLCLOSE_MODULE_LIBRARY = 1,
};

struct Api {
    long connectCompanion();
    int getModuleDir();
    void setOption(Option opt);
};

namespace internal {
struct api_table;
template <class T> void entry_impl(api_table *, JNIEnv *);
} // namespace internal

} // namespace zygisk

#define REGISTER_ZYGISK_MODULE(clazz) \
extern "C" [[gnu::visibility("default")]] void zygisk_module_entry( \
    zygisk::internal::api_table *table, JNIEnv *env) { \
    (void)table; (void)env; \
    static clazz module_instance; \
    (void)module_instance; \
}
