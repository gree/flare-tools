
BINDIR=/usr/bin
RUBYLIBDIR=/usr/lib/ruby/${RUBYVER}
SRCDIR=.

install:
	install -d ${DESTDIR}${BINDIR}
	install -m 755 ${SRCDIR}/bin/* ${DESTDIR}${BINDIR}
	install -d ${DESTDIR}${RUBYLIBDIR}/flare
	install -m 644 ${SRCDIR}/lib/flare/*.rb ${DESTDIR}${RUBYLIBDIR}/flare
	install -d ${DESTDIR}${RUBYLIBDIR}/flare/tools
	install -m 644 ${SRCDIR}/lib/flare/tools/*.rb ${DESTDIR}${RUBYLIBDIR}/flare/tools
	install -d ${DESTDIR}${RUBYLIBDIR}/flare/tools/cli
	install -m 644 ${SRCDIR}/lib/flare/tools/cli/*.rb ${DESTDIR}${RUBYLIBDIR}/flare/tools/cli
	install -d ${DESTDIR}${RUBYLIBDIR}/flare/util
	install -m 644 ${SRCDIR}/lib/flare/util/*.rb ${DESTDIR}${RUBYLIBDIR}/flare/util
	install -d ${DESTDIR}${RUBYLIBDIR}/flare/net
	install -m 644 ${SRCDIR}/lib/flare/net/*.rb ${DESTDIR}${RUBYLIBDIR}/flare/net
	install -d ${DESTDIR}${RUBYLIBDIR}/flare/test
	install -m 644 ${SRCDIR}/lib/flare/test/*.rb ${DESTDIR}${RUBYLIBDIR}/flare/test

clean:

