// Learn more about Tauri commands at https://tauri.app/develop/calling-rust/
#[tauri::command]
fn greet(name: &str) -> String {
    format!("你好, {}! You've been greeted from Rust!", name)
}

#[tauri::command]
fn greet1(id: &str) -> String {
    format!("
        <button> {0} </butoon>
        <button> {0} </butoon>
        <button> {0} </butoon>
        <button> {0} </butoon>
        <button> {0} </butoon>
        <button> {0} </butoon>
    ", id)
}

#[tauri::command]
fn get_message() -> String {
    "Hello from Tauri!".to_string()
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![greet, greet1, get_message])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
