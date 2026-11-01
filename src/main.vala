int fork_self(string[] argv) throws Error {
    Bus.watch_name(BusType.SESSION, StatusNotifierWatcher.NAME,
            BusNameWatcherFlags.NONE, () => Process.exit(0), null);

    for (int i = 0; i < argv.length; i++) {
        argv[i] = argv[i] == "--fork" ? "" : argv[i];
    }

    Pid pid;
    try {
        Process.spawn_async(null, argv, null,
                SpawnFlags.CHILD_INHERITS_STDIN | SpawnFlags.SEARCH_PATH,
                null, out pid);
    } catch (SpawnError e) {
        stderr.printf("spawn error: %s\n", e.message);
        Process.exit(1);
    }
    ChildWatch.add(pid, (pid, status) => {
        Process.close_pid(pid);
        Process.exit(status);
    });

    new MainLoop().run();
    return 0;
}

int main(string[] args) {
    if ("-v" in args || "--version" in args) {
        stdout.printf("version: %s\n", VERSION);
        return 0;
    }
    if ("--fork" in args) {
        string[] argv = args; // Copy since we're not allowed to mutate args
        try {
            return fork_self(argv);
        } catch (Error e) {
            stderr.printf("fork error: %s\n", e.message);
            return 1;
        }
    }

    Gtk.init(ref args);

    var server = new ProxyServer();
    server.start();

    Gtk.main();
    return 0;
}
