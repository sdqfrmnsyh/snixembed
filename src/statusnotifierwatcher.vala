[DBus (name = "org.kde.StatusNotifierWatcher")]
public class StatusNotifierWatcher : Object {
    public const string NAME = "org.kde.StatusNotifierWatcher";
    public const string OBJECT = "/StatusNotifierWatcher";

    // Methods
    public void register_status_notifier_item(string service, BusName sender) throws IOError, DBusError {
        var name = service;
        if (!DBus.is_name(service)) {
            // appindicator fallback
            name = sender;
        }

        if (watchers.contains(name)) {
            stdout.printf("%s (%s) is already registered; ignoring registration\n", name, service);
            return;
        }

        watchers[name] = Bus.watch_name(BusType.SESSION, name, BusNameWatcherFlags.NONE,
            (conn, item, owner) => status_notifier_item_registered(service, sender),
            (conn, item) => {
                Bus.unwatch_name(watchers[name]);
                watchers.remove(name);
                status_notifier_item_unregistered(item);
            });
    }

    public void register_status_notifier_host(string service) throws IOError, DBusError {
        // We probably don't have to anything here, as we just proxy
    }

    // Properties
    public string[] registered_status_notifier_items { get; }
    public bool is_status_notifier_host_registered { get { return true; } }

    // This property is undocumented yet KDE implements it
    public int protocol_version { get { return 0; } }

    // Signals
    internal signal bool status_notifier_item_registered(string service, BusName sender);
    public signal bool status_notifier_item_unregistered(string service);
    public signal bool status_notifier_host_registered();

    // Internal
    HashTable<string, uint> watchers;
    construct {
        watchers = new HashTable<string, uint>(str_hash, str_equal);
    }
}
