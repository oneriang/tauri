document.addEventListener('DOMContentLoaded', function() {
    const modal = document.getElementById('record-modal');
    const modalTitle = document.getElementById('modal-title');
    const recordForm = document.getElementById('record-form');
    const addBtn = document.getElementById('add-record-btn');
    const closeBtn = document.querySelector('.close');
    let currentRecordId = null;
    
    // 打开添加记录模态框
    if (addBtn) {
        addBtn.addEventListener('click', function() {
            currentRecordId = null;
            modalTitle.textContent = 'Add Record';
            recordForm.reset();
            modal.style.display = 'block';
        });
    }
    
    // 关闭模态框
    closeBtn.addEventListener('click', function() {
        modal.style.display = 'none';
    });
    
    // 点击模态框外部关闭
    window.addEventListener('click', function(event) {
        if (event.target === modal) {
            modal.style.display = 'none';
        }
    });
    
    // 处理表单提交
    if (recordForm) {
        recordForm.addEventListener('submit', function(e) {
            e.preventDefault();
            
            const formData = new FormData(recordForm);
            const data = {};
            formData.forEach((value, key) => {
                data[key] = value;
            });
            
            const tableName = window.location.pathname.split('/')[2];
            const url = currentRecordId 
                ? `/api/tables/${tableName}/records/${currentRecordId}`
                : `/api/tables/${tableName}/records`;
                
            const method = currentRecordId ? 'PUT' : 'POST';
            
            fetch(url, {
                method: method,
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(data),
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    window.location.reload();
                } else {
                    alert(data.error || 'An error occurred');
                }
            })
            .catch(error => {
                console.error('Error:', error);
                alert('An error occurred');
            });
        });
    }
    
    // 绑定编辑按钮
    document.querySelectorAll('.edit-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            currentRecordId = this.getAttribute('data-id');
            modalTitle.textContent = 'Edit Record';
            
            const row = this.closest('tr');
            const inputs = recordForm.querySelectorAll('input');
            
            inputs.forEach(input => {
                const columnName = input.name;
                const cell = row.querySelector(`td:nth-child(${Array.from(row.cells).findIndex(cell => cell.textContent.trim() === row.querySelector(`td[data-column="${columnName}"]`)?.textContent.trim()) + 1})`);
                if (cell) {
                    input.value = cell.textContent.trim();
                }
            });
            
            modal.style.display = 'block';
        });
    });
    
    // 绑定删除按钮
    document.querySelectorAll('.delete-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            if (confirm('Are you sure you want to delete this record?')) {
                const recordId = this.getAttribute('data-id');
                const tableName = window.location.pathname.split('/')[2];
                
                fetch(`/api/tables/${tableName}/records/${recordId}`, {
                    method: 'DELETE',
                })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        window.location.reload();
                    } else {
                        alert(data.error || 'An error occurred');
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    alert('An error occurred');
                });
            }
        });
    });
});
