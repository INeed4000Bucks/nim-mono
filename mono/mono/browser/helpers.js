export let p = console.log.bind(console), global = window;
const http_log = Log("http", false);
export function send(method, url, data, timeout = 5000) {
    http_log.info("send", { method, url, data });
    return new Promise((resolve, reject) => {
        var responded = false;
        var xhr = new XMLHttpRequest();
        xhr.open(method.toUpperCase(), url, true);
        xhr.onreadystatechange = function () {
            if (responded)
                return;
            if (xhr.readyState == 4) {
                responded = true;
                if (xhr.status == 200) {
                    const response = JSON.parse(xhr.responseText);
                    http_log.info("receive", { method, url, data, response });
                    resolve(response);
                }
                else {
                    const error = new Error(xhr.responseText);
                    http_log.info("error", { method, url, data, error });
                    reject(error);
                }
            }
        };
        if (timeout > 0) {
            setTimeout(function () {
                if (responded)
                    return;
                responded = true;
                const error = new Error("no response from " + url + "!");
                http_log.info("error", { method, url, data, error });
                reject(error);
            }, timeout);
        }
        xhr.send(JSON.stringify(data));
    });
}
export function find_all(query) {
    let list = [], els = document.querySelectorAll(query);
    for (var i = 0; i < els.length; i++)
        list.push(els[i]);
    return list;
}
export function find_one(query) {
    let el = document.querySelector(query);
    if (!el)
        throw new Error("query_one haven't found any " + query);
    return el;
}
export function sleep(ms) {
    return new Promise((resolve, _reject) => { setTimeout(() => { resolve(); }, ms); });
}
export function Log(component, enabled = true) {
    if (!enabled)
        return {
            info(msg, data = {}) { },
            error(msg, data = {}) { },
            warn(msg, data = {}) { }
        };
    component = component.substring(0, 4).toLowerCase().padEnd(4);
    return {
        info(msg, data = {}) { console.log("  " + component + " " + msg, data); },
        error(msg, data = {}) { console.log("E " + component + " " + msg, data); },
        warn(msg, data = {}) { console.log("W " + component + " " + msg, data); }
    };
}
export function el_by_path(root, path) {
    let el = root;
    for (const pos of path) {
        assert(pos < el.children.length, "wrong path, child index is out of bounds");
        el = el.children[pos];
    }
    return el;
}
export function build_el(html) {
    var tmp = document.createElement('div');
    tmp.innerHTML = html;
    assert(tmp.children.length == 1, "exactly one el expected");
    return tmp.firstChild;
}
export function assert(cond, message = "assertion failed") {
    if (!cond)
        throw new Error(message);
}
export function arrays_equal(a, b) {
    return JSON.stringify(a) == JSON.stringify(b);
}
// Highlight element with yellow flash
let update_timeouts = {};
let flash_id_counter = 0;
export function flash(el, before_delete = false, timeout = 1500, // should be same as in CSS animation
before_delete_timeout = 400 // should be same as in CSS animation
) {
    // const id = $el.get_attr('id')
    let [klass, delay] = before_delete ?
        ['flash_before_delete', before_delete_timeout] :
        ['flash', timeout];
    // ID needed when flash repeatedly triggered on the same element, before the previous flash has
    // been finished. Without ID such fast flashes won't work properly.
    // Example - frequent updates from the server changing counter.
    if (!el.dataset.flash_id)
        el.dataset.flash_id = "" + (flash_id_counter++);
    let id = el.dataset.flash_id;
    if (id in update_timeouts) {
        clearTimeout(update_timeouts[id]);
        el.classList.remove(klass);
        setTimeout(() => {
            void el.offsetWidth;
            el.classList.add(klass);
        }); // Triggering re-render
    }
    else {
        el.classList.add(klass);
    }
    update_timeouts[id] = setTimeout(() => {
        el.classList.remove(klass);
        delete update_timeouts[id];
    }, delay);
}
export function set_window_title(title) {
    if (document.title != title)
        document.title = title;
}
export function set_window_location(location) {
    let current = window.location.pathname + window.location.search + window.location.hash;
    if (location != current)
        history.pushState({}, "", location);
}
export function get_window_location() {
    return window.location.pathname + window.location.search;
}
export function set_favicon(href) {
    var link = document.head.querySelector("link[rel~='icon']");
    if (link) {
        if (link.href != href)
            link.href = href;
    }
    else {
        Log("mono").error("no favicon in html");
    }
}
export function svg_to_base64_data_url(svg) {
    return "data:image/svg+xml;base64," + btoa(svg);
}
