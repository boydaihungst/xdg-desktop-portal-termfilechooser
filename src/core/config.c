#include "config.h"
#include "logger.h"
#include "xdpw.h"

#include <ini.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <wordexp.h>

#define FILECHOOSER_DEFAULT_CMD                                                \
  "/usr/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh"
#define FILECHOOSER_DEFAULT_DIR "$HOME"

static char *expand_env(const char *input) {
  wordexp_t p;
  if (wordexp(input, &p, 0) != 0) {
    return strdup(input); // Return original if expansion fails
  }
  char *expanded = strdup(p.we_wordv[0]);
  wordfree(&p);
  return expanded;
}

void print_config(enum LOGLEVEL loglevel, struct xdpw_config *config) {
  logprint(loglevel, "config: cmd:  %s", config->filechooser_conf.cmd);
  logprint(loglevel, "config: default_dir:  %s",
           config->filechooser_conf.default_dir);
}

// NOTE: calling finish_config won't prepare the config to be read again from
// config file with init_config since to pointers and other values won't be
// reset to NULL, or 0
void finish_config(struct xdpw_config *config) {
  logprint(DEBUG, "config: destroying config");
  free(config->filechooser_conf.cmd);
  free(config->filechooser_conf.default_dir);
}

static void parse_string(char **dest, const char *value) {
  if (value == NULL || *value == '\0') {
    logprint(TRACE, "config: skipping empty value in config file");
    return;
  }
  free(*dest);
  char *expanded_cmd = expand_env(value);
  *dest = strdup(expanded_cmd);
  free(expanded_cmd);
}

static int handle_ini_filechooser(struct config_filechooser *filechooser_conf,
                                  const char *key, const char *value) {
  if (strcmp(key, "cmd") == 0) {
    parse_string(&filechooser_conf->cmd, value);
  } else if (strcmp(key, "default_dir") == 0) {
    parse_string(&filechooser_conf->default_dir, value);
  } else {
    logprint(TRACE, "config: skipping invalid key in config file");
    return 0;
  }
  return 1;
}

static int handle_ini_config(void *data, const char *section, const char *key,
                             const char *value) {
  struct xdpw_config *config = (struct xdpw_config *)data;
  logprint(TRACE, "config: parsing section %s, key %s, value %s", section, key,
           value);

  if (strcmp(section, "filechooser") == 0) {
    return handle_ini_filechooser(&config->filechooser_conf, key, value);
  }

  logprint(TRACE, "config: skipping invalid key in config file");
  return 0;
}

static void default_config(struct xdpw_config *config) {
  char *expanded_cmd = expand_env(FILECHOOSER_DEFAULT_CMD);
  config->filechooser_conf.cmd = strdup(expanded_cmd);
  free(expanded_cmd);

  char *expanded_dir = expand_env(FILECHOOSER_DEFAULT_DIR);
  config->filechooser_conf.default_dir = strdup(expanded_dir);
  free(expanded_dir);
}

static bool file_exists(const char *path) {
  return path && access(path, R_OK) != -1;
}

static char *config_path(const char *prefix, const char *filename) {
  if (!prefix || !prefix[0] || !filename || !filename[0]) {
    return NULL;
  }

  char *config_folder = "xdg-desktop-portal-termfilechooser";

  size_t size = 3 + strlen(prefix) + strlen(config_folder) + strlen(filename);
  char *path = calloc(size, sizeof(char));
  snprintf(path, size, "%s/%s/%s", prefix, config_folder, filename);
  return path;
}

static char *get_config_path(void) {
  const char *home = getenv("HOME");
  char *config_home_fallback = NULL;
  if (home != NULL && home[0] != '\0') {
    size_t size_fallback = 1 + strlen(home) + strlen("/.config");
    config_home_fallback = calloc(size_fallback, sizeof(char));
    snprintf(config_home_fallback, size_fallback, "%s/.config", home);
  }

  const char *config_home = getenv("XDG_CONFIG_HOME");
  if (config_home == NULL || config_home[0] == '\0') {
    config_home = config_home_fallback;
  }

  const char *prefix[2];
  prefix[0] = config_home;
  prefix[1] = SYSCONFDIR "/xdg";

  const char *xdg_current_desktop = getenv("XDG_CURRENT_DESKTOP");
  const char *config_fallback = "config";

  char *config_list = NULL;
  for (size_t i = 0; i < 2; i++) {
    if (xdg_current_desktop) {
      config_list = strdup(xdg_current_desktop);
      char *config = strtok(config_list, ":");
      while (config) {
        char *path = config_path(prefix[i], config);
        if (!path) {
          config = strtok(NULL, ":");
          continue;
        }
        logprint(TRACE, "config: trying config file %s", path);
        if (file_exists(path)) {
          free(config_list);
          free(config_home_fallback);
          return path;
        }
        free(path);
        config = strtok(NULL, ":");
      }
      free(config_list);
    }
    char *path = config_path(prefix[i], config_fallback);
    if (!path) {
      continue;
    }
    logprint(TRACE, "config: trying config file %s", path);
    if (file_exists(path)) {
      free(config_home_fallback);
      return path;
    }
    free(path);
  }

  free(config_home_fallback);
  return NULL;
}

void init_config(char **const configfile, struct xdpw_config *config) {
  if (*configfile == NULL) {
    *configfile = get_config_path();
  }

  default_config(config);
  if (*configfile == NULL) {
    logprint(ERROR, "config: no config file found");
    return;
  }
  if (ini_parse(*configfile, handle_ini_config, config) < 0) {
    logprint(ERROR, "config: unable to load config file %s", *configfile);
  }
}
