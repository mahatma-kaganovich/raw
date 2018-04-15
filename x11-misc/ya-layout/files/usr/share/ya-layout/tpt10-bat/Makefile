# 
# Thinkpad Tablet 10 battery raw I2C read application
# GPLv3
#

CFLAGS=-O3 -Wall
LDFLAGS=
# CFLAGS+=-DDEBUG

PRG=tpt10-bat
OBJ=tpt10-bat.o
SRC=tpt10-bat.c

all: $(PRG)

$(PRG): $(OBJ)
	$(CC) -o $(PRG) $(OBJ) $(CFLAGS) && chmod 4755 $(PRG)

clean:
	rm -f $(PRG) $(OBJ)
