datalibdir = $(datadir)/efm/gcp/script

SUFFIXES = .sh 

.sh:
	@echo "g/BASEDIR/s;BASEDIR;$(prefix);g" > exscript.$< ;\
	echo "g/SBINDIR/s;SBINDIR;$(sbindir);g" >> exscript.$< ;\
	echo "g/BINDIR/s;BINDIR;$(bindir);g" >> exscript.$< ;\
	echo "g/LIBDIR/s;LIBDIR;$(libdir);g" >> exscript.$< ;\
	echo "g/DATADIR/s;DATADIR;$(datadir);g" >> exscript.$< ;\
	echo "g/SYSCONFDIR/s;SYSCONFDIR;$(sysconfdir);g" >> exscript.$< ;\
	echo "g/LOCALSTATEDIR/s;LOCALSTATEDIR;$(localstatedir);g" >> exscript.$< ;\
	echo "g/PREFIX/s;PREFIX;$(prefix);g" >> exscript.$< ;\
	echo "w! $@" >> exscript.$< 
	@ex -s $< < exscript.$<
	@rm -f exscript.$<
	@chmod +x $@

datalib_SCRIPTS = \
	efm-notify \
	efm-post-promotion \
	efm-remote-post-promotion 

CLEANFILES = $(datalib_SCRIPTS)

EXTRA_DIST = \
	efm-notify.sh \
	efm-post-promotion.sh \
	efm-remote-post-promotion.sh 
