class ProxyIcon : Object {
    StatusNotifierItem item;
    Gtk.StatusIcon icon;
    // if pixmaps != null then we are in pixmap mode
    // TODO: maybe replace with bool/enum if the proxy already caches pixmaps?
    IconPixmap[] pixmaps = null;
    DbusmenuGtk.Menu menu;
    // Cache for scaled pixbuf to avoid re-scaling on every size_changed
    Gdk.Pixbuf cached_pixbuf = null;
    int cached_size = -1;

    public ProxyIcon(string name, string object) throws IOError {
        init.begin(name, object);
    }

    async void init(string name, string object) throws IOError {
        item = yield Bus.get_proxy(BusType.SESSION, name, object, DBusProxyFlags.DO_NOT_AUTO_START, null);
        icon = new Gtk.StatusIcon();

        item.changed.connect(property => {
            switch(property) {
            case "tool-tip": set_tooltip(); break;
            }
        });
        item.icon_changed.connect(set_icon);

        set_icon();
        icon.set_name(item.id); // MUST be called after an icon is set due to Gdk internals
        set_tooltip();

        if (item.menu != null) {
            stdout.printf("%s set menu: %s\n", name, item.menu);
            menu = new DbusmenuGtk.Menu(name, (string)item.menu);
        }

        icon.activate.connect(() => {
            try { item.activate(0, 0); } catch (IOError e) { stderr.printf("activate error: %s\n", e.message); } catch (DBusError e) { stderr.printf("activate DBus error: %s\n", e.message); }
        }); // TODO: consider smarter coordinate hints
        icon.button_press_event.connect(on_button_press);
        icon.scroll_event.connect(on_scroll);
        // Use a debounced size_changed handler to avoid excessive re-scaling
        icon.size_changed.connect(debounced_set_icon_pixmap);
    }

    bool on_button_press(Gdk.EventButton event) {
        if (event.button == 3) {
            if (menu != null) {
                menu.popup_at_pointer(event);
                return true;
            }

            try { item.context_menu((int)event.x_root, (int)event.y_root); } catch (IOError e) { stderr.printf("context_menu error: %s\n", e.message); } catch (DBusError e) { stderr.printf("context_menu DBus error: %s\n", e.message); }
            return true;
        }
        return false;
    }

    bool on_scroll(Gdk.EventScroll event) {
        switch(event.direction) {
            case Gdk.ScrollDirection.SMOOTH:
                 // It seems that we can safely ignore this
                 break;
            case Gdk.ScrollDirection.DOWN:
            case Gdk.ScrollDirection.UP:
                 try { item.scroll((int)event.delta_y, "vertical"); } catch (IOError e) { stderr.printf("scroll error: %s\n", e.message); } catch (DBusError e) { stderr.printf("scroll DBus error: %s\n", e.message); }
                 break;
            case Gdk.ScrollDirection.LEFT:
            case Gdk.ScrollDirection.RIGHT:
                 try { item.scroll((int)event.delta_x, "horizontal"); } catch (IOError e) { stderr.printf("scroll error: %s\n", e.message); } catch (DBusError e) { stderr.printf("scroll DBus error: %s\n", e.message); }
                 break;
            default: stderr.printf("unsupported scrolling event\n");
                 break;
        }
        return true;
    }

    uint debounce_id = 0;

    bool debounced_set_icon_pixmap() {
        if (debounce_id != 0) {
            Source.remove(debounce_id);
        }
        debounce_id = Timeout.add(50, () => {
            debounce_id = 0;
            set_icon_pixmap();
            return false;
        });
        return true;
    }

