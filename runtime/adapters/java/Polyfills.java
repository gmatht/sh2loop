// adapters/java/Polyfills.java — the Java backend's thin adapter for
// the C polyfills. Loads the JNI shim (polyfills_jni.c, which links
// libsh2poly.a) and maps the sh2.* call-site convention to
// sh2poly_dispatch.
//
// Build:
//   javac Polyfills.java
//   javac -h . Polyfills.java          (generates Polyfills.h)
//   cc -shared -fPIC -I$JAVA_HOME/include -I$JAVA_HOME/include/linux \
//      -o libpolyfills_jni.so polyfills_jni.c ../../libsh2poly.a
// Run:
//   java -Djava.library.path=. Polyfills   (reads adapters/battery.txt)
//
// The battery runner: reads battery.txt (TAB-separated fields, `\\` →
// backslash, `\n` → newline), sets up the deterministic stdin,
// dispatches every call, prints `== name` / `status=N`.
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;

public class Polyfills {
    static {
        System.loadLibrary("polyfills_jni");
    }

    private static native void sh2polyInit();
    private static native int sh2polyDispatch(String[] argv);
    private static native void redirectStdin(String path);

    static String unescape(String field) {
        StringBuilder b = new StringBuilder();
        for (int i = 0; i < field.length(); i++) {
            char c = field.charAt(i);
            if (c == '\\' && i + 1 < field.length()) {
                char n = field.charAt(i + 1);
                if (n == '\\') { b.append('\\'); i++; }
                else if (n == 'n') { b.append('\n'); i++; }
                else if (n == 't') { b.append('\t'); i++; }
                else b.append('\\');
            } else {
                b.append(c);
            }
        }
        return b.toString();
    }

    public static void main(String[] args) throws Exception {
        sh2polyInit();

        // deterministic stdin for the read/readarray calls
        Files.write(Paths.get("/tmp/sh2poly_selftest_in.txt"),
            "alpha beta gamma\none\ntwo\nthree\n".getBytes(StandardCharsets.UTF_8));
        redirectStdin("/tmp/sh2poly_selftest_in.txt");

        Path bat = Paths.get("adapters/battery.txt");
        if (!Files.exists(bat)) bat = Paths.get("battery.txt");
        for (String line : Files.readAllLines(bat, StandardCharsets.UTF_8)) {
            line = line.trim();
            if (line.isEmpty() || line.startsWith("#")) continue;
            String[] fields = line.split("\t", -1);
            String name = fields[0];
            String[] argv = new String[fields.length];
            argv[0] = name;
            for (int i = 1; i < fields.length; i++) argv[i] = unescape(fields[i]);
            System.out.println("== " + name);
            System.out.flush();
            int st = sh2polyDispatch(argv);
            System.out.println("status=" + st);
            System.out.flush();
        }
    }
}
