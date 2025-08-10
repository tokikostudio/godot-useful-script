@tool
extends EditorPlugin

const MENU_REMOTE_SYNC = "Custom/Remote Sync"
const SPREADSHEET_ID = "....." # It's in the URL
const ACCESS_TOKEN = "...." # You must setup this from your google drive account

const OUTPUT_FOLDER = "res://sync_folder"
const TAB_NAMES = ["Tab1", "Tab2"]

func _enter_tree():
	add_tool_menu_item(MENU_REMOTE_SYNC, _on_fetch_and_sync)
	var palette = EditorInterface.get_command_palette()
	palette.add_command(MENU_REMOTE_SYNC, MENU_REMOTE_SYNC, _on_fetch_and_sync)

func _exit_tree():
	remove_tool_menu_item(MENU_REMOTE_SYNC)
	var palette = EditorInterface.get_command_palette()
	palette.remove_command(MENU_REMOTE_SYNC)

func _on_fetch_and_sync():
	for tab_name in TAB_NAMES:
		var url = "https://sheets.googleapis.com/v4/spreadsheets/%s/values/%s?key=%s" % [SPREADSHEET_ID, tab_name, ACCESS_TOKEN]

		# Create a new HTTP request for each download
		var request = HTTPRequest.new()
		add_child(request)
		request.request_completed.connect(_on_tab_request_completed.bind(tab_name))
		
		var error = request.request(url)
		if error != OK:
			print("Failed to start request for ", tab_name, ": ", error)

func _on_tab_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, tab_name: String):
	if response_code == 200:
		# Save the response to file
		var output_file = "%s/%s.json" % [OUTPUT_FOLDER, tab_name]
		var file = FileAccess.open(output_file, FileAccess.WRITE)
		if file:
			file.store_string(body.get_string_from_utf8())
			file.close()
			print("✅ Saved: ", output_file)
			_on_download_completed(tab_name)
		else:
			print("❌ Failed to save: ", output_file)
	else:
		print("❌ Failed to download '%s': HTTP %d" % [tab_name, response_code])

func _on_download_completed(tab_name: String):
	var json_file = "/%s.json" % [OUTPUT_FOLDER, tab_name]
	print("📖 Parsing ", tab_name)
	
	if not FileAccess.file_exists(json_file):
		print("🔎 Missing ", tab_name)
		return
	
	# Read and process the Google Sheets JSON format
	var file = FileAccess.open(json_file, FileAccess.READ)
	var json = JSON.parse_string(file.get_as_text())
	file.close()
	
	if not json or not json.has("values"):
		print("JSON doesn't contain 'values' fields")
		return
	
	var values = json["values"]
	# values contains your row data, if for exemple you had in google:
	#
	#     +----------------------+
	#     | NAME | LIFE | DAMAGE |
	#     +----------------------+
	#     | hero |  10  |   1    |
	#     | enemy|  5   |   2    |
	#     +----------------------+
	# 
	# Then:
	# values[0] = [ "NAME", "LIFE", "DAMAGE" ]
	# values[1] = [ "hero", "10", "1" ]
	# values[2] = [ "enemy", "5", "2" ]
