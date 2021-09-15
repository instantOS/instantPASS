PREFIX = /usr/

all: install

install:
	install -Dm 755 instantpass.sh ${DESTDIR}${PREFIX}bin/instantpass

uninstall:
	rm ${DESTDIR}${PREFIX}bin/instantpass
