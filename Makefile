all:
	./package_release.sh

clean:
	rm -rf build/*.xcarchive build/universal_pkg dist/*.app dist/*.dmg dist/*.zip