    void set_icon() {
        var name = item.icon_name;
        pixmaps = null;
        // Clear cached pixbuf when icon changes
        cached_pixbuf = null;
        cached_size = -1;

        if (name != null && name != "") {
            /* Some apps wrongly set a filename for name, relying on this
             * undefined behavior. Since StatusIcon.set_from_file gives no
             * feedback, this check and race is about the best we can do. */
            if (name.contains("/") && FileUtils.test(name, FileTest.EXISTS)) {
                icon.set_from_file(name);
                return;
            }

            var theme = Gtk.IconTheme.get_for_screen(icon.screen);
            var path = item.icon_theme_path;
            if (path != null) {
                string[] paths;
                theme.get_search_path(out paths);
                if (!(path in paths)) {
                    theme.append_search_path(path);
                }
            }
            if (!theme.rescan_if_needed() && !theme.has_icon(name)) {
                /* Forcibly trigger a rescan in case the icon file was added
                 * after the theme has been scanned (new files don't change
                 * mtime if they're in a subdirectory). */
                string[] paths;
                theme.get_search_path(out paths);
                // Suppress const qualifier warning - Vala doesn't support const array cast
                theme.set_search_path(paths);
            }

            set_icon_name(name);
            if (theme.has_icon(name)) {
                return;
            }
        }

        pixmaps = item.icon_pixmap;
        set_icon_pixmap();
    }

    void set_icon_name(string name) {
        icon.set_from_icon_name(name);
    }

    IconPixmap? choose_best_pixmap() {
        if (pixmaps == null || pixmaps.length == 0) return null;
        if (icon.get_size() <= 0) return pixmaps[0];

        var pixmap = pixmaps[0];
        var target_height = icon.get_size();

        // select the smallest pixmap >= target size, or else the largest
        foreach (var newpm in pixmaps) {
            if ( (pixmap.height < target_height && pixmap.height < newpm.height)
                || (pixmap.height > newpm.height && newpm.height >= target_height) )
            { pixmap = newpm; }
        }
        return pixmap;
    }

    Gdk.Pixbuf? pixbuf_from_data(IconPixmap? pixmap) {
        if (pixmap == null || pixmap.width == 0 || pixmap.height == 0) return null;
        
        // Avoid allocation if we can use the data directly
        // The data is ARGB, we need RGBA for Gdk.Pixbuf
        uint8[] data = new uint8[pixmap.width * pixmap.height * 4];

        // Convert from ARGB to RGBA - optimized loop
        int src_idx = 0;
        for (int i = 0; i < data.length; i += 4, src_idx += 4) {
            data[i]     = pixmap.data[src_idx + 1]; // R
            data[i + 1] = pixmap.data[src_idx + 2]; // G
            data[i + 2] = pixmap.data[src_idx + 3]; // B
            data[i + 3] = pixmap.data[src_idx];     // A
        }

        return new Gdk.Pixbuf.from_data(data, Gdk.Colorspace.RGB,
                true, 8, pixmap.width, pixmap.height, pixmap.width * 4);
    }

    Gdk.Pixbuf? scale_pixbuf(Gdk.Pixbuf pixbuf) {
        if (pixbuf == null || icon.get_size() <= 0) return pixbuf;
        if (pixbuf.get_height() == 0 || pixbuf.get_width() == 0) return null;
        if (pixbuf.get_height() == icon.get_size()) return pixbuf;

        // read the image height and use it to calculate the width
        var height = icon.get_size();
        var width = pixbuf.get_width() * height / pixbuf.get_height();

        // Use NEAREST for speed on weak GPU, BILINEAR only if significantly different size
        var diff = pixbuf.get_height() - height;
        if (diff < 0) diff = -diff;
        var interp = (diff > height / 4) 
            ? Gdk.InterpType.BILINEAR 
            : Gdk.InterpType.NEAREST;

        return pixbuf.scale_simple(width, height, interp);
    }

    bool set_icon_pixmap() {
        if (pixmaps == null) return false;
        
        var size = icon.get_size();
        if (size <= 0) return false;

        // Return cached pixbuf if size hasn't changed
        if (cached_pixbuf != null && cached_size == size) {
            icon.set_from_pixbuf(cached_pixbuf);
            return true;
        }

        var pixmap = choose_best_pixmap();
        var pixbuf = pixbuf_from_data(pixmap);
        pixbuf = scale_pixbuf(pixbuf);
        if (pixbuf != null) {
            // Cache the scaled pixbuf
            cached_pixbuf = pixbuf;
            cached_size = size;
            icon.set_from_pixbuf(pixbuf);
            return true;
        }
        return false;
    }

    void set_tooltip() {
        var tooltip = item.tool_tip;
        string title = tooltip.title;
        string text = tooltip.text;

        if (text != null && text != "") {
            title += @"\n$(tooltip.text)";
        }
        icon.set_tooltip_markup(title);
    }
}
