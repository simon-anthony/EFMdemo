dist_man1_MANS = \
	getbasebackup.1 

install-data-hook:
	@echo "g/BASEDIR/s;BASEDIR;$(prefix);g" > $(DESTDIR)/$(man1dir)/exscript ;\
	echo "g/SBINDIR/s;SBINDIR;$(sbindir);g" >> $(DESTDIR)/$(man1dir)/exscript ;\
	echo "g/BINDIR/s;BINDIR;$(bindir);g" >> $(DESTDIR)/$(man1dir)/exscript ;\
	echo "g/LIBDIR/s;LIBDIR;$(libdir);g" >> $(DESTDIR)/$(man1dir)/exscript ;\
	echo "g/DATADIR/s;DATADIR;$(datadir);g" >> $(DESTDIR)/$(man1dir)/exscript ;\
	echo "g/SYSCONFDIR/s;SYSCONFDIR;$(sysconfdir);g" >> $(DESTDIR)/$(man1dir)/exscript ;\
	echo "g/LOCALSTATEDIR/s;LOCALSTATEDIR;$(localstatedir);g" >> $(DESTDIR)/$(man1dir)/exscript ;\
	echo "g/PREFIX/s;PREFIX;$(prefix);g" >> $(DESTDIR)/$(man1dir)/exscript ;\
	echo "w!" >> $(DESTDIR)/$(man1dir)/exscript
	@cd $(DESTDIR)/$(man1dir) ;\
	 for file in $(dist_man1_MANS) ;\
	 do \
		ex -s $$file < $(DESTDIR)/$(man1dir)/exscript ;\
	 done
	@rm -f $(DESTDIR)/$(man1dir)/exscript
