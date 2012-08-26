#!/usr/bin/perl -w
use strict;

# Copyright 2008, Andrew Ross andy@plausible.org
# Distributable under the terms of the GNU GPL, see COPYING for details

# The Android toolchain is ... rough.  Rather than try to manage the
# complexity directly, this script wraps the tools into an "agcc" that
# works a lot like a gcc command line does for a native platform or a
# properly integrated cross-compiler.  It accepts arbitrary arguments,
# but interprets the following specially:
#
# -E/-S/-c/-shared - Enable needed arguments (linker flags, include
#                    directories, runtime startup objects...) for the
#                    specified compilation mode when building under
#                    android.
#
# -O<any> - Turn on the optimizer flags used by the Dalvik build.  No
#           control is provided over low-level optimizer flags.
#
# -W<any> - Turn on the warning flags used by the Dalvik build.  No
#           control is provided over specific gcc warning flags.
#
# Notes:
# + The prebuilt arm-eabi-gcc from a built (!) android source
#   directory must be on your PATH.
# + All files are compiled with -fPIC to an ARMv5TE target.  No
#   support is provided for thumb.
# + No need to pass a "-Wl,-soname" argument when linking with
#   -shared, it uses the file name always (so don't pass a directory in
#   the output path for a shared library!)
#
# ================
# Revision History
# ================
#
# dd.mm.2008 - Andrew Ross
# > Initial and original version.
#
# 26.08.2012 - Winny (WiZarD)
# > Updated to work with Andorid NDK r8b.
# > Removed references to android source includes.
# > Added support to compile with mips and x86 toolchain.
# > ARM arch is set to Cortex A9 v7-a as default.

# Please configure your build settings here.
#
# Not all build settings are valid when combined. You should be aware 
# of what each level/version of SDK/NDK supports.
#

# Update your NDK base path here (not including the NDK folder itself)
my $NDK_BASE = "E:/SDE/Android/NDK";

# Valid NDK versions are: r7b, r8b
my $NDK_VERSION = "r8b";

# Valid Host architectures are: windows, linux-x86
my $ARCH_HOST = "windows";

# Valid Target architectures are: arm, mips, x86
my $ARCH_TARGET = "arm";

# Valid SDK levels are: android-3, android-4, android-5, android-8, android-9, android-14
my $SDK_LEVEL = "android-14";

# Valid GCC versions are: 4.4.3, 4.6
my $GCC_VERSION = "4.6";

my $NDK_PATH = "$NDK_BASE/android-ndk-$NDK_VERSION";
my $PLATFORM_BASE = "$NDK_PATH/platforms/$SDK_LEVEL/arch-$ARCH_TARGET";

my $TOOLCHAIN_BASE = "";
my $ARCH_TARGET_ABI = "";
my $ARCH_TARGET_VERSION = "";
my $LINKER_SCRIPT_X = "";
my $LINKER_SCRIPT_XSC = "";

if ($ARCH_TARGET eq "mips") {
	$ARCH_TARGET = "mipsel";
	$ARCH_TARGET_ABI = "linux-android";
    $ARCH_TARGET_VERSION = "mips-r2";

	# Set the linker script files
	$LINKER_SCRIPT_X = "elf32ltsmip.x";
	$LINKER_SCRIPT_XSC = "elf32ltsmip.xsc"
}

if ($ARCH_TARGET eq "arm") {
	$ARCH_TARGET_ABI = "linux-androideabi";
    $ARCH_TARGET_VERSION = "armv7-a";

	# Set the linker script files
	$LINKER_SCRIPT_X = "armelf_linux_eabi.x";
	$LINKER_SCRIPT_XSC = "armelf_linux_eabi.xsc"
}

$TOOLCHAIN_BASE = "$NDK_PATH/toolchains/$ARCH_TARGET-$ARCH_TARGET_ABI-$GCC_VERSION";

if ($ARCH_TARGET eq "x86") {
	# Reset toolchain base path for x86
	$TOOLCHAIN_BASE = "$NDK_PATH/toolchains/$ARCH_TARGET-$GCC_VERSION";

	$ARCH_TARGET = "i686";
	$ARCH_TARGET_ABI = "linux-android";

	# Set the linker script files
	$LINKER_SCRIPT_X = "elf_i386.x";
	$LINKER_SCRIPT_XSC = "elf_i386.xsc"
}

my $TOOLCHAIN = "$TOOLCHAIN_BASE/prebuilt/$ARCH_HOST";

if ($GCC_VERSION eq "4.6") {
	$GCC_VERSION = "4.6.x-google";
}

my $ALIB = "$TOOLCHAIN/lib/gcc/$ARCH_TARGET-$ARCH_TARGET_ABI/$GCC_VERSION/$ARCH_TARGET_VERSION";

my @include_paths = (
    "-I$PLATFORM_BASE/usr/include");

my @preprocess_args = (
    "-DANDROID",
    "-DSK_RELEASE",
    "-DNDEBUG",
    "-UDEBUG");

