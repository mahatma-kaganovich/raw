[ -z "$LIBS" -o "$LIBS" = -lncurses ] && export LIBS="$(pkg-config ncurses --libs)"
