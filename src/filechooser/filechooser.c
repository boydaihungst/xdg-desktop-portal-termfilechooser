#include "filechooser.h"
#include "xdpw.h"
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#define PATH_PREFIX "file://"
#define PATH_PORTAL "/tmp/termfilechooser.portal"

static const char object_path[] = "/org/freedesktop/portal/desktop";
static const char interface_name[] = "org.freedesktop.impl.portal.FileChooser";

// Helper function to URL encode a string
static char *url_encode(const char *s) {
  const char *hex = "0123456789abcdef";
  size_t len = strlen(s);
  unsigned char *encoded =
      malloc(len * 3 + 1); // Worst case: all chars need encoding
  unsigned char *p = encoded;
  for (size_t i = 0; i < len; i++) {
    unsigned char c = s[i];
    if (isalnum(c) || c == '-' || c == '_' || c == '.' || c == '~' ||
        c == '/') {
      *p++ = c;
    } else {
      *p++ = '%';
      *p++ = hex[c >> 4];
      *p++ = hex[c & 15];
    }
  }
  *p = '\0';
  return (char *)encoded;
}

static int exec_filechooser(void *data, bool writing, bool multiple,
                            bool directory, char *path, char ***selected_files,
                            size_t *num_selected_files) {
  struct xdpw_state *state = data;

  char *cmd_script = state->config->filechooser_conf.cmd;

  if (!cmd_script) {
    logprint(ERROR, "cmd not specified");
    return -1;
  }

  if (path == NULL) {
    path = "";
  }

  // Split the command into an array of arguments
  char *args[8];
  args[0] = cmd_script;
  args[1] = multiple ? "1" : "0";
  args[2] = directory ? "1" : "0";
  args[3] = writing ? "1" : "0";
  args[4] = path;
  args[5] = PATH_PORTAL;
  args[6] = get_logger_level() >= DEBUG ? "1" : "0";
  args[7] = NULL;

  logprint(DEBUG, "Command script path: %s", cmd_script);
  if (access(cmd_script, F_OK) != 0) {
    logprint(ERROR, "Command script does not exist: %s", cmd_script);
    return -1;
  }
  if (access(cmd_script, X_OK) != 0) {
    logprint(ERROR, "Command script is not executable: %s", cmd_script);
    return -1;
  }
  // Check if the portal file exists and have read write permission
  if (access(PATH_PORTAL, F_OK) == 0) {
    if (access(PATH_PORTAL, R_OK | W_OK) != 0) {
      logprint(ERROR,
               "failed to start portal, make sure you have permission to read "
               "and write %s",
               PATH_PORTAL);
      return -1;
    }
  }
  remove(PATH_PORTAL);

  pid_t pid = fork();
  if (pid == -1) {
    logprint(ERROR, "fork failed: %d", strerror(errno));
    return -1;
  } else if (pid == 0) {
    // Child process
    execvp(cmd_script, args);
    logprint(ERROR, "execvp failed: %s", strerror(errno));
    _exit(EXIT_FAILURE);
  } else {
    // Parent process
    int status;
    waitpid(pid, &status, 0);
    if (WIFEXITED(status) && WEXITSTATUS(status) != 0) {
      logprint(ERROR, "command failed with status %d", WEXITSTATUS(status));
      return -1;
    }
  }

  FILE *fp = fopen(PATH_PORTAL, "r+");
  if (fp == NULL) {
    logprint(DEBUG, "Aborted");
    return 0;
  }

  size_t num_lines = 0;
  int cr;

  // NOTE: Some file manager like lf doesn't add newline at the end of file

  // Go to the end to check size
  if (fseek(fp, 0, SEEK_END) != 0) {
    fclose(fp);
    return -1;
  }

  long size = ftell(fp);
  if (size == 0) {
    // Empty file, do nothing
    fclose(fp);
    return 0;
  }

  // Check last character
  if (fseek(fp, -1, SEEK_END) != 0) {
    fclose(fp);
    return -1;
  }

  int last = fgetc(fp);
  if (last != '\n') {
    fseek(fp, 0, SEEK_END); // move to EOF again
    fputc('\n', fp);        // append newline
  }
  fseek(fp, 0, SEEK_SET);

  // Count lines
  while ((cr = getc(fp)) != EOF) {
    if (cr == '\n') {
      num_lines++;
    }
  }
  if (ferror(fp)) {
    fclose(fp);
    return 1;
  }
  rewind(fp);

  if (num_lines == 0) {
    num_lines = 1;
  }

  *num_selected_files = num_lines;
  *selected_files = malloc((num_lines + 1) * sizeof(char *));

  for (size_t i = 0; i < num_lines; i++) {
    size_t n = 0;
    char *line = NULL;
    ssize_t nread = getline(&line, &n, fp);
    if (ferror(fp)) {
      free(line);
      for (size_t j = 0; j < i - 1; j++) {
        free((*selected_files)[j]);
      }
      free(*selected_files);
      fclose(fp);
      return 1;
    }

    if (nread > 0 && line[nread - 1] == '\n') {
      line[nread - 1] = '\0';
    }
    char *encoded_path = url_encode(line);
    size_t str_size = strlen(PATH_PREFIX) + strlen(encoded_path) + 1;
    (*selected_files)[i] = malloc(str_size);
    snprintf((*selected_files)[i], str_size, "%s%s", PATH_PREFIX, encoded_path);
    free(line);
    free(encoded_path);
  }
  (*selected_files)[num_lines] = NULL;

  fclose(fp);
  return 0;
}

