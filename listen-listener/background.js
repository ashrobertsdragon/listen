let endpoint = null;
let tabGroupName = "listen";

const NEW_TAB = "chrome://newtab/";

async function loadConfiguration() {
  try {
    const response = await fetch(chrome.runtime.getURL('config.json'));
    const config = await response.json();
    const stored = await chrome.storage.sync.get(["endpoint", "tabGroupName"]);

    if (!stored.endpoint && config.endpoint) {
      await chrome.storage.sync.set({ endpoint: config.endpoint });
      endpoint = config.endpoint;
    } else if (stored.endpoint) {
      endpoint = stored.endpoint;
    }

    if (!stored.tabGroupName && config.tabGroupName) {
      await chrome.storage.sync.set({ tabGroupName: config.tabGroupName });
      tabGroupName = config.tabGroupName;
    } else if (stored.tabGroupName) {
      tabGroupName = stored.tabGroupName;
    }
  } catch (error) {
    console.log("No config.json found, using storage values only");
    const result = await chrome.storage.sync.get(["endpoint", "tabGroupName"]);
    if (result.endpoint) {
      endpoint = result.endpoint;
    }
    if (result.tabGroupName) {
      tabGroupName = result.tabGroupName;
    }
  }
}

// Load configuration on startup
loadConfiguration();

chrome.storage.onChanged.addListener((changes) => {
  if (changes.endpoint) {
    endpoint = changes.endpoint.newValue;
  }
  if (changes.tabGroupName) {
    tabGroupName = changes.tabGroupName.newValue;
  }
});

chrome.runtime.onStartup.addListener(handleTabs);
chrome.runtime.onInstalled.addListener(handleTabs);

async function handleGroup() {
  try {
    const group = await getGroup();
    if (!group) {
      return;
    }

    await ensureNewTab(group.id);
    await processGroup(group.id);
  } catch (err) {
    console.error("Sweep failed:", err);
  }
}

function getGroup() {
  return chrome.tabGroups.query({}).then(groups => (
    groups.find(g => g.title === tabGroupName) || null
  ));
}

async function ensureNewTab(groupId) {
  const tabs = await chrome.tabs.query({ groupId });
  const hasNewTab = tabs.some(t => t.url === NEW_TAB);

  if (!hasNewTab) {
    const newTab = await chrome.tabs.create({ url: NEW_TAB, active: false });
    await chrome.tabs.group({ tabIds: [newTab.id], groupId });
  }
}

async function processGroup(groupId) {
  const tabs = await chrome.tabs.query({ groupId });
  for (const tab of tabs) {
    if (tab.url && tab.url !== NEW_TAB) {
      try {
        const page = await getPage(tab.id);
        await sendPage(page);

        await chrome.tabs.remove(tab.id);
      } catch (err) {
        console.error(`Failed to process tab ${tab.id}:`, err);
      }
    }
  }
}

async function getPage(tab) {
  await new Promise(resolve => setTimeout(resolve, 1000));

  const results = await chrome.scripting.executeScript({
    target: { tab },
    func: () => {
      return {
        url: tab.url,
        html: document.documentElement.outerHTML
      };
    }
  });

  return results[0].result;
}

async function sendPage(page) {
  try {
    await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(page)
    });
  } catch (err) {
    console.error("Failed to send page:", err);
  }
}