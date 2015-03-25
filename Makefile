#!/usr/bin/make -f
#Line 122580,4
OPTIMIZATIONS ?= -msse -msse2 -mfpmath=sse -ffast-math -fomit-frame-pointer -O3 -fno-finite-math-only
PREFIX ?= /usr/local
CGLAGS ?= -Wall -Wno-unused-function
LIBDIR ?= lib

EXTERNALUI?=yes
KXURI?=yes

override CFLAGS += -g $(OPTIMIZATIONS)
BUILDDIR=build/
RW?=robtk/
#######################

LIB_EXT=.so

LV2DIR ?= $(PREFIX)/$(LIBDIR)/lv2
# TODO: why does lvtk installer add '-1'?
LOADLIBES=-lm `pkg-config --libs lvtk-plugin-1`

LV2NAME=rtkfil
BUNDLE=rtkfil.lv2

LV2GUI=rtkfilUI_gl
FILGUI=fil:rtkfil
#######################

LV2UIREQ=
GLUICFLAGS=-I.
GTKUICFLAGS=-I.

UNAME=$(shell uname)
ifeq ($(UNAME),Darwin)
  LV2LDFLAGS=-dynamiclib
  LIB_EXT=.dylib
  UI_TYPE=ui:CocoaUI
  PUGL_SRC=$(RW)pugl/pugl_osx.m
  PKG_LIBS=
  GLUILIBS=-framework Cocoa -framework OpenGL
  BUILDGTK=no
else
  LV2LDFLAGS=-Wl,-Bstatic -Wl,-Bdynamic
  LIB_EXT=.so
  UI_TYPE=ui:X11UI
  PUGL_SRC=$(RW)pugl/pugl_x11.c
  PKG_LIBS=glu gl
  GLUILIBS=-lX11
  GLUICFLAGS+=`pkg-config --cflags glu`
endif

ifeq ($(EXTERNALUI), yes)
  ifeq ($(KXURI), yes)
    UI_TYPE=kx:Widget
    LV2UIREQ+=lv2:requiredFeature kx:Widget;
    override CFLAGS += -DXTERNAL_UI
  else
    LV2UIREQ+=lv2:requiredFeature ui:external;
    override CFLAGS += -DXTERNAL_UI
    UI_TYPE=ui:external
  endif
endif

targets=$(BUILDDIR)$(LV2NAME)$(LIB_EXT)
targets+=$(BUILDDIR)$(LV2GUI)$(LIB_EXT)

#########################
# check for build-dependencies
ifeq ($(shell pkg-config --exists lv2 || echo no), no)
  $(error "LV2 SDK was not found")
endif

ifeq ($(shell pkg-config --exists glib-2.0 gtk+-2.0 pango cairo $(PKG_LIBS) || echo no), no)
  $(error "This plugin requires cairo, pango, openGL, glib-2.0 and gtk+-2.0")
endif

#ifeq ($(shell pkg-config --exists fftw3f || echo no), no)
#  $(error "fftw3f library was not found")
#endif

# check for LV2 idle thread
ifeq ($(shell pkg-config --atleast-version=1.4.2 lv2 && echo yes), yes)
  GLUICFLAGS+=-DHAVE_IDLE_IFACE
  GTKUICFLAGS+=-DHAVE_IDLE_IFACE
  LV2UIREQ+=lv2:requiredFeature ui:idleInterface; lv2:extensionData ui:idleInterface;
endif

# check for lv2_atom_forge_object  new in 1.8.1 deprecates lv2_atom_forge_blank
#ifeq ($(shell pkg-config --atleast-version=1.8.1 lv2 && echo yes), yes)
#       override CFLAGS += -DHAVE_LV2_1_8
#endif

