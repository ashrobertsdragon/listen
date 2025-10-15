let supabaseUrl = null;
let supabaseKey = null;
let tabGroupName = "listen";

const NEW_TAB = "chrome://newtab/";

async function loadConfiguration() {
	try {
		const response = await fetch(chrome.runtime.getURL("config.json"));
		const config = await response.json();
		const stored = await chrome.storage.sync.get([
			"supabaseUrl",
			"supabaseKey",
			"tabGroupName",
		]);

		if (!stored.supabaseUrl && config.supabaseUrl) {
			await chrome.storage.sync.set({ supabaseUrl: config.supabaseUrl });
			supabaseUrl = config.supabaseUrl;
		} else if (stored.supabaseUrl) {
			supabaseUrl = stored.supabaseUrl;
		}

		if (!stored.supabaseKey && config.supabaseKey) {
			await chrome.storage.sync.set({ supabaseKey: config.supabaseKey });
			supabaseKey = config.supabaseKey;
		} else if (stored.supabaseKey) {
			supabaseKey = stored.supabaseKey;
		}

		if (!stored.tabGroupName && config.tabGroupName) {
			await chrome.storage.sync.set({ tabGroupName: config.tabGroupName });
			tabGroupName = config.tabGroupName;
		} else if (stored.tabGroupName) {
			tabGroupName = stored.tabGroupName;
		}
	} catch (error) {
		console.log("No config.json found, using storage values only");
		const result = await chrome.storage.sync.get([
			"supabaseUrl",
			"supabaseKey",
			"tabGroupName",
		]);
		if (result.supabaseUrl) {
			supabaseUrl = result.supabaseUrl;
		}
		if (result.supabaseKey) {
			supabaseKey = result.supabaseKey;
		}
		if (result.tabGroupName) {
			tabGroupName = result.tabGroupName;
		}
	}
}

// Load configuration on startup
loadConfiguration();

chrome.storage.onChanged.addListener((changes) => {
	if (changes.supabaseUrl) {
		supabaseUrl = changes.supabaseUrl.newValue;
	}
	if (changes.supabaseKey) {
		supabaseKey = changes.supabaseKey.newValue;
	}
	if (changes.tabGroupName) {
		tabGroupName = changes.tabGroupName.newValue;
	}
});

chrome.runtime.onStartup.addListener(queueTabs);
chrome.runtime.onInstalled.addListener(queueTabs);

chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {
	if (
		changeInfo.groupId &&
		changeInfo.groupId !== chrome.tabGroups.TAB_GROUP_ID_NONE
	) {
		try {
			const group = await chrome.tabGroups.get(changeInfo.groupId);
			if (group.title === tabGroupName) {
				await queueTab(tab, group.id);
			}
		} catch (err) {
			console.error("Error checking tab group:", err);
		}
	}
});

async function queueTabs() {
	if (!supabaseUrl || !supabaseKey) {
		console.log("Supabase not configured");
		return;
	}

	try {
		const group = await getGroup();
		if (!group) {
			console.log(`No "${tabGroupName}" group found`);
			return;
		}

		const tabs = await chrome.tabs.query({ groupId: group.id });
		const urlTabs = tabs.filter(
			(t) => t.url && t.url !== NEW_TAB && !t.url.startsWith("chrome://"),
		);

		for (const tab of urlTabs) {
			await queueTab(tab, group.id);
		}

		console.log(`Queued ${urlTabs.length} URLs`);
	} catch (err) {
		console.error("Queue tabs failed:", err);
	}
}

async function queueTab(tab, groupId) {
	if (!tab.url || tab.url === NEW_TAB || tab.url.startsWith("chrome://")) {
		return;
	}

	try {
		const response = await fetch(`${supabaseUrl}url_queue`, {
			method: "POST",
			headers: {
				"Content-Type": "application/json",
				apikey: supabaseKey,
				Authorization: `Bearer ${supabaseKey}`,
				Prefer: "return=minimal",
			},
			body: JSON.stringify({ url: tab.url }),
		});

		if (response.ok || response.status === 201) {
			console.log(`Queued: ${tab.url}`);
			await removeTabSafely(tab.id, groupId);
		} else {
			console.error(`Failed to queue ${tab.url}:`, await response.text());
		}
	} catch (err) {
		if (err.message && err.message.includes("Failed to fetch")) {
			console.log(`Queued: ${tab.url} (minimal response)`);
			await removeTabSafely(tab.id, groupId);
		} else {
			console.error(`Error queuing tab:`, err);
		}
	}
}

async function removeTabSafely(tabId, groupId) {
	const tabs = await chrome.tabs.query({ groupId: groupId });

	if (tabs.length > 1) {
		await chrome.tabs.remove(tabId);
	} else {
		const newTab = await chrome.tabs.create({ url: NEW_TAB });
		await chrome.tabs.group({ groupId: groupId, tabIds: newTab.id });
		await chrome.tabs.remove(tabId);
	}
}

function getGroup() {
	return chrome.tabGroups
		.query({})
		.then((groups) => groups.find((g) => g.title === tabGroupName) || null);
}
