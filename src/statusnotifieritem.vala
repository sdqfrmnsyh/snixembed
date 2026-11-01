struct IconPixmap {
    int32 width;
    int32 height;
    uint8[] data;
}

struct ToolTip {
    string title;
    string text;
}

// StatusNotifierItem proxy
//
// Do not use the D-Bus signals directly, instead rely on icon_changed for icon changes
// and the property changed signals for the rest (title, tooltip, ...).
//
// TODO: handle race conditions
[DBus (name = "org.kde.StatusNotifierItem")]
interface StatusNotifierItem : Object {
    public const string OBJECT = "/StatusNotifierItem";

    // Properties
    public abstract string id { owned get; }
    public abstract string title { owned get; }
    public abstract string icon_name { owned get; }
    public abstract IconPixmap[] icon_pixmap { owned get; }
    public abstract ToolTip tool_tip { owned get; }
    public abstract ObjectPath menu { owned get; }

    // AppIndicator TODO: split in separate interface
    public abstract string icon_theme_path { owned get; }

    // Methods
    public abstract void activate(int x, int y) throws IOError, DBusError;
    public abstract void context_menu(int x, int y) throws IOError, DBusError;
    public abstract void scroll(int delta, string orientation) throws IOError, DBusError;

    // Signals
    public virtual signal void new_title();
    public virtual signal void new_icon();
    public signal void icon_changed();

    // Asynchronously update icon data and then emit icon_changed if necessary
    async void handle_new_icon() throws Error {
        var changes = 0;

        var done = 0;
        AsyncReadyCallback handler = (obj, res) => {
            try {
                if (update_cache.end(res)) changes++;
            } catch (Error e) {
                // Ignore errors from individual property updates
            } finally {
                if (++done == 3) handle_new_icon.callback();
            }
        };
        // Run all three in parallel to reduce latency
        update_cache.begin("IconName", "icon-name", handler);
        update_cache.begin("IconPixmap", "icon-pixmap", handler);
        update_cache.begin("IconThemePath", "icon-theme-path", handler); // AppIndicator only
        yield;

        if (changes != 0) icon_changed();
    }

    public virtual signal void new_tool_tip() {
        update_cache.begin("ToolTip", "tool-tip");
    }

    // Internal cache updates and signalling
    //
    // This looks like the most ugly implementation ever, however:
    // - Vala DBus abstraction is abstract
    // - GObject notify signals doesn't work
    // - g_properties_changed does not get called automatically when the cache is updated
    // - this is simple and just works
    internal abstract signal void changed(string property);

    async bool update_cache(string property, string name) throws Error {
        var me = this as DBusProxy;

        var par = new Variant("(ss)", me.get_interface_name(), property);
        try {
            var res = yield me.call("org.freedesktop.DBus.Properties.Get", par, 0, -1, null);
            Variant v;
            res.get("(v)", out v);

            if (v != me.get_cached_property(property)) {
                me.set_cached_property(property, v);
                var sni = me as StatusNotifierItem;
                if (sni != null) {
                    sni.changed(name);
                }
                return true;
            }
        } catch (DBusError.UNKNOWN_PROPERTY e) {} catch (DBusError.INVALID_ARGS e) {}
        return false;
    }
}
