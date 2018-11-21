# first, this examples not required. next, broken for lto
use test || sed -i -e '/add_subdirectory(example)/d' "$S"/CMakeLists.txt
