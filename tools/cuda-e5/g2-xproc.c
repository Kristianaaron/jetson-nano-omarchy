// G2 check for the garbage-block corruption (docs/cuda-feasibility.md section 18).
// Renders a per-16x16-tile pattern into an EGL window surface on a GBM surface with NVIDIA
// block-linear modifiers (as a Wayland client does), locks the front buffer, imports it as a
// dma-buf EGLImage (as a compositor does), samples it into a texture and compares every pixel.
//   CLIENT=1            render, print "CLIENT pid P fd F mod M stride S", wait 60 s (exporter)
//   FROM_PID/FROM_FD/FROM_MOD/FROM_STRIDE
//                       import the exporter's buffer through pidfd_getfd (cross-process)
//   XR30=1              XRGB2101010 instead of XRGB8888; NATIVE=1: use the GBM bo, no import
// Build: gcc -O2 -DW=1280 -DH=720 g2-xproc.c $(pkg-config --cflags --libs egl glesv2 gbm libdrm)
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <gbm.h>
#include <linux/dma-buf.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <GLES2/gl2ext.h>
#include <drm_fourcc.h>
#ifndef W
#define W 1280
#endif
#ifndef H
#define H 768
#endif
int main(void) {
  int fd = open("/dev/dri/renderD128", O_RDWR | O_CLOEXEC);
  struct gbm_device *gbm = gbm_create_device(fd);
  EGLDisplay d = eglGetPlatformDisplay(EGL_PLATFORM_GBM_KHR, gbm, NULL);
  eglInitialize(d, NULL, NULL); eglBindAPI(EGL_OPENGL_ES_API);
  uint32_t fourcc = getenv("XR30") ? GBM_FORMAT_XRGB2101010 : GBM_FORMAT_XRGB8888;
  EGLint cfg_attr[] = {EGL_SURFACE_TYPE, EGL_WINDOW_BIT, EGL_RED_SIZE, 1, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT, EGL_NONE};
  EGLConfig cfgs[64]; EGLint n = 0; eglChooseConfig(d, cfg_attr, cfgs, 64, &n);
  EGLConfig cfg = NULL;
  for (int i = 0; i < n; i++) { EGLint id; eglGetConfigAttrib(d, cfgs[i], EGL_NATIVE_VISUAL_ID, &id); if ((uint32_t)id == fourcc) { cfg = cfgs[i]; break; } }
  if (!cfg) { printf("no config for format\n"); return 1; }
  uint64_t mods[] = {0x03000000000fe014ULL, 0x03000000000fe010ULL};
  struct gbm_surface *gs = gbm_surface_create_with_modifiers2(gbm, W, H, fourcc, mods, 2, GBM_BO_USE_RENDERING);
  EGLSurface s = eglCreatePlatformWindowSurface(d, cfg, gs, NULL);
  EGLint ca[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
  EGLContext c = eglCreateContext(d, cfg, EGL_NO_CONTEXT, ca);
  eglMakeCurrent(d, s, s, c);
  printf("renderer %s, format %s\n", glGetString(GL_RENDERER), fourcc == GBM_FORMAT_XRGB8888 ? "XR24" : "XR30");
  // a pattern that differs per 16x16 tile: colour = (tx*13 & 255, ty*29 & 255, (tx^ty)*7 & 255)
  glEnable(GL_SCISSOR_TEST);
  for (int ty = 0; ty < H / 16; ty++) for (int tx = 0; tx < W / 16; tx++) {
    glScissor(tx * 16, ty * 16, 16, 16);
    glClearColor(((tx * 13) & 255) / 255.0f, ((ty * 29) & 255) / 255.0f, (((tx ^ ty) * 7) & 255) / 255.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
  }
  glDisable(GL_SCISSOR_TEST);
  unsigned char px[4];
  eglSwapBuffers(d, s);
  struct gbm_bo *bo = gbm_surface_lock_front_buffer(gs);
  int bfd = gbm_bo_get_fd(bo);
  if (getenv("CLIENT")) {
    printf("CLIENT pid %d fd %d mod 0x%llx stride %u off %u\n", getpid(), bfd, (unsigned long long)gbm_bo_get_modifier(bo), gbm_bo_get_stride(bo), gbm_bo_get_offset(bo, 0));
    fflush(stdout); sleep(60); return 0;
  }
  uint64_t xmod = 0; unsigned xstride = 0, xoff = 0;
  if (getenv("FROM_PID")) {
    int pidfd = syscall(SYS_pidfd_open, atoi(getenv("FROM_PID")), 0);
    bfd = syscall(SYS_pidfd_getfd, pidfd, atoi(getenv("FROM_FD")), 0);
    xmod = strtoull(getenv("FROM_MOD"), NULL, 0); xstride = atoi(getenv("FROM_STRIDE"));
    printf("importer: took fd %d from pid %s\n", bfd, getenv("FROM_PID"));
  }
  printf("front bo modifier 0x%016llx stride %u fd %d\n", (unsigned long long)gbm_bo_get_modifier(bo), gbm_bo_get_stride(bo), bfd);
  off_t size = lseek(bfd, 0, SEEK_END);
  unsigned char *p = mmap(NULL, size, PROT_READ, MAP_SHARED, bfd, 0);
  if (p == MAP_FAILED) { printf("mmap failed\n"); return 1; }
  struct dma_buf_sync sy = {DMA_BUF_SYNC_START | DMA_BUF_SYNC_READ}; ioctl(bfd, DMA_BUF_IOCTL_SYNC, &sy);
  long nz = 0; for (off_t k = 0; k < size; k++) nz += p[k] != 0;
  printf("shared buffer: %ld bytes, %ld non-zero (%.1f%%), first word 0x%08x\n", (long)size, nz, 100.0 * nz / size, *(unsigned *)p);

  // compositor side: import the front buffer and sample it into a separate texture
  PFNEGLCREATEIMAGEKHRPROC createImage = (void *)eglGetProcAddress("eglCreateImageKHR");
  PFNGLEGLIMAGETARGETTEXTURE2DOESPROC imageTarget = (void *)eglGetProcAddress("glEGLImageTargetTexture2DOES");
  uint64_t mod = getenv("FROM_PID") ? xmod : gbm_bo_get_modifier(bo);
  EGLint attr[] = {EGL_WIDTH, W, EGL_HEIGHT, H, EGL_LINUX_DRM_FOURCC_EXT, (EGLint)fourcc,
                   EGL_DMA_BUF_PLANE0_FD_EXT, bfd, EGL_DMA_BUF_PLANE0_OFFSET_EXT, getenv("FROM_PID") ? (EGLint)xoff : (EGLint)gbm_bo_get_offset(bo, 0),
                   EGL_DMA_BUF_PLANE0_PITCH_EXT, getenv("FROM_PID") ? (EGLint)xstride : (EGLint)gbm_bo_get_stride(bo),
                   EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT, (EGLint)(mod & 0xffffffff), EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT, (EGLint)(mod >> 32), EGL_NONE};
  EGLImageKHR img = getenv("NATIVE") ? createImage(d, EGL_NO_CONTEXT, EGL_NATIVE_PIXMAP_KHR, (EGLClientBuffer)bo, NULL)
                                     : createImage(d, EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT, NULL, attr);
  printf("image source: %s\n", getenv("NATIVE") ? "the GBM bo itself (no import)" : "dma-buf import");
  printf("import %s\n", img ? "ok" : "FAILED");
  GLuint itex; glGenTextures(1, &itex); glBindTexture(GL_TEXTURE_2D, itex);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  imageTarget(GL_TEXTURE_2D, img);
  GLuint dst; glGenTextures(1, &dst); glBindTexture(GL_TEXTURE_2D, dst);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, W, H, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
  GLuint fb; glGenFramebuffers(1, &fb); glBindFramebuffer(GL_FRAMEBUFFER, fb);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, dst, 0);
  const char *vs = "attribute vec2 q; varying vec2 uv; void main(){ uv = q * 0.5 + 0.5; gl_Position = vec4(q, 0.0, 1.0); }";
  const char *fs = "precision mediump float; varying vec2 uv; uniform sampler2D t; void main(){ gl_FragColor = texture2D(t, uv); }";
  GLuint prog = glCreateProgram(), sh;
  sh = glCreateShader(GL_VERTEX_SHADER); glShaderSource(sh, 1, &vs, NULL); glCompileShader(sh); glAttachShader(prog, sh);
  sh = glCreateShader(GL_FRAGMENT_SHADER); glShaderSource(sh, 1, &fs, NULL); glCompileShader(sh); glAttachShader(prog, sh);
  glBindAttribLocation(prog, 0, "q"); glLinkProgram(prog); glUseProgram(prog);
  static const float tri[] = {-1, -1, 3, -1, -1, 3};
  glBindBuffer(GL_ARRAY_BUFFER, 0); glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, tri); glEnableVertexAttribArray(0);
  glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D, itex);
  glViewport(0, 0, W, H); glClearColor(0, 0, 1, 1); glClear(GL_COLOR_BUFFER_BIT);
  glDrawArrays(GL_TRIANGLES, 0, 3);
  static unsigned char out[W * H * 4];
  glReadPixels(0, 0, W, H, GL_RGBA, GL_UNSIGNED_BYTE, out);
  long bad = 0; static long badcol[W / 16];
  for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
    int tx = x / 16, ty = (H - 1 - y) / 16; unsigned char *o = out + (y * W + x) * 4;
    int er = (tx * 13) & 255, eg = (ty * 29) & 255, eb = ((tx ^ ty) * 7) & 255;
    if (abs(o[0] - er) > 2 || abs(o[1] - eg) > 2 || abs(o[2] - eb) > 2) { bad++; badcol[tx]++; }
  }
  for (int k = 0; k < 4; k++) { int x = (k * 337 + 5) % W, y = (k * 211 + 7) % H; unsigned char *o = out + (y * W + x) * 4; int tx = x / 16, ty = y / 16;
    printf("  px(%d,%d) got %u %u %u want %d %d %d (flipped-y want %d %d %d)\n", x, y, o[0], o[1], o[2], (tx * 13) & 255, (ty * 29) & 255, ((tx ^ ty) * 7) & 255,
           (tx * 13) & 255, (((H - 1 - y) / 16) * 29) & 255, ((tx ^ ((H - 1 - y) / 16)) * 7) & 255); }
  printf("full-image check: %ld of %d pixels wrong (%.2f%%)\n", bad, W * H, 100.0 * bad / (W * H));
  printf("wrong pixels per 16-px column tile:"); for (int t = 0; t < W / 16; t++) printf(" %ld", badcol[t] / 16); printf("\n");
  return 0;
}
