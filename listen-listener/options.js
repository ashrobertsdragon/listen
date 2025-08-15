document.addEventListener("DOMContentLoaded", () => {
  const endpointInput = document.getElementById("endpointInput");
  const tabGroupNameInput = document.getElementById("tabGroupNameInput");
  const saveBtn = document.getElementById("saveBtn");

  chrome.storage.sync.get(["endpoint", "tabGroupName"], (result) => {
    if (result.endpoint) {
      endpointInput.value = result.endpointName;
    }
    if (result.tabGroupName) {
      tabGroupNameInput.value = result.tabGroupName;
    }
  });

  saveBtn.addEventListener("click", () => {
    const endpoint = endpointInput.value.trim();
    const tabGroupName = tabGroupNameInput.value.trim();
    chrome.storage.sync.set({ endpoint, tabGroupName }, () => {
      console.log("Settings saved:", { endpoint, tabGroupName });
    });
  });
});
