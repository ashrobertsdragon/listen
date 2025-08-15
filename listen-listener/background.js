let endpoint = null;
let tabGroupName = null;

const tabGroupCache = {};

const NEW_TAB = "chrome://newtab/";


chrome.storage.sync.get(["endpoint"], (result) => {
  if (result.endpoint) {
    endpoint = result.endpoint;
    console.log("Loaded endpoint:", endpoint);
  }
});

chrome.storage.sync.get(["groupName"], (result) => {
  if (result.groupName) {
    groupName = result.groupName;
    console.log("Loaded group name:", groupName);
  }
});

chrome.storage.onChanged.addListener((changes) => {
  if (changes.endpoint) {
    endpoint = changes.endpoint.newValue;
    console.log("Endpoint updated to:", endpoint);
  }

  if (changes.groupName) {
    groupName = changes.groupName.newValue;
    console.log("Group name updated to:", groupName);
  }
});

chrome.tabGroups.query({}, (groups) => {
  groups.forEach(group => {
    tabGroupCache[group.id] = group.title;
  });
});

chrome.tabGroups.onUpdated.addListener((group) => {
  tabGroupCache[group.id] = group.title;
});

chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {
  if ((!tab.groupId || tab.groupId === -1) && (!changeInfo.url || changeInfo.url === NEW_TAB)) {
        return;
  }
  if (!changeInfo.url || changeInfo.url === NEW_TAB) {
    return;
  }

  const groupTitle = tabGroupCache[tab.groupId];
  if (groupTitle === tabGroupName) {
    await handleTab(tabId, tab.url, tab.groupId);
  }
});
if (!tab.groupId || tab.groupId === -1 || !tab.url || tab.url === NEW_TAB) {
    return;
  }
chrome.tabs.onCreated.addListener(async (tab) => {
  if (!tab.groupId || tab.groupId === -1 || !tab.url || tab.url === NEW_TAB) {
    return;
  }

  const groupTitle = tabGroupCache[tab.groupId];
  if (groupTitle === tabGroupName) {
    await handleTab(tab.id, tab.url, tab.groupId);
  }
});

async function handleTab(tabId, url, groupId) {
  if (url === NEW_TAB) {
    return;
  }
  const tabsInGroup = await chrome.tabs.query({ groupId });

  if (url === NEW_TAB) {
    return;
  }

  if (tabsInGroup.length === 1) {
    const newTab = await chrome.tabs.create({ url: NEW_TAB, active: false });
    await chrome.tabs.group({ tabIds: [newTab.id], groupId });
    console.log("Added dummy tab to preserve tab group.");
  }

  await sendUrl(url);
  chrome.tabs.remove(tabId);
}

async function sendUrl(url) {
  try {
    await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ url })
    });
    console.log("URL sent to TTS Service:", url);
  } catch (err) {
    console.error("Failed to send URL:", err);
  }
}
