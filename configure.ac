AC_INIT([xtables-addons-asn], [2.2.0])
AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_MACRO_DIR([m4])
AC_PROG_INSTALL
AM_INIT_AUTOMAKE([1.11 -Wall foreign subdir-objects tar-pax])
AC_PROG_CC
AM_PROG_CC_C_O
m4_ifdef([AM_PROG_AR], [AM_PROG_AR])
AC_DISABLE_STATIC
LT_INIT

# Enable silent rules by default
AM_SILENT_RULES([yes])

# Additional compiler checks
AC_PROG_AWK
AC_PROG_GREP
AC_PROG_SED

AC_ARG_WITH([kbuild],
	AS_HELP_STRING([--with-kbuild=PATH],
	[Path to kernel build directory [[/lib/modules/CURRENT/build]]])
AS_HELP_STRING([--without-kbuild],
	[Build only userspace tools]),
	[kbuilddir="$withval"],
	[kbuilddir="/lib/modules/$(uname -r)/build"])
#
# check for --without-kbuild
#
if [[ "$kbuilddir" == no ]]; then
	kbuilddir="";
fi

AC_CHECK_HEADERS([linux/netfilter/x_tables.h], [],
	[AC_MSG_ERROR([You need to have linux/netfilter/x_tables.h, see INSTALL file for details])])
PKG_CHECK_MODULES([libxtables], [xtables >= 1.4.5])
xtlibdir="$(pkg-config --variable=xtlibdir xtables)"

AC_ARG_WITH([xtlibdir],
	AS_HELP_STRING([--with-xtlibdir=PATH],
	[Path where to install Xtables extensions [[autodetect]]]),
	[xtlibdir="$withval"])
AC_MSG_CHECKING([Xtables module directory])
AC_MSG_RESULT([$xtlibdir])

regular_CPPFLAGS="-D_LARGEFILE_SOURCE=1 -D_LARGE_FILES -D_FILE_OFFSET_BITS=64 \
	-D_REENTRANT -I\${XA_TOPSRCDIR}/include"
regular_CFLAGS="-Wall -Waggregate-return -Wmissing-declarations \
	-Wmissing-prototypes -Wredundant-decls -Wshadow -Wstrict-prototypes \
	-Winline -pipe";

if test -n "$kbuilddir"; then
	AC_MSG_CHECKING([kernel version that we will build against])
	krel="$(make -sC "$kbuilddir" M=$PWD kernelrelease | $AWK -v 'FS=[[^0-9.]]' '{print $1; exit}')"
	save_IFS="$IFS"
	IFS='.'
	set x $krel
	IFS="$save_IFS"
	kmajor="$(($2+0))"
	kminor="$(($3+0))"
	kmicro="$(($4+0))"
	kstable="$(($5+0))"
	if test -z "$kmajor" -o -z "$kminor" -o -z "$kmicro"; then
		echo "WARNING: Version detection did not succeed. Continue at own luck.";
	else
		echo "$kmajor.$kminor.$kmicro.$kstable in $kbuilddir";
		if test "$kmajor" -gt 4 -o "$kmajor" -eq 4 -a "$kminor" -gt 12; then
			echo "WARNING: That kernel version is not officially supported yet. Continue at own luck.";
		elif test "$kmajor" -eq 4 -a "$kminor" -le 10; then
			:;
		elif test "$kmajor" -eq 3 -a "$kminor" -ge 7; then
			:;
		else
			echo "WARNING: That kernel version is not officially supported.";
		fi;
	fi;
fi;

AC_SUBST([regular_CPPFLAGS])
AC_SUBST([regular_CFLAGS])
AC_SUBST([kbuilddir])
AC_SUBST([xtlibdir])

# Enable debugging
AC_ARG_ENABLE([debug],
	AS_HELP_STRING([--enable-debug], [Enable debug mode]),
	[debug=$enableval], [debug=no])
if test "x$debug" = "xyes"; then
	regular_CFLAGS="$regular_CFLAGS -g -DDEBUG"
else
	regular_CFLAGS="$regular_CFLAGS -DNDEBUG"
fi

# Enable testing
AC_ARG_ENABLE([testing],
	AS_HELP_STRING([--enable-testing], [Enable testing framework]),
	[testing=$enableval], [testing=no])
AM_CONDITIONAL([ENABLE_TESTING], [test "x$testing" = "xyes"])

# Check for required tools for ASN data processing
AC_PATH_PROG([PERL], [perl], [no])
if test "x$PERL" = "xno"; then
	AC_MSG_WARN([Perl not found - ASN data processing scripts may not work])
fi

AC_PATH_PROG([BGPDUMP], [bgpdump], [no])
if test "x$BGPDUMP" = "xno"; then
	AC_MSG_WARN([bgpdump not found - ASN data processing will not work])
fi

AC_PATH_PROG([WGET], [wget], [no])
if test "x$WGET" = "xno"; then
	AC_PATH_PROG([CURL], [curl], [no])
	if test "x$CURL" = "xno"; then
		AC_MSG_WARN([Neither wget nor curl found - ASN data download will not work])
	fi
fi

AC_CONFIG_FILES([Makefile Makefile.iptrules Makefile.mans extensions/Makefile])

AC_OUTPUT

echo
echo "Configuration summary:"
echo "  Package version: ${PACKAGE_VERSION}"
echo "  Kernel module: $(if test -n "$kbuilddir"; then echo "yes ($kbuilddir)"; else echo "no"; fi)"
echo "  Debug mode: $debug"
echo "  Testing: $testing"
echo "  Install prefix: ${prefix}"
echo "  Xtables library dir: ${xtlibdir}"
echo
