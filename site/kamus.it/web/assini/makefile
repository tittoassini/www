# Assini's site makefile

#include /etc/kamus.mak

ROOT=/home/titto/root

include $(ROOT)/dev/conf/prehtml.mak

LOCAL_LIB=assini.i4
PRE=http://www.kamus.it/assini/
SUF=html

LANG=en
LANG_SUF=

SRCS = index.m4 directory.m4 faq.m4 views.m4 tree.m4 
OBJS=$(SRCS:.m4=$(LANG_SUF).$(SUF))

# build new site form .m4 files
all: $(OBJS)
	cat index$(LANG_SUF).$(SUF)

# update server 
up:
	rsync -avz --delete . root@quicquid.org:/home/kamus/public_html/assini

# -n = test only

include $(ROOT)/dev/conf/posthtml.mak












