# 使用 Tauri 实现跨平台 Samba 文件夹挂载功能

下面是一个使用 Tauri 框架实现 Windows、macOS 和 Linux 系统中 Samba 文件夹本地挂载的完整方案，前端使用纯 JavaScript。

## 系统架构

1. 前端：纯 JavaScript + HTML/CSS
2. 后端：Rust (通过 Tauri 的命令系统)
3. 平台适配：针对不同操作系统实现挂载功能

## 实现步骤

### 1. 创建 Tauri 项目

首先创建一个新的 Tauri 项目：

```bash
npm create tauri-app@latest
```

选择 "Vanilla" 作为前端模板。

### 2. 前端实现 (HTML/JavaScript)

在 `src` 目录下创建以下文件：

**index.html**
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Samba 挂载工具</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <div class="container">
        <h1>Samba 文件夹挂载</h1>
        
        <div class="form-group">
            <label for="server">服务器地址:</label>
            <input type="text" id="server" placeholder="例如: //192.168.1.100/share">
        </div>
        
        <div class="form-group">
            <label for="username">用户名:</label>
            <input type="text" id="username">
        </div>
        
        <div class="form-group">
            <label for="password">密码:</label>
            <input type="password" id="password">
        </div>
        
        <div class="form-group">
            <label for="mountpoint">挂载点 (可选):</label>
            <input type="text" id="mountpoint" placeholder="例如: /mnt/samba (Linux/macOS) 或 Z: (Windows)">
        </div>
        
        <div class="buttons">
            <button id="mountBtn">挂载</button>
            <button id="unmountBtn">卸载</button>
            <button id="listBtn">列出已挂载</button>
        </div>
        
        <div id="status"></div>
        <div id="mountedList"></div>
    </div>
    
    <script src="main.js"></script>
</body>
</html>
```

**main.js**
```javascript
document.addEventListener('DOMContentLoaded', () => {
    const mountBtn = document.getElementById('mountBtn');
    const unmountBtn = document.getElementById('unmountBtn');
    const listBtn = document.getElementById('listBtn');
    const statusDiv = document.getElementById('status');
    const mountedListDiv = document.getElementById('mountedList');
    
    // 挂载按钮点击事件
    mountBtn.addEventListener('click', async () => {
        const server = document.getElementById('server').value;
        const username = document.getElementById('username').value;
        const password = document.getElementById('password').value;
        const mountpoint = document.getElementById('mountpoint').value;
        
        if (!server) {
            showStatus('请输入服务器地址', 'error');
            return;
        }
        
        try {
            showStatus('正在挂载...', 'info');
            const result = await window.__TAURI__.invoke('mount_samba', {
                server,
                username,
                password,
                mountpoint: mountpoint || null
            });
            showStatus(`挂载成功: ${result}`, 'success');
        } catch (error) {
            showStatus(`挂载失败: ${error}`, 'error');
        }
    });
    
    // 卸载按钮点击事件
    unmountBtn.addEventListener('click', async () => {
        const mountpoint = document.getElementById('mountpoint').value;
        
        if (!mountpoint) {
            showStatus('请输入挂载点', 'error');
            return;
        }
        
        try {
            showStatus('正在卸载...', 'info');
            await window.__TAURI__.invoke('unmount_samba', { mountpoint });
            showStatus('卸载成功', 'success');
        } catch (error) {
            showStatus(`卸载失败: ${error}`, 'error');
        }
    });
    
    // 列出已挂载按钮点击事件
    listBtn.addEventListener('click', async () => {
        try {
            const mounted = await window.__TAURI__.invoke('list_mounted');
            if (mounted.length === 0) {
                mountedListDiv.innerHTML = '<p>没有已挂载的 Samba 共享</p>';
            } else {
                mountedListDiv.innerHTML = '<h3>已挂载的 Samba 共享:</h3><ul>' + 
                    mounted.map(m => `<li>${m.server} → ${m.mountpoint}</li>`).join('') + 
                    '</ul>';
            }
        } catch (error) {
            mountedListDiv.innerHTML = `<p class="error">获取挂载列表失败: ${error}</p>`;
        }
    });
    
    // 显示状态信息
    function showStatus(message, type) {
        statusDiv.textContent = message;
        statusDiv.className = type;
    }
});
```

**styles.css**
```css
body {
    font-family: Arial, sans-serif;
    margin: 0;
    padding: 20px;
    background-color: #f5f5f5;
}

.container {
    max-width: 600px;
    margin: 0 auto;
    background: white;
    padding: 20px;
    border-radius: 8px;
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
}