static int method_open_file(sd_bus_message *msg, void *data,
                            sd_bus_error *ret_error) {
  int ret = 0;

  char *handle, *app_id, *parent_window, *title;
  ret = sd_bus_message_read(msg, "osss", &handle, &app_id, &parent_window,
                            &title);
  if (ret < 0) {
    return ret;
  }

  ret = sd_bus_message_enter_container(msg, 'a', "{sv}");
  if (ret < 0) {
    return ret;
  }
  char *key;
  int inner_ret = 0;
  int multiple = 0, directory = 0;
  char *current_folder = NULL;

  while ((ret = sd_bus_message_enter_container(msg, 'e', "sv")) > 0) {
    inner_ret = sd_bus_message_read(msg, "s", &key);
    if (inner_ret < 0) {
      return inner_ret;
    }

    logprint(DEBUG, "dbus: option %s", key);
    if (strcmp(key, "multiple") == 0) {
      sd_bus_message_read(msg, "v", "b", &multiple);
      logprint(DEBUG, "dbus: option multiple: %d", multiple);
    } else if (strcmp(key, "modal") == 0) {
      int modal;
      sd_bus_message_read(msg, "v", "b", &modal);
      logprint(DEBUG, "dbus: option modal: %d", modal);
    } else if (strcmp(key, "directory") == 0) {
      sd_bus_message_read(msg, "v", "b", &directory);
      logprint(DEBUG, "dbus: option directory: %d", directory);
    } else if (strcmp(key, "current_folder") == 0) {
      const void *p = NULL;
      size_t sz = 0;
      inner_ret = sd_bus_message_enter_container(msg, 'v', "ay");
      if (inner_ret < 0) {
        return inner_ret;
      }
      inner_ret = sd_bus_message_read_array(msg, 'y', &p, &sz);
      if (inner_ret < 0) {
        return inner_ret;
      }
      inner_ret = sd_bus_message_exit_container(msg);
      if (inner_ret < 0) {
        return inner_ret;
      }

      current_folder = (char *)p;
      logprint(DEBUG, "dbus: option current_folder: %s", current_folder);
    } else {
      logprint(WARN, "dbus: unknown option %s", key);
      sd_bus_message_skip(msg, "v");
    }

    inner_ret = sd_bus_message_exit_container(msg);
    if (inner_ret < 0) {
      return inner_ret;
    }
  }
  if (ret < 0) {
    return ret;
  }
  ret = sd_bus_message_exit_container(msg);
  if (ret < 0) {
    return ret;
  }

  // TODO: cleanup this
  struct xdpw_request *req =
      xdpw_request_create(sd_bus_message_get_bus(msg), handle);
  if (req == NULL) {
    return -ENOMEM;
  }

  char **selected_files = NULL;
  size_t num_selected_files = 0;
  if (current_folder == NULL) {
    struct xdpw_state *state = data;
    char *default_dir = state->config->filechooser_conf.default_dir;
    if (!default_dir) {
      logprint(ERROR, "default_dir not specified");
      return -1;
    }
    current_folder = default_dir;
  }

  ret = exec_filechooser(data, false, multiple, directory, current_folder,
                         &selected_files, &num_selected_files);
  if (ret) {
    goto cleanup;
  }

  logprint(TRACE, "(OpenFile) Number of selected files: %d",
           num_selected_files);
  for (size_t i = 0; i < num_selected_files; i++) {
    logprint(TRACE, "%d. %s", i, selected_files[i]);
  }

  sd_bus_message *reply = NULL;
  ret = sd_bus_message_new_method_return(msg, &reply);
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_message_append(reply, "u", PORTAL_RESPONSE_SUCCESS, 1);
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_message_open_container(reply, 'a', "{sv}");
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_message_open_container(reply, 'e', "sv");
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_message_append_basic(reply, 's', "uris");
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_message_open_container(reply, 'v', "as");
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_message_append_strv(reply, selected_files);
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_message_close_container(reply);
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_message_close_container(reply);
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_message_close_container(reply);
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_send(NULL, reply, NULL);
  if (ret < 0) {
    goto cleanup;
  }

  sd_bus_message_unref(reply);

cleanup:
  for (size_t i = 0; i < num_selected_files; i++) {
    free(selected_files[i]);
  }
  free(selected_files);

  remove(PATH_PORTAL);
  return ret;
}

