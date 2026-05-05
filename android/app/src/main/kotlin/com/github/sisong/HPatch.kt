package com.github.sisong

/**
 * JNI bridge to the HDiffPatch `libhpatchz.so` shared library.
 *
 * The library exports `Java_com_github_sisong_HPatch_patch`, which maps
 * exactly to the [patch] method declared here. Android's JNI linker resolves
 * the call automatically when the library is loaded.
 *
 * Returns 0 on success, non-zero on failure.
 */
object HPatch {
    init {
        System.loadLibrary("hpatchz")
    }

    /**
     * Apply a binary delta patch.
     *
     * @param oldFileName   Absolute path to the source (old) file.
     * @param patchFileName Absolute path to the downloaded `.patch` file.
     * @param outNewFileName Absolute path where the reconstructed new file will be written.
     * @return 0 on success, non-zero on failure.
     */
    external fun patch(
        oldFileName: String,
        patchFileName: String,
        outNewFileName: String,
    ): Int
}
