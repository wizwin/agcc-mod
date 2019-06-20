agcc-mod
========

agcc wrapper mod for using Android NDK

Usage
=====

Initially you need to setup your build settings inside the script. Here are a few of the variables that you might want to change:

- NDK_BASE    - This is where your Andorid NDK is installed.
- NDK_VERSION - Android NDK version which you would like to use for build.
- ARCH_HOST   - Host machine that you are using.
- ARCH_TARGET - Target machine you want to compile for.
- SDK_LEVEL   - Android SDK level you plan to use.
- GCC_VERSION - GCC version which you want to use.

Valid values which you can use is specified in the script comments.

- On Windows:
    > perl agcc.pl test.c -o test


- On Linux:
    > agcc test.c -o test


I assume you have set the paths correctly, gave executable permissions etc.
