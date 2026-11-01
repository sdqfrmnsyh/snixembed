class ProxyServer : Object {
    StatusNotifierWatcher watcher;
    HashTable<string, ProxyIcon> icons;
    // Debounce registrations to avoid spawning multiple ProxyIcons simultaneously
    HashTable<string, uint> pending_registrations;

    public ProxyServer() {
        icons = new HashTable<string, ProxyIcon>(str_hash, str_equal);
        pending_registrations = new HashTable<string, uint>(str_hash, str_equal);
    }

    public void start() {
        // Register watcher
        Bus.own_name(BusType.SESSION, StatusNotifierWatcher.NAME,
                BusNameOwnerFlags.NONE, on_bus_acquired_watcher, () => { },
                () => {
                    stderr.printf("error: could not acquire watcher name\n");
                    Process.exit(1);
                });
    }

    bool on_item_registered(string service, BusName sender) {
        // Debounce rapid registrations
        if (pending_registrations.contains(service)) {
            Source.remove(pending_registrations[service]);
        }
        
        pending_registrations[service] = Timeout.add(100, () => {
            pending_registrations.remove(service);
            do_register_item(service, sender);
            return false;
        });
        return true;
    }

    void do_register_item(string service, BusName sender) {
        stdout.printf("%s appeared\n", service);

        var name = service;
        var object = StatusNotifierItem.OBJECT;
        if (!DBus.is_name(service)) {
            stdout.printf("%s is not a service name, falling back to appindicator on %s\n", service, sender);
            name = sender;
            object = service;
        }

        try {
            var icon = new ProxyIcon(name, object);
            icons.insert(name, icon);
        } catch (IOError e) {
            stderr.printf("error: %s\n", e.message);
        }
    }

    bool on_item_unregistered(string service) {
        stdout.printf("%s vanished\n", service);
        // Cancel any pending registration
        if (pending_registrations.contains(service)) {
            Source.remove(pending_registrations[service]);
            pending_registrations.remove(service);
        }
        icons.remove(service);
        return true;
    }

    void on_bus_acquired_watcher(DBusConnection conn) {
        try {
            watcher = new StatusNotifierWatcher();
            watcher.status_notifier_item_registered.connect(on_item_registered);
            watcher.status_notifier_item_unregistered.connect(on_item_unregistered);

            conn.register_object(StatusNotifierWatcher.OBJECT, watcher);
            watcher.status_notifier_host_registered();
        } catch (IOError e) {
            stderr.printf("could not register watcher service\n");
        }
    }
}
