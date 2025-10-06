document.addEventListener("DOMContentLoaded", () => {
	const supabaseUrlInput = document.getElementById("supabaseUrlInput");
	const supabaseKeyInput = document.getElementById("supabaseKeyInput");
	const tabGroupNameInput = document.getElementById("tabGroupNameInput");
	const saveBtn = document.getElementById("saveBtn");

	chrome.storage.sync.get(
		["supabaseUrl", "supabaseKey", "tabGroupName"],
		(result) => {
			if (result.supabaseUrl) {
				supabaseUrlInput.value = result.supabaseUrl;
			}
			if (result.supabaseKey) {
				supabaseKeyInput.value = result.supabaseKey;
			}
			if (result.tabGroupName) {
				tabGroupNameInput.value = result.tabGroupName;
			}
		},
	);

	saveBtn.addEventListener("click", () => {
		const supabaseUrl = supabaseUrlInput.value.trim();
		const supabaseKey = supabaseKeyInput.value.trim();
		const tabGroupName = tabGroupNameInput.value.trim();
		chrome.storage.sync.set({ supabaseUrl, supabaseKey, tabGroupName }, () => {
			console.log("Settings saved");
			alert("Settings saved!");
		});
	});
});
