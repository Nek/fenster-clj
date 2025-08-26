package demo;

import java.io.File;
import java.nio.ByteBuffer;
import java.nio.file.Paths;

public final class FenShim {

    static {
        String p = Paths.get("native", "libfen_shim_jni.dylib")
            .toAbsolutePath()
            .toString();
        System.err.println("[FenShim] System.load -> " + p);
        System.load(p);
    }

    private FenShim() {}

    public static native long fenOpen(
        int width,
        int height,
        String title,
        ByteBuffer pixelBuf
    );

    public static native int fenLoop(long handle);

    public static native void fenClose(long handle);

    public static native int fenKey(long handle, int code);

    public static native void fenSleep(int ms);

    public static native long fenTime();
}
