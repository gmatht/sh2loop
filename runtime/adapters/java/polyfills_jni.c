// adapters/java/polyfills_jni.c — the JNI shim for the Java adapter.
// Links libsh2poly.a and exposes sh2poly_init / sh2poly_dispatch /
// dup2 to the Polyfills Java class.
//
// Build (see Polyfills.java header):
//   javac -h . Polyfills.java
//   cc -shared -fPIC -I$JAVA_HOME/include -I$JAVA_HOME/include/linux \
//      -o libpolyfills_jni.so polyfills_jni.c ../../libsh2poly.a
#include <jni.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

void sh2poly_init(void);
int sh2poly_dispatch(int argc, char **argv);

JNIEXPORT void JNICALL Java_Polyfills_sh2polyInit(JNIEnv *env, jclass cls) {
    (void)env; (void)cls;
    sh2poly_init();
}

JNIEXPORT jint JNICALL Java_Polyfills_sh2polyDispatch(JNIEnv *env, jclass cls, jobjectArray argv) {
    (void)cls;
    jsize argc = (*env)->GetArrayLength(env, argv);
    char **cargv = malloc(((size_t)argc + 1) * sizeof(char *));
    if (!cargv) return 2;
    for (jsize i = 0; i < argc; i++) {
        jstring s = (jstring)(*env)->GetObjectArrayElement(env, argv, i);
        const char *cs = (*env)->GetStringUTFChars(env, s, NULL);
        cargv[i] = cs ? strdup(cs) : strdup("");
        if (cs) (*env)->ReleaseStringUTFChars(env, s, cs);
    }
    cargv[argc] = NULL;
    int st = sh2poly_dispatch((int)argc, cargv);
    for (jsize i = 0; i < argc; i++) free(cargv[i]);
    free(cargv);
    return (jint)st;
}

JNIEXPORT void JNICALL Java_Polyfills_redirectStdin(JNIEnv *env, jclass cls, jstring path) {
    (void)cls;
    const char *p = (*env)->GetStringUTFChars(env, path, NULL);
    if (p) {
        int fd = open(p, O_RDONLY);
        if (fd >= 0) { dup2(fd, 0); close(fd); }
        (*env)->ReleaseStringUTFChars(env, path, p);
    }
}
