/* Landing page logic for a cloud-deployed Wolfram MCP server.
 *
 * The page is a static shell: at view time it fetches the sibling /api/info endpoint (public JSON
 * metadata: server name, version, tools, and the /mcp endpoint URL) and renders it, including the
 * click-to-copy client-configuration snippets. All copy-to-clipboard is done here in JavaScript --
 * the notebook clickToCopy helper emits front-end boxes, not HTML, so only the JSON config *shape*
 * is reused. No key is ever shown: snippets carry a <YOUR_KEY> placeholder (keys are minted on the
 * admin page).
 */
(function () {
    "use strict";

    var KEY_PLACEHOLDER = "<YOUR_KEY>";

    // ---- DOM refs ----
    var loadingEl = document.getElementById("loading");
    var errorEl   = document.getElementById("error");
    var contentEl = document.getElementById("content");

    // ---- Helpers ----

    // Resolve a path relative to this page's directory, so the deployment works at whatever cloud
    // path it lands on (e.g. .../obj/<user>/<dir>/index.html -> .../obj/<user>/<dir>/api/info).
    function siblingURL(path) {
        return new URL(path, window.location.href).href;
    }

    function showError(msg) {
        loadingEl.hidden = true;
        contentEl.hidden = true;
        errorEl.textContent = msg;
        errorEl.style.display = "block";
    }

    // MCP server labels/names are restricted to [A-Za-z0-9_-] by some providers; derive a safe label
    // from the server name for the provider snippets.
    function safeLabel(name) {
        var s = String(name || "").replace(/[^A-Za-z0-9_-]/g, "_").replace(/^_+|_+$/g, "");
        return s || "mcp_server";
    }

    // ---- Config snippet shapes (see the OpenAI / Anthropic examples in the deployment notes) ----

    function genericSnippet(url) {
        return JSON.stringify({
            type: "http",
            url: url,
            headers: { "Authorization": "Bearer " + KEY_PLACEHOLDER }
        }, null, 2);
    }

    function openAISnippet(url, label) {
        return JSON.stringify({
            type: "mcp",
            server_label: label,
            server_url: url,
            require_approval: "never",
            headers: { "Authorization": "Bearer " + KEY_PLACEHOLDER }
        }, null, 2);
    }

    function anthropicSnippet(url, label) {
        return JSON.stringify({
            type: "url",
            url: url + "?_key=" + KEY_PLACEHOLDER,
            name: label
        }, null, 2);
    }

    // ---- Rendering ----

    function renderTools(tools) {
        var listEl  = document.getElementById("tools");
        var countEl = document.getElementById("tool-count");
        listEl.textContent = "";

        if (!tools || !tools.length) {
            countEl.textContent = "";
            var none = document.createElement("p");
            none.className = "section-hint";
            none.textContent = "This server exposes no tools.";
            listEl.appendChild(none);
            return;
        }

        countEl.textContent = tools.length + (tools.length === 1 ? " tool" : " tools");

        tools.forEach(function (tool) {
            var row = document.createElement("div");
            row.className = "tool";

            var head = document.createElement("div");
            head.className = "tool-head";

            var hasTitle = tool.title && tool.title !== tool.name;
            if (hasTitle) {
                var title = document.createElement("span");
                title.className = "tool-title";
                title.textContent = tool.title;
                head.appendChild(title);
            }

            var nameEl = document.createElement("code");
            nameEl.className = "tool-name";
            nameEl.textContent = tool.name;
            head.appendChild(nameEl);
            row.appendChild(head);

            if (tool.description) {
                var desc = document.createElement("div");
                desc.className = "tool-desc";
                desc.textContent = tool.description;
                row.appendChild(desc);
            }

            listEl.appendChild(row);
        });
    }

    function render(info) {
        var name  = info && info.name    ? String(info.name)    : "MCP Server";
        var url   = info && info.url     ? String(info.url)     : siblingURL("mcp");
        var label = safeLabel(name);

        document.title = name + " — MCP Server";
        document.getElementById("server-name").textContent = name;

        var versionEl = document.getElementById("server-version");
        if (info && info.version) {
            versionEl.textContent = "v" + info.version;
        } else {
            versionEl.hidden = true;
        }

        document.getElementById("endpoint-url").textContent   = url;
        document.getElementById("snippet-generic").textContent   = genericSnippet(url);
        document.getElementById("snippet-openai").textContent    = openAISnippet(url, label);
        document.getElementById("snippet-anthropic").textContent = anthropicSnippet(url, label);

        renderTools(info && info.tools);

        loadingEl.hidden = true;
        contentEl.hidden = false;
    }

    // ---- Click-to-copy ----

    function flashCopied(btn) {
        var original = btn.getAttribute("data-label") || btn.textContent;
        btn.setAttribute("data-label", original);
        btn.textContent = "Copied";
        btn.classList.add("copied");
        window.setTimeout(function () {
            btn.textContent = original;
            btn.classList.remove("copied");
        }, 1400);
    }

    function copyText(text, btn) {
        var done = function () { flashCopied(btn); };
        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(text).then(done, function () { legacyCopy(text, done); });
        } else {
            legacyCopy(text, done);
        }
    }

    // Fallback for browsers/contexts without the async clipboard API.
    function legacyCopy(text, done) {
        var ta = document.createElement("textarea");
        ta.value = text;
        ta.setAttribute("readonly", "");
        ta.style.position = "absolute";
        ta.style.left = "-9999px";
        document.body.appendChild(ta);
        ta.select();
        try { document.execCommand("copy"); } catch (e) { /* ignore */ }
        document.body.removeChild(ta);
        done();
    }

    function wireCopyButtons() {
        var buttons = document.querySelectorAll(".copy-btn[data-copy-target]");
        Array.prototype.forEach.call(buttons, function (btn) {
            btn.addEventListener("click", function () {
                var target = document.getElementById(btn.getAttribute("data-copy-target"));
                if (target) { copyText(target.textContent, btn); }
            });
        });
    }

    // ---- Boot ----

    function load() {
        fetch(siblingURL("api/info"), { headers: { "Accept": "application/json" } })
            .then(function (resp) {
                if (!resp.ok) { throw new Error("HTTP " + resp.status); }
                return resp.json();
            })
            .then(function (info) {
                render(info);
                wireCopyButtons();
            })
            .catch(function (err) {
                showError("Could not load server information (" + err.message + "). " +
                          "The /api/info endpoint may be unavailable or you may not have permission to view it.");
            });
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", load);
    } else {
        load();
    }
})();
