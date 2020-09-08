AUTHOR := Klassen Software Solutions
AUTHOR_URL := https://www.kss.cc/

include BuildSystem/swift/common.mk

TEST_DATA_SRCS := $(wildcard Tests/KSSDiffTests/Resources/*.txt)
TEST_DATA_SYMBOLS := $(patsubst Tests/KSSDiffTests/Resources/%.txt,Tests/KSSDiffTests/DATA_%.swift,$(TEST_DATA_SRCS))

build: $(TEST_DATA_SYMBOLS)

Tests/KSSDiffTests/DATA_%.swift: Tests/KSSDiffTests/Resources/%.txt
	BuildSystem/swift/generate_resource_file.sh $< $@ $(subst .,_,`basename -s .swift $@`)_InputStream


check: Tests/LinuxMain.swift

TEST_SOURCES := $(wildcard Tests/*Tests/*.swift)

Tests/LinuxMain.swift: $(TEST_SOURCES)
	swift test --generate-linuxmain
