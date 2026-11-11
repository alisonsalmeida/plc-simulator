#include "my_application.h"

int main(int argc, char** argv) {
  // If GTK_IM_MODULE is not explicitly set, fallback to "xim" to prevent
  // IBus queue deadlocks and dropped keystrokes on Linux desktop.
  if (!g_getenv("GTK_IM_MODULE")) {
    g_setenv("GTK_IM_MODULE", "xim", FALSE);
  }
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
