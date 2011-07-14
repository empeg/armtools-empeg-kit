# Where to install your toolchain
#
# Other good choices might be /opt/empeg or /usr/local/armtools
# Do NOT use /usr/local or /usr as we will install a bin/cpp (not
# bin/arm-empeg-linux-cpp) which predefines __arm__ and not whatever your
# architecture should be predefining.
#
PREFIX:=/opt/local/armtools

# The other files you need (apart from this Makefile)
#
# The first two should have come with this Makefile; the rest can be found at
# any good archive site. Any Linux 2.2 or 2.4 tarball should do (except 2.4.9
# which doesn't seem to work; 2.4.3 definitely does). It DOESN'T have to be the
# same kernel that the car player actually uses.
#
FILES := gcc-inhibitlibc-patch.gz \
	gcc-2.95.3-diff-010218.gz \
	binutils-2.21.1.tar.gz	\
	gcc-2.95.3.tar.gz \
	glibc-2.1.3.tar.gz \
	glibc-crypt-2.1.tar.gz \
	glibc-linuxthreads-2.1.3.tar.gz \
	glibc-csu.patch \
	gcc3-binutils.patch \
	linux-Makefile.patch \
	gcc-configure.patch \
	gcc-configure2.patch \
	gcc-nold.patch \
	gcc-stage1-docs.patch \
	glibc-man.patch \
	config.sub \
	config.guess \
	ncurses-5.2.tar.gz \
	ncurses-tic.diff \
	zlib-1.1.4.tar.gz \
	gettext-0.18.1.1.tar.gz \
	gettext.patch \
	linux-2.*.tar.gz

FILES_PRESENT := $(wildcard $(FILES))

all: check arm-linux-gcc arm-linux-ncurses arm-linux-zlib arm-linux-gettext
	@echo
	@echo Done

clean:
	rm -rf build-*
	rm -rf arm-linux-*

# Make binutils (the linker and assembler, mainly)
#
arm-linux-binutils:
	@echo Making binutils
	rm -rf build-binutils
	mkdir -p build-binutils
	tar xzf binutils*.tar.gz -C build-binutils
	( cd build-binutils/* \
		&& ./configure --target=arm-empeg-linux --prefix=$(PREFIX) --enable-shared --disable-static --with-gnu-ld --disable-nls --host=i386-apple-darwin --build=i386-apple-darwin --enable-languages=c,c++ \
		&& $(MAKE) -j1 \
		&& $(MAKE) install )
	du -s build-binutils > arm-linux-binutils
	rm -rf build-binutils

# Get hold of a set of ARM kernel headers
#
# For consistency's sake we make some brand new ones from a kernel tarball
#
arm-linux-headers:
	@echo Making arm-linux-headers from $(wildcard linux-2*.tar.gz)
	rm -rf build-linux
	mkdir -p build-linux
	tar xzf linux-2*.tar.gz -C build-linux
	cat linux-Makefile.patch|patch -d build-linux/l* -p0 
	cp build-linux/linux/arch/arm/defconfig build-linux/linux/.config
	echo -e "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n" | make -C build-linux/linux ARCH=arm oldconfig
	make -C build-linux/linux ARCH=arm dep
	rm -rf $(PREFIX)/arm-empeg-linux/include
	mkdir -p $(PREFIX)/arm-empeg-linux/include
	mkdir -p $(PREFIX)/arm-empeg-linux/include/asm
	(cd build-linux/*/include/asm-arm; tar cpf - .)|(cd $(PREFIX)/arm-empeg-linux/include/asm; tar xpf -)
	mkdir -p $(PREFIX)/arm-empeg-linux/include/linux
	(cd build-linux/*/include/linux; tar cpf - .) |(cd $(PREFIX)/arm-empeg-linux/include/linux; tar xpf -)
	chmod -R a+r $(PREFIX)/arm-empeg-linux/include
	sh -c "find $(PREFIX)/arm-empeg-linux/include -type d | xargs chmod a+x"
	du -s build-linux > arm-linux-headers
	rm -rf build-linux

# Make a stage-1 (no C library) C-only compiler
#
arm-linux-gcc-stage1: arm-linux-binutils arm-linux-headers
	@echo Making gcc-stage1
	rm -rf build-stage1
	mkdir -p build-stage1/build
	tar xzf gcc-*.tar.gz -C build-stage1
	gzcat gcc-inhibitlibc-patch.gz | patch -d build-stage1/gcc-*/gcc/config/arm
	cat gcc-stage1-docs.patch|patch -d build-stage1/gcc-* -p0
	cat gcc3-binutils.patch|patch -d build-stage1/gcc-* -p0 
	cat gcc3-binutils.patch|patch -d build-stage1/gcc-*/texinfo/lib -p1
	export PATH=$(PREFIX)/bin:$(PATH) ; ( cd build-stage1/build \
		&& which arm-empeg-linux-ld \
		&& ../gcc-*/configure --disable-threads --target=arm-empeg-linux --prefix=$(PREFIX) --host=i386-linux --build=i386-linux --enable-languages="c" \
		&& $(MAKE) all-gcc \
		&& $(MAKE) install-gcc )
	du -s build-stage1 > arm-linux-gcc-stage1
	rm -rf build-stage1

# Make the C library
#
arm-linux-glibc: arm-linux-gcc-stage1 arm-linux-headers
	@echo Making glibc
	rm -rf build-glibc
	mkdir -p build-glibc
	tar xzf glibc-2*.tar.gz  -C build-glibc
	tar xzf glibc-li*.tar.gz -C build-glibc/*
	tar xzf glibc-cr*.tar.gz -C build-glibc/*
	cat glibc-man.patch|patch -d build-glibc/glibc* -p0 
	cat glibc-csu.patch|patch -d build-glibc/glibc* -p0
	mkdir -p build-glibc/build
	export PATH=$(PREFIX)/bin:$(PATH) ; ( cd build-glibc/build \
		&& CC=arm-empeg-linux-gcc ../glibc*/configure arm-empeg-linux --build=i386-linux --prefix=$(PREFIX)/arm-empeg-linux --enable-add-ons --disable-profile \
		&& $(MAKE) \
		&& $(MAKE) install )
	du -s build-glibc > arm-linux-glibc
	rm -rf build-glibc