ifneq ($(MAKECMDGOALS), submodules)
  ifeq ($(wildcard $(RW)robtk.mk),)
    $(warning This plugin needs https://github.com/x42/robtk)
    $(info set the RW environment variale to the location of the robtk headers)
    ifeq ($(wildcard .git),.git)
      $(info or run 'make submodules' to initialize robtk as git submodule)
    endif
    $(error robtk not found)
  endif
endif

override CFLAGS += -fPIC
# TODO: again the '-1' i find annoying
override CFLAGS += `pkg-config --cflags lv2 --cflags lvtk-1`

#######################################
IM=/gui/img/

UIIMGS=
GLUICFLAGS+=`pkg-config --cflags cairo pango`
GLUILIBS+=`pkg-config --libs cairo pango pangocairo $(PKG_LIBS)`

ifeq ($(GLTHREADSYNC), yes)
  GLUICFLAGS+=-DTHREADSYNC
endif

# TODO XXX
DSPSRC=
DSPDEPS=

##################################3
default: all

submodule_pull:
	-test -d .git -a .gitmodules -a -f Makefile.git && $(MAKE) -f Makefile.git submodule_pull

submodule_update:
	-test -d .git -a .gitmodules -a -f Makefile.git && $(MAKE) -f Makefile.git submodule_update

submodule_check:
	-test -d .git -a .gitmodules -a -f Makefile.git && $(MAKE) -f Makefile.git submodule_check

submodules:
	-test -d .git -a .gitmodules -a -f Makefile.git && $(MAKE) -f Makefile.git submodules

all: submodule_check $(BUILDDIR)manifest.ttl $(BUILDDIR)$(LV2NAME).ttl $(targets)

SEDSTR="s/@LV2NAME@/$(LV2NAME)/g;s/@LIB_EXT@/$(LIB_EXT)/g;s/@FILGUI@/$(FILGUI)_gl/g;s/@UI_REQ@/$(LV2UIREQ)/g;s/@UI_TYPE@/$(UI_TYPE)/g;s/@LV2GUI@/$(LV2GUI)/g;s/@FILGUI@/$(FILGUI)_gl/g;s/@UI_REQ@/$(LV2UIREQ)/g"
$(BUILDDIR)manifest.ttl: lv2ttl/manifest.ttl.in Makefile
	@mkdir -p $(BUILDDIR)
	sed $(SEDSTR) lv2ttl/manifest.ttl.in > $(BUILDDIR)manifest.ttl

$(BUILDDIR)$(LV2NAME).ttl: lv2ttl/$(LV2NAME).ttl.in lv2ttl/$(LV2NAME).lv2.ttl.in lv2ttl/$(LV2NAME).gui.ttl.in Makefile
	@mkdir -p $(BUILDDIR)
	sed $(SEDSTR) lv2ttl/$(LV2NAME).ttl.in > $(BUILDDIR)$(LV2NAME).ttl
	sed $(SEDSTR) lv2ttl/$(LV2NAME).lv2.ttl.in >> $(BUILDDIR)$(LV2NAME).ttl
	sed $(SEDSTR) lv2ttl/$(LV2NAME).gui.ttl.in >> $(BUILDDIR)$(LV2NAME).ttl

$(BUILDDIR)$(LV2NAME)$(LIB_EXT): src/$(LV2NAME).cc $(DSPDEPS)
	@mkdir -p $(BUILDDIR)
	$(CXX) $(CPPFLAGS) $(CFLAGS) $(CXXFLAGS) \
	  -o $(BUILDDIR)$(LV2NAME)$(LIB_EXT) src/$(LV2NAME).cc $(DSPSRC) \
	  -shared $(LV2LDFLAGS) $(LDFLAGS) $(LOADLIBES)
	strip -x $(BUILDDIR)$(LV2NAME)$(LIB_EXT)

-include $(RW)robtk.mk

###################################
install: all
	install -d $(DESTDIR)$(LV2DIR)/$(BUNDLE)
	install -m755 $(targets) $(DESTDIR)$(LV2DIR)/$(BUNDLE)
	install -m644 $(BUILDDIR)manifest.ttl $(BUILDDIR)$(LV2NAME).ttl $(DESTDIR)$(LV2DIR)/$(BUNDLE)

uninstall:
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/manifest.ttl
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/$(LV2NAME).ttl
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/$(LV2NAME)$(LIB_EXT)
	rm -f $(DESTDIR)$(LV2DIR)/$(BUNDLE)/$(LV2GUI)$(LIB_EXT)
	-rmdir $(DESTDIR)$(LV2DIR)/$(BUNDLE)

clean:
	rm -f $(BUILDDIR)manifest.ttl \
        rm -f $(BUILDDIR)$(LV2NAME).ttl \
          $(BUILDDIR)$(LV2NAME)$(LIB_EXT) $(BUILDDIR)$(LV2GUI)$(LIB_EXT)
	rm -f $(BUILDDIR)*.dSYM
	-test -d $(BUILDDIR) && rmdir $(BUILDDIR) || true

distclean:
	rm -f cscope.out cscope.files tags

.PHONY: clean all install uninstall distclean \
        submodule_check submodules submodule_update submodule_pull
