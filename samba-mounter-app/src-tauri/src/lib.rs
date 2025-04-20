// #![cfg_attr(
//     all(not(debug_assertions), target_os = "windows"),
//     windows_subsystem = "windows"
// )]

use std::process::Command;
use std::path::Path;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Serialize, Deserialize)]
struct MountInfo {
    server: String,
    mountpoint: String,
}

// 挂载 Samba 共享
#[tauri::command]
fn mount_samba(server: String, username: Option<String>, password: Option<String>, mountpoint: Option<String>) -> Result<String, String> {
    let mountpoint = match mountpoint {
        Some(m) => m,
        None => {
            // 如果没有提供挂载点，则根据操作系统生成默认挂载点
            if cfg!(target_os = "windows") {
                // Windows: 使用下一个可用驱动器号
                find_available_drive_letter().ok_or("无法找到可用的驱动器号")?
            } else {
                // Unix-like: 使用 /mnt/ 下的目录
                let default_path = format!("/mnt/{}", sanitize_server_name(&server));
                if !Path::new(&default_path).exists() {
                    std::fs::create_dir_all(&default_path).map_err(|e| e.to_string())?;
                }
                default_path
            }
        }
    };

    if cfg!(target_os = "windows") {
        // Windows 挂载逻辑
        mount_samba_windows(&server, username.as_deref(), password.as_deref(), &mountpoint)
    } else if cfg!(target_os = "macos") {
        // macOS 挂载逻辑
        mount_samba_macos(&server, username.as_deref(), password.as_deref(), &mountpoint)
    } else {
        // Linux 挂载逻辑
        mount_samba_linux(&server, username.as_deref(), password.as_deref(), &mountpoint)
    }
}

// Windows 挂载实现
fn mount_samba_windows(server: &str, username: Option<&str>, password: Option<&str>, mountpoint: &str) -> Result<String, String> {
    let mut cmd = Command::new("net");
    cmd.arg("use");
    cmd.arg(mountpoint);
    cmd.arg(server);
    
    if let Some(pass) = password {
        cmd.arg(pass);
    }

    if let Some(user) = username {
        cmd.arg(format!("/user:{}", user));
    }

    cmd.arg("/persistent:yes"); // 非永久挂载
    
    let output = cmd.output().map_err(|e| e.to_string())?;
    
    if output.status.success() {
        Ok(format!("已挂载 {} 到 {}", server, mountpoint))
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

// macOS 挂载实现
fn mount_samba_macos(server: &str, username: Option<&str>, password: Option<&str>, mountpoint: &str) -> Result<String, String> {
    let mut cmd = Command::new("mount");
    cmd.arg("-t");
    cmd.arg("smbfs");
    
    // 构建认证字符串
    let auth_string = match (username, password) {
        (Some(user), Some(pass)) => format!("{}:{}", user, pass),
        (Some(user), None) => user.to_string(),
        _ => String::new(),
    };
    
    let server_with_auth = if !auth_string.is_empty() {
        format!("//{}@{}", auth_string, server.trim_start_matches("//"))
    } else {
        server.to_string()
    };
    
    cmd.arg(&server_with_auth);
    cmd.arg(mountpoint);
    
    let output = cmd.output().map_err(|e| e.to_string())?;
    
    if output.status.success() {
        Ok(format!("已挂载 {} 到 {}", server, mountpoint))
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

// Linux 挂载实现
fn mount_samba_linux(server: &str, username: Option<&str>, password: Option<&str>, mountpoint: &str) -> Result<String, String> {
    // 确保挂载点存在
    if !Path::new(mountpoint).exists() {
        std::fs::create_dir_all(mountpoint).map_err(|e| e.to_string())?;
    }
    
    let mut cmd = Command::new("mount");
    cmd.arg("-t");
    cmd.arg("cifs");
    cmd.arg(server);
    cmd.arg(mountpoint);
    
    // 添加选项
    let mut options = Vec::new();
    if let Some(user) = username {
        options.push(format!("username={}", user));
    }
    if let Some(pass) = password {
        options.push(format!("password={}", pass));
    }
    
    if !options.is_empty() {
        cmd.arg("-o").arg(options.join(","));
    }
    
    let output = cmd.output().map_err(|e| e.to_string())?;
    
    if output.status.success() {
        Ok(format!("已挂载 {} 到 {}", server, mountpoint))
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

// 卸载 Samba 共享
#[tauri::command]
fn unmount_samba(mountpoint: String) -> Result<String, String> {
    if cfg!(target_os = "windows") {
        // Windows 卸载
        let output = Command::new("net")
            .arg("use")
            .arg(&mountpoint)
            .arg("/delete")
            .output()
            .map_err(|e| e.to_string())?;
        if output.status.success() {
            Ok(format!("成功卸载 {}", mountpoint))
        } else {
            Err(String::from_utf8_lossy(&output.stderr).to_string())
        }
    } else {
        // Unix-like 卸载
        let output = Command::new("umount")
            .arg(&mountpoint)
            .output()
            .map_err(|e| e.to_string())?;
            
        if output.status.success() {
            Ok(format!("已卸载 {}", mountpoint))
        } else {
            Err(String::from_utf8_lossy(&output.stderr).to_string())
        }
    }
}

// 列出已挂载的 Samba 共享
#[tauri::command]
fn list_mounted() -> Result<Vec<MountInfo>, String> {
    if cfg!(target_os = "windows") {
        // Windows: 使用 net use 命令
        let output = Command::new("net")
            .arg("use")
            .output()
            .map_err(|e| e.to_string())?;
            
        if !output.status.success() {
            return Err(String::from_utf8_lossy(&output.stderr).to_string());
        }
        
        let output_str = String::from_utf8_lossy(&output.stdout);
        let mut mounts = Vec::new();
        
        for line in output_str.lines() {
            if line.contains("Microsoft Windows Network") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 3 {
                    mounts.push(MountInfo {
                        server: parts[2].to_string(),
                        mountpoint: parts[0].to_string(),
                    });
                }
            }
        }
        
        Ok(mounts)
    } else {
        // Unix-like: 使用 mount 命令
        let output = Command::new("mount")
            .output()
            .map_err(|e| e.to_string())?;
            
        if !output.status.success() {
            return Err(String::from_utf8_lossy(&output.stderr).to_string());
        }
        
        let output_str = String::from_utf8_lossy(&output.stdout);
        let mut mounts = Vec::new();
        
        for line in output_str.lines() {
            if line.contains("type cifs") || line.contains("type smbfs") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 3 {
                    mounts.push(MountInfo {
                        server: parts[0].to_string(),
                        mountpoint: parts[2].to_string(),
                    });
                }
            }
        }
        
        Ok(mounts)
    }
}

#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

// 辅助函数: 查找可用的 Windows 驱动器号
fn find_available_drive_letter() -> Option<String> {
    for c in ('E'..='Z').rev() {
        let drive = format!("{}:", c);
        if !Path::new(&drive).exists() {
            return Some(drive);
        }
    }
    None
}

// 辅助函数: 清理服务器名称用于创建目录
fn sanitize_server_name(server: &str) -> String {
    server
        .replace("//", "")
        .replace('/', "_")
        .replace(':', "_")
        .replace('\\', "_")
        .replace('?', "_")
        .replace('*', "_")
}

// fn main() {
//     tauri::Builder::default()
//         .invoke_handler(tauri::generate_handler![mount_samba, unmount_samba, list_mounted])
//         .run(tauri::generate_context!())
//         .expect("error while running tauri application");
// }

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![greet, mount_samba, unmount_samba, list_mounted])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
