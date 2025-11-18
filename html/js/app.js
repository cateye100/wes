document.addEventListener("DOMContentLoaded", function () {
    const targetLabelWrapper = document.getElementById("target-label-wrapper");
    const targetPanel = document.getElementById("target-panel");
    const targetOptions = document.getElementById("target-options");
    const targetHint = document.getElementById("target-hint");
    const targetTitle = document.getElementById("target-title");

    const defaultTitle = "Interaktioner";
    const defaultHint = "Vänsterklicka för att välja • Högerklicka för att stänga";

    let targetOpen = false;
    let menuOpen = false;
    let menuContext = null;

    function clearOptions() {
        targetOptions.textContent = "";
    }

    function hidePanel() {
        targetLabelWrapper.style.display = "none";
        targetLabelWrapper.style.visibility = "";
    }

    function ensurePanelVisible() {
        if (targetLabelWrapper.style.display !== "block") {
            targetLabelWrapper.style.display = "block";
            targetLabelWrapper.style.visibility = "hidden";
        }
    }

    function positionPanel() {
        const padding = 20;
        const maxWidth = targetPanel.offsetWidth || targetLabelWrapper.offsetWidth || 260;
        const maxHeight = targetPanel.offsetHeight || targetLabelWrapper.offsetHeight || 200;

        const centerLeft = (window.innerWidth - maxWidth) / 2;
        let left = centerLeft + 140;
        const maxLeft = window.innerWidth - maxWidth - padding;
        left = Math.min(Math.max(left, padding), Math.max(padding, maxLeft));

        const centerTop = (window.innerHeight - maxHeight) / 2;
        const minTop = padding;
        const maxTop = window.innerHeight - maxHeight - padding;
        const clampedTop = Math.min(Math.max(centerTop, minTop), Math.max(minTop, maxTop));

        targetLabelWrapper.style.left = `${left}px`;
        targetLabelWrapper.style.top = `${clampedTop}px`;
        targetLabelWrapper.style.visibility = "visible";
    }

    function resetPanel() {
        clearOptions();
        targetTitle.textContent = defaultTitle;
        targetHint.textContent = defaultHint;
        menuContext = null;
        positionPanel();
    }

    function openTargetPanel() {
        targetOpen = true;
        menuOpen = false;
        menuContext = null;
        ensurePanelVisible();
        clearOptions();
        targetTitle.textContent = defaultTitle;
        targetHint.textContent = defaultHint;
    }

    function closeTargetPanel() {
        targetOpen = false;
        if (!menuOpen) {
            resetPanel();
            hidePanel();
        }
    }

    function handleFoundTarget() {}

    function canSendToNui() {
        return typeof GetParentResourceName === "function";
    }

    function postToResource(endpoint, payload) {
        if (!canSendToNui()) return Promise.resolve();

        return new Promise((resolve) => {
            try {
                const request = new XMLHttpRequest();
                request.open("POST", `https://${GetParentResourceName()}/${endpoint}`, true);
                request.setRequestHeader("Content-Type", "application/json; charset=UTF-8");
                request.onreadystatechange = function () {
                    if (request.readyState === XMLHttpRequest.DONE) {
                        resolve();
                    }
                };
                request.onerror = function () {
                    resolve();
                };
                request.send(payload !== undefined ? JSON.stringify(payload) : "{}");
            } catch (error) {
                resolve();
            }
        });
    }

    function createTargetOption(slot, option) {
        const button = document.createElement("button");
        button.className = "target-option";
        button.dataset.slot = String(slot);

        const icon = document.createElement("i");
        icon.className = option.icon || "fas fa-hand-pointer";
        button.appendChild(icon);

        const label = document.createElement("span");
        label.className = "label";
        label.textContent = option.label || "Interaktion";
        button.appendChild(label);

        if (option.state) {
            const state = document.createElement("span");
            state.className = "state-label";
            state.textContent = option.state;
            button.appendChild(state);
        }

        return button;
    }

    function normalizeTargetEntries(options) {
        if (!options) return [];

        if (Array.isArray(options)) {
            return options
                .map((option, index) => {
                    if (!option) return null;
                    const slot = option.slot !== undefined ? option.slot : index + 1;
                    return [slot, option];
                })
                .filter((entry) => entry !== null);
        }

        return Object.entries(options).filter(([, option]) => option !== null && option !== undefined);
    }

    function renderTarget(data) {
        if (!data || !data.data) {
            closeTargetPanel();
            return;
        }

        const entries = normalizeTargetEntries(data.data);

        if (entries.length === 0) {
            closeTargetPanel();
            return;
        }

        openTargetPanel();
        const meta = data.meta || {};

        targetTitle.textContent = meta.title || defaultTitle;
        targetHint.textContent = meta.hint || defaultHint;

        for (const [slot, option] of entries) {
            const button = createTargetOption(slot, option);
            targetOptions.appendChild(button);
        }

        positionPanel();
    }

    function leaveTarget() {
        if (menuOpen) return;
        closeTargetPanel();
    }

    function renderMenu(context) {
        if (!context) return;

        const contextId = context.id || (menuContext && menuContext.id) || "";
        context.id = contextId;

        menuOpen = true;
        targetOpen = false;
        menuContext = context;

        ensurePanelVisible();
        clearOptions();

        targetTitle.textContent = context.title || defaultTitle;
        targetHint.textContent = context.hint || defaultHint;

        if (!Array.isArray(context.options) || context.options.length === 0) {
            const empty = document.createElement("div");
            empty.className = "target-empty";
            empty.textContent = "Inga alternativ";
            targetOptions.appendChild(empty);
        } else {
            context.options.forEach((option) => {
                if (!option) return;
                const button = document.createElement("button");
                button.className = "target-option menu-option";
                button.dataset.context = contextId;
                if (option.action) {
                    button.dataset.action = option.action;
                } else if (option.id) {
                    button.dataset.action = option.id;
                }
                if (option.value !== undefined) {
                    button.dataset.value = option.value;
                }

                const icon = document.createElement("i");
                icon.className = option.icon || "fas fa-hand-pointer";
                button.appendChild(icon);

                const label = document.createElement("span");
                label.className = "label";
                label.textContent = option.label || "Alternativ";
                button.appendChild(label);

                if (option.state) {
                    const state = document.createElement("span");
                    state.className = "state-label";
                    state.textContent = option.state;
                    button.appendChild(state);
                }

                targetOptions.appendChild(button);
            });
        }

        positionPanel();
    }

    function updateMenu(context) {
        if (!menuOpen || !menuContext || !context) return;
        const contextId = context.id || menuContext.id;
        if (menuContext.id && contextId !== menuContext.id) return;
        context.id = contextId;
        renderMenu(context);
    }

    function closeMenuUI() {
        if (!menuOpen) return;
        menuOpen = false;
        menuContext = null;
        resetPanel();
        if (!targetOpen) {
            hidePanel();
        }
    }

    function handleMenuSelection(button) {
        if (!button || !menuOpen || !menuContext) return;

        const payload = {
            context: button.dataset.context || menuContext.id || "",
            action: button.dataset.action || "",
        };

        if (button.dataset.value !== undefined) {
            const numeric = Number(button.dataset.value);
            payload.value = Number.isNaN(numeric) ? button.dataset.value : numeric;
        }

        postToResource("selectMenu", payload);
    }

    function handleMouseDown(event) {
        const option = event.target.closest(".target-option");

        if (menuOpen) {
            if (event.button === 0 && option) {
                event.preventDefault();
                handleMenuSelection(option);
            } else if (event.button === 2) {
                event.preventDefault();
                closeMenuUI();
                postToResource("closeMenu");
            }
            return;
        }

        if (!targetOpen) return;

        if (option && event.button === 0) {
            event.preventDefault();
            const slotValue = Number(option.dataset.slot);
            const payload = Number.isNaN(slotValue) ? option.dataset.slot : slotValue;
            postToResource("selectTarget", payload);
            closeTargetPanel();
            return;
        }

        if (event.button === 2) {
            event.preventDefault();

            if (!targetOpen) {
                return;
            }

            const hasOptions = targetOptions.querySelector(".target-option");
            if (!hasOptions) {
                return;
            }

            closeTargetPanel();
            postToResource("leftTarget");
        }
    }

    function handleKeyDown(event) {
        if (menuOpen && (event.key === "Escape" || event.key === "Backspace")) {
            event.preventDefault();
            closeMenuUI();
            postToResource("closeMenu");
            return;
        }

        if (event.key === "Escape" || event.key === "Backspace") {
            closeTargetPanel();
            postToResource("closeTarget");
        }
    }

    window.addEventListener("message", function (event) {
        switch (event.data.response) {
            case "openTarget":
                openTargetPanel();
                break;
            case "closeTarget":
                closeTargetPanel();
                break;
            case "foundTarget":
                handleFoundTarget();
                break;
            case "validTarget":
                renderTarget(event.data);
                break;
            case "leftTarget":
                leaveTarget();
                break;
            case "showMenu":
                renderMenu(event.data.data || event.data);
                break;
            case "updateMenu":
                updateMenu(event.data.data || event.data);
                break;
            case "closeMenu":
                closeMenuUI();
                break;
        }
    });

    window.addEventListener("mousedown", handleMouseDown);
    window.addEventListener("keydown", handleKeyDown);

    window.addEventListener("unload", function () {
        window.removeEventListener("mousedown", handleMouseDown);
        window.removeEventListener("keydown", handleKeyDown);
    });
});
