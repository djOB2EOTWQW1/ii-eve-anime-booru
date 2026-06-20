import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.sidebarPolicies
import "anime"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell

// Anime loaders components
import "anime" as AnimeComponents

Item {
    id: root
    anchors.fill: parent
    property real padding: 4

    property var inputField: tagInputField
    readonly property var responses: Booru.responses
    property string previewDownloadPath: Directories.booruPreviews
    property string downloadPath: Directories.booruDownloads
    property string nsfwPath: Directories.booruDownloadsNsfw
    property string commandPrefix: "/"
    property real scrollOnNewResponse: 100
    property int tagSuggestionDelay: 210
    property var suggestionQuery: ""
    property var suggestionList: []

    property bool pullLoading: false
    property int pullLoadingGap: 80
    property real normalizedPullDistance: Math.max(0, (1 - Math.exp(-booruResponseListView.verticalOvershoot / 50)) * booruResponseListView.dragging)

    Connections {
        target: Booru

        function onTagSuggestion(query, suggestions) {
            root.suggestionQuery = query;
            root.suggestionList = suggestions;
        }

        function onRunningRequestsChanged() {
            if (Booru.runningRequests === 0) {
                root.pullLoading = false;
            }
        }

        function onResponseFinished() {
            if (root.responses.length === 0) return

                var last = root.responses[root.responses.length - 1]
                if (last && last.provider !== "system") {
                    Qt.callLater(function() {
                        booruResponseListView.contentY = booruResponseListView.contentY + root.scrollOnNewResponse
                    })
                }
        }
    }

    property var allCommands: [
        {
            name: "clear",
            description: Translation.tr("Clear the current list of images"),
            execute: () => {
                Booru.clearResponses();
            }
        },
        {
            name: "next",
            description: Translation.tr("Get the next page of results"),
            execute: () => {
                if (root.responses.length > 0) {
                    const lastResponse = root.responses[root.responses.length - 1];
                    root.handleInput(`${lastResponse.tags.join(" ")} ${parseInt(lastResponse.page) + 1}`);
                } else {
                    root.handleInput("");
                }
            }
        },
        {
            name: "safe",
            description: Translation.tr("Disable NSFW content"),
            execute: () => {
                Persistent.states.booru.allowNsfw = false;
            }
        },
        {
            name: "lewd",
            description: Translation.tr("Allow NSFW content"),
            execute: () => {
                Persistent.states.booru.allowNsfw = true;
            }
        },
        {
            name: "limit",
            description: Translation.tr("Set image limit. Usage: %1limit NUMBER").arg(root.commandPrefix),
            execute: args => {
                if (args.length === 0 || args[0] === "") {
                    Booru.addSystemMessage(
                        Translation.tr("Current limit: %1").arg(Config.options.sidebar.booru.limit)
                    );
                    return;
                }

                const value = parseInt(args[0]);

                if (isNaN(value) || value < 1 || value > 100) {
                    Booru.addSystemMessage(
                        Translation.tr("Invalid value. Use %1limit NUMBER (1–100)").arg(root.commandPrefix)
                    );
                    return;
                }

                Config.options.sidebar.booru.limit = value;

                Booru.addSystemMessage(
                    Translation.tr("Limit set to %1").arg(value)
                );
            }
        },
        {
            name: "thumbnail",
            description: Translation.tr("Set thumbnail row height. Usage: %1thumbnail VALUE").arg(root.commandPrefix),
            execute: args => {
                if (args.length === 0 || args[0] === "") {
                    Booru.addSystemMessage(
                        Translation.tr("Current thumbnail: %1").arg(ExtensionManager.getExtensionConfig("ii-eve-anime-booru", "rowTooShortThreshold", Config.options?.sidebar?.booru?.rowTooShortThreshold ?? 250))
                    );
                    return;
                }

                const value = parseInt(args[0]);

                if (isNaN(value) || value < 100 || value > 1000) {
                    Booru.addSystemMessage(
                        Translation.tr("Invalid value. Use %1thumbnail VALUE (100–1000)").arg(root.commandPrefix)
                    );
                    return;
                }

                ExtensionManager.setExtensionConfig("ii-eve-anime-booru", "rowTooShortThreshold", value);

                Booru.addSystemMessage(
                    Translation.tr("Thumbnail set to %1").arg(value)
                );
            }
        },
        {
            name: "reset_api",
            description: Translation.tr("Reset API keys for current provider"),
            execute: () => {
                const provider = Booru.currentProvider;
                if (provider === "system") {
                    Booru.addSystemMessage(Translation.tr("Cannot reset keys for system provider"));
                    return;
                }
                KeyringStorage.setNestedField(["apiKeys", provider], undefined);
                KeyringStorage.setNestedField(["apiKeys", provider + "_user_id"], undefined);
                KeyringStorage.setNestedField(["apiKeys", provider + "_pass_hash"], undefined);
                Booru.addSystemMessage(Translation.tr("API keys reset for %1").arg(Booru.providers[provider]?.name ?? provider));
            }
        },
        {
            name: "quality",
            description: Translation.tr("Set preview quality. Usage: %1quality preview|sample|full").arg(root.commandPrefix),
            execute: args => {
                if (args.length === 0 || args[0] === "") {
                    Booru.addSystemMessage(
                        Translation.tr("Current preview quality: %1").arg(ExtensionManager.getExtensionConfig("ii-eve-anime-booru", "previewQuality", Config.options?.sidebar?.booru?.previewQuality ?? "preview"))
                    );
                    return;
                }

                const value = args[0].toLowerCase();

                if (!["preview", "sample", "full"].includes(value)) {
                    Booru.addSystemMessage(
                        Translation.tr("Invalid value. Use %1quality preview|sample|full").arg(root.commandPrefix)
                    );
                    return;
                }

                ExtensionManager.setExtensionConfig("ii-eve-anime-booru", "previewQuality", value);

                Booru.addSystemMessage(
                    Translation.tr("Preview quality set to %1").arg(value)
                );
            }
        },
        {
            name: "player",
            description: Translation.tr("Set video player. Usage: %1player mpv|native").arg(root.commandPrefix),
            execute: args => {
                if (args.length === 0 || args[0] === "") {
                    Booru.addSystemMessage(
                        Translation.tr("Current player: %1").arg(ExtensionManager.getExtensionConfig("ii-eve-anime-booru", "player", Config.options?.sidebar?.booru?.player ?? "mpv"))
                    );
                    return;
                }

                const value = args[0].toLowerCase();

                if (value !== "mpv" && value !== "native") {
                    Booru.addSystemMessage(
                        Translation.tr("Invalid value. Use %1player mpv|native").arg(root.commandPrefix)
                    );
                    return;
                }

                ExtensionManager.setExtensionConfig("ii-eve-anime-booru", "player", value);

                Booru.addSystemMessage(
                    Translation.tr("Player set to %1").arg(value)
                );
            }
        }
    ]

    function handleInput(inputText) {
        if (inputText.startsWith(root.commandPrefix)) {
            // Handle special commands
            const command = inputText.split(" ")[0].substring(1);
            const args = inputText.split(" ").slice(1);
            const commandObj = root.allCommands.find(cmd => cmd.name === `${command}`);
            if (commandObj) {
                // A command may touch shell config/state absent on other shells; degrade gracefully
                try {
                    commandObj.execute(args);
                } catch (e) {
                    Booru.addSystemMessage(Translation.tr("Command not supported here: ") + command);
                }
            } else {
                Booru.addSystemMessage(Translation.tr("Unknown command: ") + command);
            }
        }
        else if (inputText.trim() == "+") {
            root.handleInput(`${root.commandPrefix}next`);
        }
        else {
            // Create tag list
            const tagList = inputText.split(/\s+/).filter(tag => tag.length > 0);
            let pageIndex = 1;

            for (let i = 0; i < tagList.length; ++i) { // Detect page number
                if (/^\d+$/.test(tagList[i])) {
                    pageIndex = parseInt(tagList[i], 10);
                    tagList.splice(i, 1);
                    break;
                }
            }

            const historyEntry = { tags: tagList, page: pageIndex, provider: Booru.currentProvider };
            // Search history lives in the extension's own config (portable across shells)
            const storedHist = ExtensionManager.getExtensionConfig("ii-eve-anime-booru", "searchHistory", []);
            let hist = storedHist ? Array.from(storedHist) : [];

            hist = hist.filter(e =>
            !(e.tags.join(" ") === tagList.join(" ") &&
            e.page === pageIndex &&
            e.provider === Booru.currentProvider)
            );

            hist.unshift(historyEntry);
            ExtensionManager.setExtensionConfig("ii-eve-anime-booru", "searchHistory", hist.slice(0, 13));

            const nsfwAllowed = Persistent.states.booru?.allowNsfw ?? false;
            const reqLimit = Config.options?.sidebar?.booru?.limit ?? 20;
            if (root._needsKeyInjection(Booru.currentProvider)) {
                root._authMakeRequest(tagList, nsfwAllowed, reqLimit, pageIndex);
            } else {
                Booru.makeRequest(tagList, nsfwAllowed, reqLimit, pageIndex);
            }
        }
    }

    // ── Authenticated booru fallback ──────────────────────────────────────────
    // ii-eve's Booru service injects API keys into gelbooru/danbooru requests
    // itself. On host shells that lack that (e.g. upstream ii-vynx), this extension
    // performs the authenticated request directly — reusing the shell Booru's own
    // response parser and response component so results display identically.
    function _needsKeyInjection(provider) {
        return (provider === "gelbooru" || provider === "danbooru") && !("apiKeys" in Booru);
    }

    function _authBooruUrl(tags, nsfw, limit, page) {
        const provider = Booru.currentProvider;
        const providerInfo = Booru.providers[provider];
        let url = providerInfo.api;
        let tagString = tags.join(" ");
        if (!nsfw)
            tagString += (provider === "gelbooru") ? " rating:general" : " rating:safe";
        let params = [];
        params.push("tags=" + encodeURIComponent(tagString));
        params.push("limit=" + limit);
        const keys = KeyringStorage.keyringData?.apiKeys ?? {};
        if (provider === "gelbooru") {
            params.push("pid=" + page);
            if (keys["gelbooru"] && keys["gelbooru_user_id"]) {
                params.push("api_key=" + keys["gelbooru"]);
                params.push("user_id=" + keys["gelbooru_user_id"]);
                if (keys["gelbooru_pass_hash"])
                    params.push("pass_hash=" + keys["gelbooru_pass_hash"]);
            }
        } else if (provider === "danbooru") {
            params.push("page=" + page);
            if (keys["danbooru"] && keys["danbooru_user_id"]) {
                params.push("api_key=" + keys["danbooru"]);
                params.push("login=" + keys["danbooru_user_id"]);
            }
        }
        url += (url.indexOf("?") === -1 ? "?" : "&") + params.join("&");
        return url;
    }

    function _authMakeRequest(tags, nsfw, limit, page) {
        const provider = Booru.currentProvider;
        const providerInfo = Booru.providers[provider];
        const url = root._authBooruUrl(tags, nsfw, limit, page);
        const newResponse = Booru.booruResponseDataComponent.createObject(null, {
            "provider": provider, "tags": tags, "page": page, "images": [], "message": ""
        });
        const xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        if (provider === "danbooru")
            xhr.setRequestHeader("User-Agent", "Quickshell-Booru/1.0");
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            Booru.runningRequests--;
            try {
                if (xhr.status === 200) {
                    let parsed;
                    if (providerInfo.manualParseFunc)
                        parsed = providerInfo.manualParseFunc(xhr.responseText);
                    else
                        parsed = providerInfo.mapFunc(JSON.parse(xhr.responseText));
                    newResponse.images = parsed;
                    newResponse.message = (parsed && parsed.length > 0) ? "" : Booru.failMessage;
                } else {
                    newResponse.message = Booru.failMessage;
                }
            } catch (e) {
                newResponse.message = Booru.failMessage;
            }
            // Mirror ii-eve Booru.addResponse exactly: append, then (in a *separate*
            // assignment) evict from the front. Two assignments let ScriptModel emit
            // granular add/remove ops so the ListView keeps its scroll position instead
            // of jumping. Evicted pages' cached previews are deleted.
            const maxResp = 3;
            Booru.responses = [...Booru.responses, newResponse];
            if (Booru.responses.length > maxResp) {
                const toRemove = Booru.responses.slice(0, Booru.responses.length - maxResp);
                toRemove.forEach(r => {
                    (r.images || []).forEach(img => {
                        [img.preview_url, img.sample_url, img.file_url].forEach(u => {
                            if (!u) return;
                            const clean = ("" + u).split('?')[0];
                            const fn = decodeURIComponent(clean.substring(clean.lastIndexOf('/') + 1));
                            Quickshell.execDetached(["rm", "-f", `${root.previewDownloadPath}/${fn}`]);
                        });
                    });
                });
                Booru.responses = Booru.responses.slice(Booru.responses.length - maxResp);
            }
            if (newResponse.provider !== "system") {
                Qt.callLater(function() {
                    booruResponseListView.contentY = booruResponseListView.contentY + root.scrollOnNewResponse;
                });
            }
        };
        Booru.runningRequests++;
        xhr.send();
    }

    onFocusChanged: (focus) => {
        if (focus && !keyInputDialogLoader.active) {
            tagInputField.forceActiveFocus()
        }
    }

    property real pageKeyScrollAmount: booruResponseListView.height / 2
    Keys.onPressed: (event) => {
        if (keyInputDialogLoader.active) return
            tagInputField.forceActiveFocus()
        if (event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageUp) {
                if (booruResponseListView.atYBeginning) return;
                booruResponseListView.contentY = Math.max(0, booruResponseListView.contentY - root.pageKeyScrollAmount)
                event.accepted = true
            } else if (event.key === Qt.Key_PageDown) {
                if (booruResponseListView.atYEnd) return;
                booruResponseListView.contentY = Math.min(booruResponseListView.contentHeight, booruResponseListView.contentY + root.pageKeyScrollAmount)
                event.accepted = true
            }
        }
        if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_O) {
            Booru.clearResponses()
        }
    }


    ColumnLayout {
        id: columnLayout
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: root.padding

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: swipeView.width
                    height: swipeView.height
                    radius: Appearance.rounding.small
                }
            }

            ScrollEdgeFade {
                z: 1
                target: booruResponseListView
                vertical: true
            }

            StyledListView { // Booru responses
                id: booruResponseListView
                z: 0
                anchors.fill: parent
                spacing: 10

                touchpadScrollFactor: Config.options.interactions.scrolling.touchpadScrollFactor * 1.4
                mouseScrollFactor: Config.options.interactions.scrolling.mouseScrollFactor * 1.4

                model: ScriptModel {
                    values: root.responses
                }
                delegate: BooruResponse {
                    responseData: modelData
                    tagInputField: root.inputField
                    previewDownloadPath: root.previewDownloadPath
                    downloadPath: root.downloadPath
                    nsfwPath: root.nsfwPath
                }

                onDragEnded: { // Pull to load more
                    const gap = booruResponseListView.verticalOvershoot
                    if (gap > root.pullLoadingGap) {
                        root.pullLoading = true
                        root.handleInput(`${root.commandPrefix}next`)
                    }
                }
            }

            Loader { // Empty-state welcome
                id: welcomeLoader
                z: 2
                anchors.fill: parent
                active: root.responses.length === 0
                visible: active
                sourceComponent: AnimeComponents.BooruWelcome {
                    tagInputField: root.inputField
                    triggerAnimationOn: GlobalStates.policiesPanelOpen
                    rotateToRight: GlobalStates.policiesOnLeft
                }
            }

            ScrollToBottomButton {
                z: 3
                target: booruResponseListView
            }

            MaterialLoadingIndicator {
                id: loadingIndicator
                z: 4
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: 20 + (root.pullLoading ? 0 : Math.max(0, (root.normalizedPullDistance - 0.5) * 50))
                    Behavior on bottomMargin {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                        }
                    }
                }
                loading: root.pullLoading || Booru.runningRequests > 0
                pullProgress: Math.min(1, booruResponseListView.verticalOvershoot / root.pullLoadingGap * booruResponseListView.dragging)
                scale: root.pullLoading ? 1 : Math.min(1, root.normalizedPullDistance * 2)
            }

        }

        DescriptionBox { // Tag suggestion description
            text: root.suggestionList[tagSuggestions.selectedIndex]?.description ?? ""
            showArrows: root.suggestionList.length > 1
        }

        Loader { // Loader for Provider API credentials input buttons
            id: apiButtonsLoader
            width: active ? (item?.implicitWidth ?? 0) : 0
            height: active ? (item?.implicitHeight ?? 0) : 0
            visible: active
            Layout.alignment: Qt.AlignHCenter

            active: (Booru.currentProvider === "gelbooru" || Booru.currentProvider === "danbooru") &&
            root.responses.length === 0 &&
            ((Booru.currentProvider === "gelbooru" && (!KeyringStorage.keyringData?.apiKeys?.["gelbooru"] || !KeyringStorage.keyringData?.apiKeys?.["gelbooru_user_id"] || !KeyringStorage.keyringData?.apiKeys?.["gelbooru_pass_hash"])) ||
            (Booru.currentProvider === "danbooru" && (!KeyringStorage.keyringData?.apiKeys?.["danbooru"] || !KeyringStorage.keyringData?.apiKeys?.["danbooru_user_id"])))

            sourceComponent: AnimeComponents.ApiButtonsPanel {
                responses: root.responses
                onOpenKeyInputDialog: keyType => {
                    keyInputDialogLoader.open(keyType)
                }
            }
        }

        FlowButtonGroup { // Tag suggestions
            id: tagSuggestions
            visible: root.suggestionList.length > 0 && tagInputField.text.length > 0
            property int selectedIndex: 0
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                id: tagSuggestionRepeater
                model: {
                    tagSuggestions.selectedIndex = 0
                    return root.suggestionList.slice(0, 10)
                }
                delegate: ApiCommandButton {
                    id: tagButton
                    colBackground: tagSuggestions.selectedIndex === index ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer
                    bounce: false
                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 5
                        StyledText {
                            Layout.fillWidth: false
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSecondaryContainer
                            horizontalAlignment: Text.AlignRight
                            text: modelData.displayName ?? modelData.name
                        }
                        StyledText {
                            Layout.fillWidth: false
                            visible: modelData.count !== undefined
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSecondaryContainer
                            horizontalAlignment: Text.AlignLeft
                            text: modelData.count ?? ""
                        }
                    }

                    onHoveredChanged: {
                        if (tagButton.hovered) {
                            tagSuggestions.selectedIndex = index;
                        }
                    }
                    onClicked: {
                        tagSuggestions.acceptTag(modelData.name)
                    }
                }
            }

            function acceptTag(tag) {
                const words = tagInputField.text.trim().split(/\s+/);
                if (words.length > 0) {
                    words[words.length - 1] = tag;
                } else {
                    words.push(tag);
                }
                const updatedText = words.join(" ") + " ";
                tagInputField.text = updatedText;
                tagInputField.cursorPosition = tagInputField.text.length;
                tagInputField.forceActiveFocus();
            }

            function acceptSelectedTag() {
                if (tagSuggestions.selectedIndex >= 0 && tagSuggestions.selectedIndex < tagSuggestionRepeater.count) {
                    const tag = root.suggestionList[tagSuggestions.selectedIndex].name;
                    tagSuggestions.acceptTag(tag);
                }
            }
        }

        Rectangle { // Tag input area
            id: tagInputContainer
            property real columnSpacing: 5
            Layout.fillWidth: true
            radius: Appearance.rounding.normal - root.padding
            color: Appearance.colors.colLayer2
            implicitWidth: tagInputField.implicitWidth
            implicitHeight: Math.max(inputFieldRowLayout.implicitHeight + inputFieldRowLayout.anchors.topMargin
                + commandButtonsRow.implicitHeight + commandButtonsRow.anchors.bottomMargin + columnSpacing, 45)
            clip: true

            Behavior on implicitHeight {
                animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
            }

            RowLayout { // Input field and send button
                id: inputFieldRowLayout
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 5
                spacing: 0

                StyledTextArea { // The actual TextArea
                    id: tagInputField
                    wrapMode: TextArea.Wrap
                    Layout.fillWidth: true
                    padding: 10
                    color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                    renderType: Text.NativeRendering
                    placeholderText: Translation.tr('Enter tags, or "%1" for commands').arg(root.commandPrefix)

                    background: null

                    property Timer searchTimer: Timer { // Timer for tag suggestions
                        interval: root.tagSuggestionDelay
                        repeat: false
                        onTriggered: {
                            const inputText = tagInputField.text
                            const words = inputText.trim().split(/\s+/);
                            if (words.length > 0) {
                                Booru.triggerTagSearch(words[words.length - 1]);
                            }
                        }
                    }

                    onTextChanged: { // Handle tag suggestions
                        if(tagInputField.text.length === 0) {
                            root.suggestionQuery = ""
                            root.suggestionList = []
                            searchTimer.stop();
                            return
                        }
                        if(tagInputField.text.startsWith(root.commandPrefix)) {
                            root.suggestionQuery = tagInputField.text
                            root.suggestionList = root.allCommands.filter(cmd => cmd.name.startsWith(tagInputField.text.substring(1))).map(cmd => {
                                return {
                                    name: `${root.commandPrefix}${cmd.name}`,
                                    description: `${cmd.description}`,
                                }
                            })
                            searchTimer.stop();
                            return
                        }
                        searchTimer.restart();
                    }

                    function accept() {
                        root.handleInput(text)
                        text = ""
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Tab) {
                            tagSuggestions.acceptSelectedTag();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            tagSuggestions.selectedIndex = Math.max(0, tagSuggestions.selectedIndex - 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            tagSuggestions.selectedIndex = Math.min(root.suggestionList.length - 1, tagSuggestions.selectedIndex + 1);
                            event.accepted = true;
                        } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                            if (event.modifiers & Qt.ShiftModifier) {
                                // Insert newline
                                tagInputField.insert(tagInputField.cursorPosition, "\n")
                                event.accepted = true
                            } else { // Accept text
                                const inputText = tagInputField.text
                                try { root.handleInput(inputText) } catch (e) { console.warn("[Anime] handleInput failed:", e) }
                                tagInputField.clear()
                                event.accepted = true
                            }
                        }
                    }
                }

                RippleButton { // Send button
                    id: sendButton
                    Layout.alignment: Qt.AlignTop
                    Layout.rightMargin: 5
                    implicitWidth: 42
                    implicitHeight: 42
                    buttonRadius: Appearance.rounding.full
                    enabled: tagInputField.text.length > 0
                    toggled: enabled

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: sendButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            const inputText = tagInputField.text
                            root.handleInput(inputText)
                            tagInputField.clear()
                        }
                    }

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        iconSize: 22
                        color: sendButton.enabled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2Disabled
                        text: "arrow_upward"
                    }
                }
            }

            RowLayout { // Controls
                id: commandButtonsRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                anchors.leftMargin: 5
                anchors.rightMargin: 5
                spacing: 5

                ApiInputBoxIndicator { // Tool indicator
                    icon: "api"
                    text: Booru.providers[Booru.currentProvider].name
                    tooltipText: Translation.tr("Current API endpoint: %1\nSet it with %2mode PROVIDER")
                        .arg(Booru.providers[Booru.currentProvider].url)
                        .arg(root.commandPrefix)
                }

                MouseArea { // NSFW toggle
                    visible: width > 0
                    implicitWidth: nsfwPill.implicitWidth
                    Layout.fillHeight: true

                    hoverEnabled: true
                    PointingHandInteraction {}
                    onPressed: {
                        nsfwSwitch.checked = !nsfwSwitch.checked
                    }

                    Rectangle {
                        id: nsfwPill
                        anchors.centerIn: parent
                        radius: Appearance.rounding.full
                        color: nsfwSwitch.checked ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                        implicitWidth: switchesRow.implicitWidth + 16
                        implicitHeight: switchesRow.implicitHeight + 8

                        RowLayout {
                            id: switchesRow
                            spacing: 5
                            anchors.centerIn: parent

                            StyledText {
                                Layout.alignment: Qt.AlignVCenter
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: nsfwSwitch.enabled ? (nsfwSwitch.checked ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1) : Appearance.m3colors.m3outline
                                text: Translation.tr("NSFW")
                            }
                            StyledSwitch {
                                id: nsfwSwitch
                                enabled: Booru.currentProvider !== "zerochan"
                                scale: 0.6
                                Layout.alignment: Qt.AlignVCenter
                                checked: (Persistent.states.booru.allowNsfw && Booru.currentProvider !== "zerochan")
                                onCheckedChanged: {
                                    if (!nsfwSwitch.enabled) return;
                                    Persistent.states.booru.allowNsfw = checked;
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                RippleButton { // Clear recent searches
                    implicitWidth: 34
                    implicitHeight: 34
                    padding: 0
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    enabled: ExtensionManager.getExtensionConfig("ii-eve-anime-booru", "searchHistory", []).length > 0
                    onClicked: {
                        ExtensionManager.setExtensionConfig("ii-eve-anime-booru", "searchHistory", [])
                    }

                    StyledToolTip {
                        text: Translation.tr("Clear recent")
                    }

                    contentItem: MaterialSymbol {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "history"
                        iconSize: 20
                        color: parent.enabled ? Appearance.colors.colOnLayer2 : Appearance.colors.colOnLayer2Disabled
                    }
                }

                RippleButton { // Clear
                    implicitWidth: 34
                    implicitHeight: 34
                    padding: 0
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: {
                        root.handleInput(`${root.commandPrefix}clear`)
                        tagInputField.text = ""
                    }

                    StyledToolTip {
                        text: Translation.tr("Clear")
                    }

                    contentItem: MaterialSymbol {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "delete_sweep"
                        iconSize: 20
                        color: Appearance.colors.colOnLayer2
                    }
                }
            }
        }
    }

    Loader { // Loader key input dialog
        id: keyInputDialogLoader
        anchors.fill: parent
        z: 100
        active: false

        property string keyType: ""

        function open(type) {
            keyType = type
            active = true
        }

        sourceComponent: AnimeComponents.KeyInputDialog {
            keyType: keyInputDialogLoader.keyType
            onClosed: {
                keyInputDialogLoader.active = false
                keyInputDialogLoader.keyType = ""
            }
        }
    }

}
