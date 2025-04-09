const { invoke } = window.__TAURI__.core;

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
            const result = await invoke('mount_samba', {
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
            await invoke('unmount_samba', { mountpoint });
            showStatus('卸载成功', 'success');
        } catch (error) {
            showStatus(`卸载失败: ${error}`, 'error');
        }
    });
    
    // 列出已挂载按钮点击事件
    listBtn.addEventListener('click', async () => {
        try {
            const mounted = await invoke('list_mounted');
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