h1 {
    text-align: center;
    color: #333;
}

.form-group {
    margin-bottom: 15px;
}

label {
    display: block;
    margin-bottom: 5px;
    font-weight: bold;
}

input[type="text"],
input[type="password"] {
    width: 100%;
    padding: 8px;
    border: 1px solid #ddd;
    border-radius: 4px;
    box-sizing: border-box;
}

.buttons {
    display: flex;
    gap: 10px;
    margin: 20px 0;
}

button {
    padding: 10px 15px;
    background-color: #4CAF50;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    flex: 1;
}

button:hover {
    background-color: #45a049;
}

#unmountBtn {
    background-color: #f44336;
}

#unmountBtn:hover {
    background-color: #d32f2f;
}

#listBtn {
    background-color: #2196F3;
}

#listBtn:hover {
    background-color: #0b7dda;
}

#status {
    margin: 15px 0;
    padding: 10px;
    border-radius: 4px;
}

#status.info {
    background-color: #e7f3fe;
    color: #2196F3;
}

#status.success {
    background-color: #ddffdd;
    color: #4CAF50;
}

#status.error {
    background-color: #ffdddd;
    color: #f44336;
}

.error {
    color: #f44336;
}
```

### 3. Rust 后端实现

在 `src-tauri/src/main.rs` 中实现后端逻辑：

```rust
#![cfg_attr(
    all(not(debug_assertions), target_os = "windows"),
    windows_subsystem = "windows"
)]

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
    
    if let Some(user) = username {
        cmd.arg("/user:").arg(user);
    }
    
    if let Some(pass) = password {
        cmd.arg(pass);
    }
    
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
fn unmount_samba(mountpoint: String) -> Result<(), String> {
    if cfg!(target_os = "windows") {
        // Windows 卸载
        let output = Command::new("net")
            .arg("use")
            .arg(&mountpoint)
            .arg("/delete")
            .output()
            .map_err(|e| e.to_string())?;
            
        if output.status.success() {
            Ok(())
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
            Ok(())
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

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![mount_samba, unmount_samba, list_mounted])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

### 4. 配置 Tauri 项目

在 `src-tauri/tauri.conf.json` 中确保有以下配置：

```json
{
  "build": {
    "beforeBuildCommand": "",
    "beforeDevCommand": "",
    "devPath": "../src",
    "distDir": "../src"
  },
  "tauri": {
    "allowlist": {
      "shell": {
        "execute": true,
        "sidecar": false,
        "open": false
      },
      "process": {
        "execute": true
      }
    },
    "bundle": {
      "active": true,
      "targets": "all",
      "identifier": "com.example.sambamount",
      "icon": [
        "icons/32x32.png",
        "icons/128x128.png",
        "icons/128x128@2x.png",
        "icons/icon.icns",
        "icons/icon.ico"
      ]
    },
    "security": {
      "csp": "default-src 'self'"
    },
    "windows": [
      {
        "fullscreen": false,
        "resizable": true,
        "title": "Samba 挂载工具",
        "width": 800,
        "height": 600
      }
    ]
  }
}
```

### 5. 添加依赖

在 `src-tauri/Cargo.toml` 中添加以下依赖：

```toml
[dependencies]
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

### 6. 构建和运行

```bash
npm run tauri build
```

或者开发模式：

```bash
npm run tauri dev
```

## 功能说明

1. **挂载功能**：
   - 支持 Windows (使用 `net use` 命令)
   - 支持 macOS (使用 `mount -t smbfs` 命令)
   - 支持 Linux (使用 `mount -t cifs` 命令)
   - 自动处理默认挂载点

2. **卸载功能**：
   - 支持 Windows (使用 `net use /delete`)
   - 支持 Unix-like (使用 `umount`)

3. **列出已挂载共享**：
   - 解析系统挂载信息

## 注意事项

1. **权限问题**：
   - 在 Linux/macOS 上，可能需要管理员权限才能挂载
   - 考虑添加 sudo 提示或使用 polkit 授权

2. **安全性**：
   - 密码以明文形式传递到命令行，可能出现在进程列表中
   - 考虑使用密钥环或安全存储来保存凭据

3. **错误处理**：
   - 当前实现捕获了命令执行错误，但可能需要更详细的错误解析

4. **跨平台兼容性**：
   - 测试在不同平台上的行为
   - 可能需要针对特定发行版进行调整

这个实现提供了一个基本的 Samba 挂载功能，可以根据需要进行扩展，比如添加记住凭据、自动挂载、更详细的错误处理等功能。