static int method_save_file(sd_bus_message *msg, void *data,
                            sd_bus_error *ret_error) {
  int ret = 0;

  char *handle, *app_id, *parent_window, *title;
  ret = sd_bus_message_read(msg, "osss", &handle, &app_id, &parent_window,
                            &title);
  if (ret < 0) {
    return ret;
  }

  ret = sd_bus_message_enter_container(msg, 'a', "{sv}");
  if (ret < 0) {
    return ret;
  }
  char *key;
  int inner_ret = 0;
  char *current_name;
  char *current_folder = NULL;
  while ((ret = sd_bus_message_enter_container(msg, 'e', "sv")) > 0) {
    inner_ret = sd_bus_message_read(msg, "s", &key);
    if (inner_ret < 0) {
      return inner_ret;
    }

    logprint(DEBUG, "dbus: option %s", key);
    if (strcmp(key, "current_name") == 0) {
      sd_bus_message_read(msg, "v", "s", &current_name);
      logprint(DEBUG, "dbus: option current_name: %s", current_name);
    } else if (strcmp(key, "current_folder") == 0) {
      const void *p = NULL;
      size_t sz = 0;
      inner_ret = sd_bus_message_enter_container(msg, 'v', "ay");
      if (inner_ret < 0) {
        return inner_ret;
      }
      inner_ret = sd_bus_message_read_array(msg, 'y', &p, &sz);
      if (inner_ret < 0) {
        return inner_ret;
      }
      current_folder = (char *)p;
      logprint(DEBUG, "dbus: option current_folder: %s", current_folder);
    } else if (strcmp(key, "current_file") == 0) {
      // when saving an existing file
      const void *p = NULL;
      size_t sz = 0;
      inner_ret = sd_bus_message_enter_container(msg, 'v', "ay");
      if (inner_ret < 0) {
        return inner_ret;
      }
      inner_ret = sd_bus_message_read_array(msg, 'y', &p, &sz);
      if (inner_ret < 0) {
        return inner_ret;
      }
      current_name = (char *)p;
      logprint(DEBUG,
               "dbus: option replace current_name with current_file : %s",
               current_name);
    } else {
      logprint(WARN, "dbus: unknown option %s", key);
      sd_bus_message_skip(msg, "v");
    }

    inner_ret = sd_bus_message_exit_container(msg);
    if (inner_ret < 0) {
      return inner_ret;
    }
  }

  // TODO: cleanup this
  struct xdpw_request *req =
      xdpw_request_create(sd_bus_message_get_bus(msg), handle);
  if (req == NULL) {
    return -ENOMEM;
  }

  if (current_folder == NULL) {
    struct xdpw_state *state = data;
    char *default_dir = state->config->filechooser_conf.default_dir;
    if (!default_dir) {
      logprint(ERROR, "default_dir not specified");
      return -1;
    }
    current_folder = default_dir;
  }

  size_t path_size =
      snprintf(NULL, 0, "%s/%s", current_folder, current_name) + 1;
  char *path = malloc(path_size);
  snprintf(path, path_size, "%s/%s", current_folder, current_name);

  bool file_already_exists = true;
  while (file_already_exists) {
    if (access(path, F_OK) == 0) {
      char *path_tmp = malloc(path_size);
      snprintf(path_tmp, path_size, "%s", path);
      path_size += 1;
      path = realloc(path, path_size);
      snprintf(path, path_size, "%s_", path_tmp);
      free(path_tmp);
    } else {
      file_already_exists = false;
    }
  }

  char **selected_files = NULL;
  size_t num_selected_files = 0;
  ret = exec_filechooser(data, true, false, false, path, &selected_files,
                         &num_selected_files);
  if (ret || num_selected_files == 0) {
    remove(path);
    ret = -1;
    goto cleanup;
  }

  logprint(TRACE, "(SaveFile) Number of selected files: %d",
           num_selected_files);
  for (size_t i = 0; i < num_selected_files; i++) {
    logprint(TRACE, "%d. %s", i, selected_files[i]);
  }

  sd_bus_message *reply = NULL;
  ret = sd_bus_message_new_method_return(msg, &reply);
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_message_append(reply, "u", PORTAL_RESPONSE_SUCCESS, 1);
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_message_open_container(reply, 'a', "{sv}");
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_message_open_container(reply, 'e', "sv");
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_message_append_basic(reply, 's', "uris");
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_message_open_container(reply, 'v', "as");
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_message_append_strv(reply, selected_files);
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_message_close_container(reply);
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_message_close_container(reply);
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_message_close_container(reply);
  if (ret < 0) {
    goto cleanup;
  }

  ret = sd_bus_send(NULL, reply, NULL);
  if (ret < 0) {
    goto cleanup;
  }

  sd_bus_message_unref(reply);

cleanup:
  for (size_t i = 0; i < num_selected_files; i++) {
    free(selected_files[i]);
  }
  free(selected_files);
  free(path);

  remove(PATH_PORTAL);
  return ret;
}

static const sd_bus_vtable filechooser_vtable[] = {
    SD_BUS_VTABLE_START(0),
    SD_BUS_METHOD("OpenFile", "osssa{sv}", "ua{sv}", method_open_file,
                  SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_METHOD("SaveFile", "osssa{sv}", "ua{sv}", method_save_file,
                  SD_BUS_VTABLE_UNPRIVILEGED),
    SD_BUS_VTABLE_END};

int xdpw_filechooser_init(struct xdpw_state *state) {
  // TODO: cleanup
  sd_bus_slot *slot = NULL;
  logprint(DEBUG, "dbus: init %s", interface_name);
  return sd_bus_add_object_vtable(state->bus, &slot, object_path,
                                  interface_name, filechooser_vtable, state);
}
