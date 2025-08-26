package demo;

import static java.nio.file.StandardCopyOption.REPLACE_EXISTING;

import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.file.Files;
import java.nio.file.Path;

public final class FenShim {

    static {
        // 1) Try normal library path (works on JVM + when lib is beside the binary)
        try {
            System.loadLibrary("fen_shim_jni");
        } catch (UnsatisfiedLinkError e1) {
            // 2) Fallback: extract the bundled resource from the image/JAR
            String res = "native/libfen_shim_jni.dylib";
            try (
                InputStream in =
                    FenShim.class.getClassLoader().getResourceAsStream(res)
            ) {
                if (in == null) throw new UnsatisfiedLinkError(
                    "Missing resource: " + res
                );
                Path tmp = Files.createTempFile("fen_shim_jni", ".dylib");
                Files.copy(in, tmp, REPLACE_EXISTING);
                tmp.toFile().deleteOnExit();
                System.load(tmp.toAbsolutePath().toString());
            } catch (Exception e2) {
                UnsatisfiedLinkError ule = new UnsatisfiedLinkError(
                    "Failed to load fen_shim_jni"
                );
                ule.addSuppressed(e1);
                ule.addSuppressed(e2);
                throw ule;
            }
        }
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
