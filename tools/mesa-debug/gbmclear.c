// Minimal GPU render check: GBM device -> EGL GLES2 context -> clear an FBO -> read back.
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <gbm.h>
#include <fcntl.h>
#include <stdio.h>

static void step(const char *s) {
  fprintf(stderr, "step: %s\n", s);
  fflush(stderr);
}

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "usage: gbmclear /dev/dri/DEVICE\n");
    return 2;
  }
  int fd = open(argv[1], O_RDWR | O_CLOEXEC);
  if (fd < 0) { perror("open"); return 1; }
  step("gbm_create_device");
  struct gbm_device *gbm = gbm_create_device(fd);
  printf("gbm backend: %s\n", gbm ? gbm_device_get_backend_name(gbm) : "none"); fflush(stdout);
  PFNEGLGETPLATFORMDISPLAYEXTPROC get = (void *)eglGetProcAddress("eglGetPlatformDisplayEXT");
  step("eglGetPlatformDisplayEXT");
  EGLDisplay d = get(EGL_PLATFORM_GBM_KHR, gbm, NULL);
  EGLint maj, min;
  step("eglInitialize");
  if (!eglInitialize(d, &maj, &min)) { printf("eglInitialize failed\n"); return 1; }
  eglBindAPI(EGL_OPENGL_ES_API);
  EGLint ca[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
  step("eglCreateContext");
  EGLContext c = eglCreateContext(d, EGL_NO_CONFIG_KHR, EGL_NO_CONTEXT, ca);
  step("eglMakeCurrent");
  if (!eglMakeCurrent(d, EGL_NO_SURFACE, EGL_NO_SURFACE, c)) { printf("makeCurrent failed\n"); return 1; }
  printf("renderer: %s\n", glGetString(GL_RENDERER)); fflush(stdout);
  GLuint rb, fb;
  step("glGenRenderbuffers");
  glGenRenderbuffers(1, &rb);
  glBindRenderbuffer(GL_RENDERBUFFER, rb);
  step("glRenderbufferStorage");
  glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA4, 64, 64);
  glGenFramebuffers(1, &fb); glBindFramebuffer(GL_FRAMEBUFFER, fb);
  step("glFramebufferRenderbuffer");
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, rb);
  printf("fb status: 0x%x\n", glCheckFramebufferStatus(GL_FRAMEBUFFER));
  glClearColor(0.0f, 1.0f, 0.0f, 1.0f);
  step("glClear");
  glClear(GL_COLOR_BUFFER_BIT);
  step("glFinish");
  glFinish();
  unsigned char px[4] = {0};
  step("glReadPixels");
  glReadPixels(0, 0, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, px);
  printf("gl error: 0x%x\n", glGetError());
  printf("pixel: %u %u %u %u (expect 0 255 0 255)\n", px[0], px[1], px[2], px[3]);
  return 0;
}