# Make the userland C and C++ cross-compilers
#
arm-linux-gcc: arm-linux-binutils arm-linux-headers arm-linux-glibc
	@echo Making gcc
	rm -rf build-gcc
	mkdir -p build-gcc/build
	tar xzf gcc-*.tar.gz -C build-gcc
	-gzcat gcc-2.95.3-diff-010218.gz | patch -d build-gcc/g* -p0
	cat gcc-configure.patch|patch -d build-gcc/gcc-* -p0 
	cat gcc-configure2.patch|patch -d build-gcc/gcc-* -p0 
	cat gcc3-binutils.patch|patch -d build-gcc/gcc-* -p0 
	cat gcc3-binutils.patch|patch -d build-gcc/gcc-*/texinfo/lib -p1
	cat gcc-stage1-docs.patch|patch -d build-gcc/gcc-* -p0
	-cp config.sub config.guess build-gcc/g*
	export PATH=$(PREFIX)/bin:$(PATH) ; ( cd build-gcc/build \
		&& ../gcc-*/configure --target=arm-empeg-linux --prefix=$(PREFIX) --enable-languages="c,c++" \
		&& $(MAKE) \
		&& $(MAKE) install )
	du -s build-gcc > arm-linux-gcc
	rm -rf build-gcc

arm-linux-ncurses: arm-linux-gcc
	@echo Making ncurses
	rm -rf build-ncurses
	mkdir -p build-ncurses/build
	tar xzf ncurses-*.tar.gz -C build-ncurses
	cat ncurses-tic.diff|patch -d build-ncurses/ncurses-* -p1 
	export PATH=$(PATH):$(PREFIX)/bin ; ( cd build-ncurses/build \
		&& CC=arm-empeg-linux-gcc ../ncurses*/configure arm-empeg-linux --target=arm-linux --with-shared --without-cxx --without-cxx-binding --prefix=/ --with-syslibroot=$(PREFIX)/arm-empeg-linux \
		&& $(MAKE) HOSTCC=gcc \
		&& $(MAKE) install DESTDIR=$(PREFIX)/arm-empeg-linux )
	du -s build-ncurses > arm-linux-ncurses
	rm -rf build-ncurses

arm-linux-gettext: arm-linux-gcc
	@echo Making gettext
	rm -rf build-gettext/build
	mkdir -p build-gettext/build
	tar xzf gettext-*.tar.gz -C build-gettext
	cat gettext.patch|patch -d build-gettext/gettext-* -p1
	export PATH=$(PREFIX)/arm-empeg-linux/bin:$(PREFIX)/bin:$(PATH) ; ( cd build-gettext/build \
		&& CXX=arm-empeg-linux-g++ CC=arm-empeg-linux-gcc ../gettext*/configure --host=arm-linux --build=i386-apple-darwin --prefix=$(PREFIX)/arm-empeg-linux \
		&& $(MAKE) \
		&& $(MAKE) install )
	du -s build-gettext > arm-linux-gettext
	rm -rf build-gettext

arm-linux-zlib: arm-linux-gcc
	@echo Making zlib
	rm -rf build-zlib
	mkdir -p build-zlib
	tar xzf zlib-*.tar.gz -C build-zlib
	export PATH=$(PREFIX)/bin:$(PATH) ; ( cd build-zlib/zlib-* \
		&& LDSHARED="arm-empeg-linux-gcc -shared -Wl,-soname,libz.so.1" CC=arm-empeg-linux-gcc ../zlib*/configure --prefix=$(PREFIX)/arm-empeg-linux --shared \
		&& $(MAKE) \
		&& $(MAKE) install prefix=$(PREFIX)/arm-empeg-linux )
	du -s build-zlib > arm-linux-zlib
	rm -rf build-zlib

check:
ifneq ($(words $(FILES_PRESENT)),$(words $(FILES)))
	@echo Kit incomplete -- you need $(filter-out $(FILES_PRESENT),$(FILES))
	@exit 1
endif
	@echo Kit complete

#eof
