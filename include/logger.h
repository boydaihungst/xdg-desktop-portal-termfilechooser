#ifndef LOGGER_H
#define LOGGER_H

#include <stdio.h>

#define DEFAULT_LOGLEVEL ERROR

enum LOGLEVEL { QUIET, ERROR, WARN, INFO, DEBUG, TRACE };

struct logger_properties {
  enum LOGLEVEL level;
  FILE *dst;
};

enum LOGLEVEL get_logger_level(void);
void init_logger(FILE *dst, enum LOGLEVEL level);
enum LOGLEVEL get_loglevel(const char *level);
void logprint(enum LOGLEVEL level, char *msg, ...);

#endif
