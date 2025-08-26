package demo;

import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.FloatBuffer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;

public final class FenShim {

    static {
        // Try normal lookup first…
        try {
            System.loadLibrary("fen_shim_jni");
        } catch (UnsatisfiedLinkError primary) {
            // …fallback to loading our bundled resource
            try {
                String res = "native/libfen_shim_jni.dylib";
                try (
                    InputStream in =
                        FenShim.class.getClassLoader().getResourceAsStream(res)
                ) {
                    if (in == null) throw new IOException(
                        "resource not found: " + res
                    );
                    Path tmp = Files.createTempFile("fen_", ".dylib");
                    Files.copy(in, tmp, StandardCopyOption.REPLACE_EXISTING);
                    System.load(tmp.toAbsolutePath().toString());
                    tmp.toFile().deleteOnExit();
                }
            } catch (Exception e) {
                throw primary;
            }
        }
    }

    // ---- window ----
    public static native long fenOpen(
        int w,
        int h,
        String title,
        ByteBuffer pixelBuf
    );

    public static native int fenLoop(long handle);

    public static native void fenClose(long handle);

    public static native int fenKey(long handle, int code);

    public static native void fenSleep(int ms); // <-- CHANGED to int

    public static native long fenTime();

    // ---- audio ----
    public static native long fenAudioOpen(); // returns audio handle

    public static native int fenAudioAvail(long audioHandle); // frames available (non-blocking)

    public static native void fenAudioWrite(
        long audioHandle,
        FloatBuffer buf,
        int nFrames
    );

    public static native void fenAudioClose(long audioHandle);

    private FenShim() {}
}