my @warn_args = (
    "-Wall",
    "-Wno-unused", # why?
    "-Wno-multichar", # why?
    "-Wstrict-aliasing=2"); # Implicit in -Wall per texinfo

my @compile_args = (
	"-msoft-float",
    "-fpic",
    "-fno-exceptions",
    "-ffunction-sections",
    "-funwind-tables", # static exception-like tables
    "-fstack-protector", # check guard variable before return
    "-fmessage-length=0"); # No line length limit to error messages

my @compile_args_arm = (
    "-mcpu=cortex-a9",
    "-march=armv7-a",
	"-mthumb-interwork");

my @optimize_args = (
    "-O2",
    "-finline-functions",
    "-finline-limit=300",
    "-fno-inline-functions-called-once",
    "-fgcse-after-reload",
    "-frerun-cse-after-loop", # Implicit in -O2 per texinfo
    "-frename-registers",
    "-fomit-frame-pointer",
    "-fstrict-aliasing", # Implicit in -O2 per texinfo
    "-funswitch-loops");

my @link_args = (
    "-Bdynamic",
    "-Wl,-T,$TOOLCHAIN/$ARCH_TARGET-$ARCH_TARGET_ABI/lib/ldscripts/$LINKER_SCRIPT_X",
    "-Wl,-dynamic-linker,/system/bin/linker",
    "-Wl,--gc-sections",
    "-Wl,-z,nocopyreloc",
    "-Wl,--no-undefined",
    "-Wl,-rpath-link=$ALIB",
    "-L$ALIB",
	"-L$PLATFORM_BASE/usr/lib",
    "-nostdlib",
	"$PLATFORM_BASE/usr/lib/crtbegin_dynamic.o",
	"$PLATFORM_BASE/usr/lib/crtend_android.o",
    "$ALIB/libgcc.a",
    "-lc",
    "-lm");

# Also need: -Wl,-soname,libXXXX.so
my @shared_args = (
    "-nostdlib",
    "-Wl,-T,$TOOLCHAIN/$ARCH_TARGET-$ARCH_TARGET_ABI/lib/ldscripts/$LINKER_SCRIPT_XSC",
    "-Wl,--gc-sections",
    "-Wl,-shared,-Bsymbolic",
    "-L$ALIB",
	"-L$PLATFORM_BASE/usr/lib",
    "-Wl,--no-whole-archive",
    "-lc",
    "-lm",
    "-Wl,--no-undefined",
	"$PLATFORM_BASE/usr/lib/crtbegin_so.o",
	"$PLATFORM_BASE/usr/lib/crtend_so.o",
    "$ALIB/libgcc.a",
    "-Wl,--whole-archive"); # .a, .o input files go *after* here

# Now implement a quick parser for a gcc-like command line

my %MODES = ("-E"=>1, "-c"=>1, "-S"=>1, "-shared"=>1);

my $mode = "DEFAULT";
my $out;
my $warn = 0;
my $opt = 0;
my @args = ();
my $have_src = 0;
while(@ARGV) {
    my $a = shift;
    if(defined $MODES{$a}) {
	die "Can't specify $a and $mode" if $mode ne "DEFAULT";
	$mode = $a;
    } elsif($a eq "-o") {
	die "Missing -o argument" if !@ARGV;
	die "Duplicate -o argument" if defined $out;
	$out = shift;
    } elsif($a =~ /^-W.*/) {
	$warn = 1;
    } elsif($a =~ /^-O.*/) {
	$opt = 1;
    } else {
	if($a =~ /\.(c|cpp|cxx)$/i) { $have_src = 1; }
	push @args, $a;
    }
}

my $need_cpp = 0;
my $need_compile = 0;
my $need_link = 0;
my $need_shlink = 0;
if($mode eq "DEFAULT") { $need_cpp = $need_compile = $need_link = 1; }
if($mode eq "-E") { $need_cpp = 1; }
if($mode eq "-c") { $need_cpp = $need_compile = 1; }
if($mode eq "-S") { $need_cpp = $need_compile = 1; }
if($mode eq "-shared") { $need_shlink = 1; }

if($have_src and $mode ne "-E") { $need_cpp = $need_compile = 1; }

# Assemble the command:
my @cmd = ("$TOOLCHAIN/bin/$ARCH_TARGET-$ARCH_TARGET_ABI-gcc");
if($mode ne "DEFAULT") { @cmd = (@cmd, $mode); }
if(defined $out) { @cmd = (@cmd, "-o", $out); }
if($need_cpp) { @cmd = (@cmd, @include_paths, @preprocess_args); }
if($need_compile){
	@cmd = (@cmd, @compile_args);
	if ($ARCH_TARGET eq "arm") {
		@cmd = (@cmd, @compile_args_arm);
	}

    if($warn) { @cmd = (@cmd, @warn_args); }
    if($opt) { @cmd = (@cmd, @optimize_args); }
}
if($need_link) { @cmd = (@cmd, @link_args); }
if($need_shlink) { @cmd = (@cmd, @shared_args); }
@cmd = (@cmd, @args);

print join(" ", @cmd), "\n"; # Spit it out if you're curious
exec(@cmd);