AC_INIT([efmdemo],[1.8],[bug@enterprisedb.com])
AM_INIT_AUTOMAKE([-Wall -Werror foreign])
AC_CONFIG_MACRO_DIRS([m4])
AC_PROG_AWK([gawk] nawk awk)
AC_PROG_YACC
AC_PROG_LEX
AM_PROG_AR
LT_INIT([aix-soname=both])
AM_CONDITIONAL([LINUX], [test `uname -s` = Linux] )
AM_CONDITIONAL([SUN], [test `uname -s` = SunOS] )
AM_CONDITIONAL([HPUX], [test `uname -s` = HP-UX] )
AM_CONDITIONAL([AIX], [test `uname -s` = AIX] )
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_FILES([
Makefile
bin/Makefile
share/Makefile
share/man/Makefile
share/man/man1/Makefile
share/pki/Makefile
share/pki/servers/Makefile
])
AC_OUTPUT
