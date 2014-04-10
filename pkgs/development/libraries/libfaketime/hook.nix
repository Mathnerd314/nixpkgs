{ stdenv, libfaketime, writeTextFile}:

# With this hook, the time can be overridden.
stdenv.mkDerivation {
  name = "faketime-hook";
  setup-hook = writeTextFile 'faketime-hook.sh' ''
    setup_faketime() {
      # The following example sets the time to 1 for gcc and date
      # FAKETIME="1970-01-01\ 00:00:01"
      # FAKETIME_ONLY_CMDS="gcc,date"
      if [ "$NIX_ENFORCE_PURITY" = "1" ]; then
          makePreloads += (LD_PRELOAD=${libfaketime}/lib/libfaketime.so.1)
      fi
    }
    
    preHook += (setup_faketime)
  '';

}
